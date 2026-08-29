import XCTest
import Foundation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// EXPLAIN QUERY PLAN assertions for the hot event queries — guards against index
/// regressions (dropped index, query shape change that defeats the planner).
final class QueryPlanTests: XCTestCase {
    var playaDB: PlayaDB!
    var dbQueue: any DatabaseWriter {
        (playaDB as! PlayaDBImpl).dbQueue
    }

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    private func queryPlan(_ sql: String) async throws -> String {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "EXPLAIN QUERY PLAN " + sql)
            return rows.compactMap { $0["detail"] as String? }.joined(separator: "\n")
        }
    }

    func testNotExpiredBrowseUsesIndex() async throws {
        // Default list filter: end_time > now, ordered by start_time.
        let plan = try await queryPlan("""
            SELECT * FROM event_occurrences
            WHERE end_time > '2026-09-01 12:00:00'
            ORDER BY start_time
            """)
        XCTAssertTrue(plan.contains("USING INDEX"), "notExpired browse should be index-served, got:\n\(plan)")
    }

    func testHappeningNowUsesIndex() async throws {
        let plan = try await queryPlan("""
            SELECT * FROM event_occurrences
            WHERE start_time <= '2026-09-01 12:00:00' AND end_time > '2026-09-01 12:00:00'
            """)
        XCTAssertTrue(plan.contains("USING INDEX"), "happeningNow should be index-served, got:\n\(plan)")
    }

    func testFavoriteExistsSubqueryUsesMetadataIndex() async throws {
        // The onlyFavorites EXISTS predicate from eventObjectOccurrencesJoined.
        let plan = try await queryPlan("""
            SELECT * FROM event_occurrences
            WHERE EXISTS (
                SELECT 1 FROM object_metadata
                WHERE object_metadata.object_type = 'event'
                  AND object_metadata.object_id = event_occurrences.event_id
                  AND object_metadata.is_favorite = 1
            )
            """)
        XCTAssertTrue(
            plan.contains("USING INDEX") || plan.contains("USING COVERING INDEX"),
            "favorites EXISTS should hit an object_metadata index, got:\n\(plan)"
        )
        XCTAssertFalse(
            plan.contains("SCAN object_metadata"),
            "favorites EXISTS must not scan object_metadata, got:\n\(plan)"
        )
    }

    func testOccurrencesByEventUsesIndex() async throws {
        let plan = try await queryPlan("""
            SELECT * FROM event_occurrences WHERE event_id = 'abc'
            """)
        XCTAssertTrue(plan.contains("USING INDEX"), "event_id lookup should be index-served, got:\n\(plan)")
    }

    func testEndTimeIndexExists() async throws {
        let indexes = try await dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'event_occurrences'
                """)
        }
        XCTAssertTrue(indexes.contains("idx_event_occurrences_end_time"), "end_time index missing: \(indexes)")
    }
}
