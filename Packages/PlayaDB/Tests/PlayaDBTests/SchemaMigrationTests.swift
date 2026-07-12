import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// Verifies DatabaseMigrator adoption: fresh installs record the initial migration,
/// and databases created before the migrator existed (ad-hoc CREATE TABLE setup)
/// adopt it without conflicting with their existing schema or losing data.
final class SchemaMigrationTests: XCTestCase {
    var tempDBPath: String!

    override func setUp() {
        super.setUp()
        tempDBPath = NSTemporaryDirectory() + "SchemaMigrationTests-\(UUID().uuidString).sqlite"
    }

    override func tearDown() {
        if let tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        super.tearDown()
    }

    func testFreshDatabaseRecordsInitialMigration() async throws {
        let playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        let applied = try await playaDB.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
        }
        XCTAssertEqual(applied, ["v1-initial-schema", "v2-favorite-sync", "v3-visit-status"])
    }

    func testPreMigratorDatabaseAdoptsCleanlyAndKeepsData() async throws {
        // Simulate a database created by the pre-migrator ad-hoc setup: schema
        // exists (partially, here) with user data, but no grdb_migrations table.
        do {
            let legacy = try DatabaseQueue(path: tempDBPath)
            try await legacy.write { db in
                try db.execute(sql: """
                    CREATE TABLE object_metadata (
                        object_type TEXT NOT NULL,
                        object_id TEXT NOT NULL,
                        is_favorite INTEGER NOT NULL DEFAULT 0,
                        first_viewed TEXT,
                        last_viewed TEXT,
                        user_notes TEXT,
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        PRIMARY KEY (object_type, object_id)
                    )
                """)
                try db.execute(sql: """
                    INSERT INTO object_metadata (object_type, object_id, is_favorite, created_at, updated_at)
                    VALUES ('camp', 'legacy-camp', 1, '2025-08-01', '2025-08-01')
                """)
            }
        }

        // Opening through PlayaDBImpl must apply v1 (idempotent DDL) without error.
        let playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let (applied, favoriteCount, tableCount, backfilledStamp) = try await playaDB.dbQueue.read { db -> ([String], Int, Int, String?) in
            let applied = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations")
            let favorites = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM object_metadata WHERE object_id = 'legacy-camp' AND is_favorite = 1
                """) ?? 0
            let tables = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM sqlite_master WHERE type = 'table'
                  AND name IN ('art_objects', 'camp_objects', 'event_objects', 'event_occurrences', 'mv_objects')
                """) ?? 0
            let stamp = try String.fetchOne(db, sql: """
                SELECT favorite_updated_at FROM object_metadata WHERE object_id = 'legacy-camp'
                """)
            return (applied, favorites, tables, stamp)
        }

        XCTAssertEqual(applied, ["v1-initial-schema", "v2-favorite-sync", "v3-visit-status"])
        XCTAssertEqual(favoriteCount, 1, "Pre-existing user data must survive migrator adoption")
        XCTAssertEqual(tableCount, 5, "v1 should create the tables the legacy DB was missing")
        XCTAssertEqual(backfilledStamp, "2025-08-01",
                       "v2 must backfill favorite_updated_at from updated_at for existing favorites")
    }
}
