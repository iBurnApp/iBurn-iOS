import XCTest
import Foundation
import GRDB
@testable import PlayaDB
@testable import PlayaAPI
import PlayaAPITestHelpers

/// Verifies the external-content FTS5 sync triggers.
///
/// External-content FTS5 tables must be maintained with the special 'delete'
/// command carrying the OLD column values. A plain `DELETE FROM fts WHERE rowid=…`
/// (shipped by earlier versions) corrupts the index on any UPDATE/DELETE of the
/// content table outside a full import.
final class FTSTriggerTests: XCTestCase {
    var playaDB: PlayaDB!
    var dbQueue: any DatabaseWriter {
        (playaDB as! PlayaDBImpl).dbQueue
    }
    var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "FTSTriggerTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        try await super.tearDown()
    }

    private func firstCampUID() async throws -> String {
        let camps = try await playaDB.fetchCamps()
        return try XCTUnwrap(camps.first).uid
    }

    private func integrityCheck(_ ftsTable: String) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "INSERT INTO \(ftsTable)(\(ftsTable)) VALUES('integrity-check')")
        }
    }

    // MARK: - Trigger correctness

    func testUpdateKeepsFTSIndexInSync() async throws {
        let uid = try await firstCampUID()

        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE camp_objects SET name = ? WHERE uid = ?",
                arguments: ["Zanzibar Xylophone Palace", uid]
            )
        }

        let results = try await playaDB.searchObjects("Zanzibar Xylophone")
        XCTAssertTrue(
            results.contains { $0.uid == uid },
            "Updated name should be searchable via FTS"
        )
        try await integrityCheck("camp_objects_fts")
    }

    func testUpdateRemovesStaleTokensFromIndex() async throws {
        let uid = try await firstCampUID()
        let originalName = try await dbQueue.read { db in
            try XCTUnwrap(String.fetchOne(
                db,
                sql: "SELECT name FROM camp_objects WHERE uid = ?",
                arguments: [uid]
            ))
        }

        try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE camp_objects SET name = ? WHERE uid = ?",
                arguments: ["Quixotic Zeppelin", uid]
            )
        }

        let staleResults = try await playaDB.searchObjects(originalName)
        XCTAssertFalse(
            staleResults.contains { $0.uid == uid },
            "Old name should no longer match after update"
        )
    }

    func testDeleteKeepsFTSIndexInSync() async throws {
        let uid = try await firstCampUID()

        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM camp_objects WHERE uid = ?", arguments: [uid])
        }

        try await integrityCheck("camp_objects_fts")
        let results = try await playaDB.searchObjects("camp")
        XCTAssertFalse(results.contains { $0.uid == uid })
    }

    func testAllFTSTablesPassIntegrityCheckAfterImport() async throws {
        for fts in ["art_objects_fts", "camp_objects_fts", "event_objects_fts", "mv_objects_fts"] {
            try await integrityCheck(fts)
        }
    }

    // MARK: - Legacy trigger migration

    /// Reinstalls the pre-fix plain-DELETE triggers, corrupts the index with an
    /// update + delete, then reopens the database. Setup must detect the legacy
    /// triggers, replace them, and rebuild the index.
    func testLegacyPlainDeleteTriggersAreMigratedAndIndexRebuilt() async throws {
        let uid = try await firstCampUID()

        try await dbQueue.write { db in
            for suffix in ["ai", "ad", "au"] {
                try db.execute(sql: "DROP TRIGGER IF EXISTS camp_objects_\(suffix)")
            }
            try db.execute(sql: """
                CREATE TRIGGER camp_objects_ai AFTER INSERT ON camp_objects BEGIN
                    INSERT INTO camp_objects_fts(rowid, uid, name, description, landmark, hometown)
                    VALUES (new.rowid, new.uid, new.name, new.description, new.landmark, new.hometown);
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER camp_objects_ad AFTER DELETE ON camp_objects BEGIN
                    DELETE FROM camp_objects_fts WHERE rowid = old.rowid;
                END
            """)
            try db.execute(sql: """
                CREATE TRIGGER camp_objects_au AFTER UPDATE ON camp_objects BEGIN
                    DELETE FROM camp_objects_fts WHERE rowid = old.rowid;
                    INSERT INTO camp_objects_fts(rowid, uid, name, description, landmark, hometown)
                    VALUES (new.rowid, new.uid, new.name, new.description, new.landmark, new.hometown);
                END
            """)
            // Desync the index through the legacy triggers.
            try db.execute(
                sql: "UPDATE camp_objects SET name = ? WHERE uid = ?",
                arguments: ["Vexing Quagmire Collective", uid]
            )
        }

        // Reopen: setup should detect the plain-DELETE trigger, replace it, and rebuild.
        playaDB = nil
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let triggerSQL = try await dbQueue.read { db in
            try XCTUnwrap(String.fetchOne(db, sql: """
                SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = 'camp_objects_ad'
                """))
        }
        XCTAssertTrue(triggerSQL.contains("'delete'"), "Legacy trigger should be replaced with the FTS5 'delete' command form")

        try await integrityCheck("camp_objects_fts")
        let results = try await playaDB.searchObjects("Vexing Quagmire")
        XCTAssertTrue(results.contains { $0.uid == uid })
    }
}
