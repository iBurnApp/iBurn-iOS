import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// Regression coverage for the production crash in build 2026.0 (110):
/// `GRDB/SerializedDatabase.swift:261: Fatal error: A transaction has been left opened at
/// the end of a database access`, on thread `GRDB.DatabasePool.reader.6`.
///
/// The app cancels in-flight database Tasks constantly (search type-ahead, list reloads,
/// nearby recomputes). Cancelling an async GRDB access calls `sqlite3_interrupt` on that
/// connection; the access must still be able to close its transaction afterwards. Two
/// GRDB bugs broke that up to 7.6.1, the version this app shipped:
///
/// * `DatabasePool.read` closed its deferred transaction with a bare `try? db.commit()`
///   and no ROLLBACK fallback, so an interrupted COMMIT left the transaction open
///   (fixed in 7.7.0).
/// * FTS5 leaks prepared statements, which keeps the connection in a *sticky* interrupted
///   state, so even COMMIT/ROLLBACK fail with SQLITE_INTERRUPT
///   (<https://sqlite.org/forum/forumpost/137c7662b3>, GRDB
///   [#1838](https://github.com/groue/GRDB.swift/issues/1838), fixed in 7.9.0 by
///   resetting all prepared statements and retrying).
///
/// Both leave `db.isInsideTransaction == true` when the access ends. GRDB's own
/// `assert(!db.isInsideTransaction)` is compiled out in Release, so the outer
/// `preconditionNoUnsafeTransactionLeft` fires — a fatalError, not a throw.
///
/// A regression here therefore does not fail the test: it kills the test process.
/// `testCancellingWriteThatTouchedFTS5` reproduced the crash deterministically on GRDB
/// 7.6.1 (first iteration) and passes on 7.11.1.
final class TaskCancellationTransactionTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    /// On-disk, so `PlayaDBImpl` builds a `DatabasePool` — the configuration that
    /// crashed. An in-memory database would use a `DatabaseQueue` and skip the
    /// reader path entirely.
    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "TaskCancellationTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        try await seedCorpus()
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: tempDBPath + suffix)
            }
        }
        tempDBPath = nil
        try await super.tearDown()
    }

    private func seedCorpus() async throws {
        try await playaDB.dbQueue.write { db in
            for index in 0..<500 {
                var art = ArtObject(
                    uid: "art-\(index)",
                    name: "Anemone Apparatus \(index) Aurora",
                    year: 2026,
                    description: "An ambulatory assemblage of ambient artifacts number \(index)"
                )
                try art.insert(db)
            }
        }
    }

    /// Long enough to be interrupted mid-flight, short enough to keep the test fast.
    private func burnTime(_ db: Database) throws {
        _ = try Int.fetchOne(db, sql: """
            WITH RECURSIVE counter(n) AS (
                SELECT 1 UNION ALL SELECT n + 1 FROM counter WHERE n < 300000
            )
            SELECT count(*) FROM counter
            """)
    }

    /// Deterministic reproduction: the write touches an FTS5-indexed table first (the
    /// `art_objects` triggers write `art_objects_fts`), which leaks the FTS5 prepared
    /// statements, and only then does slow work that the cancellation can interrupt.
    func testCancellingWriteThatTouchedFTS5DoesNotLeaveTransactionOpen() async throws {
        let dbQueue = playaDB.dbQueue

        for iteration in 0..<40 {
            let insideTransaction = XCTestExpectation(description: "inside transaction \(iteration)")
            let task = Task {
                try await dbQueue.write { db in
                    try db.execute(
                        sql: "UPDATE art_objects SET description = ? WHERE uid = ?",
                        arguments: ["touched-\(iteration)", "art-0"])
                    insideTransaction.fulfill()
                    try self.burnTime(db)
                }
            }
            await fulfillment(of: [insideTransaction], timeout: 10)
            task.cancel()
            // Completing or throwing CancellationError / SQLITE_INTERRUPT are both
            // legal outcomes. What matters is that the connection is left clean.
            _ = try? await task.value
        }

        let count = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM art_objects") ?? 0
        }
        XCTAssertEqual(count, 500)
    }

    /// Smoke sweep over the reader path: cancel at a spread of points inside an
    /// FTS5 query plus slow scan. This did not reproduce the crash on 7.6.1 on its
    /// own (the reader race is much narrower than the FTS5 write case), but it keeps
    /// the cancelled-read path exercised and is fast and deterministic.
    func testCancellingReadsLeavesPoolUsable() async throws {
        let dbQueue = playaDB.dbQueue

        for iteration in 0..<200 {
            let delayMicroseconds = UInt64((iteration % 20) * 100)
            let task = Task {
                try await dbQueue.read { db in
                    _ = try Int.fetchOne(
                        db,
                        sql: "SELECT count(*) FROM art_objects_fts WHERE art_objects_fts MATCH ?",
                        arguments: ["a*"])
                    try self.burnTime(db)
                }
            }
            if delayMicroseconds > 0 {
                try? await Task.sleep(nanoseconds: delayMicroseconds * 1_000)
            }
            task.cancel()
            _ = try? await task.value
        }

        let count = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM art_objects") ?? 0
        }
        XCTAssertEqual(count, 500)
    }
}
