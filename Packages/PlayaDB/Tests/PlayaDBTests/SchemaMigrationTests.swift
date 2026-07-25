import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// Verifies DatabaseMigrator adoption: fresh installs record the initial migration,
/// and databases created before the migrator existed (ad-hoc CREATE TABLE setup)
/// adopt it without conflicting with their existing schema or losing data.
final class SchemaMigrationTests: XCTestCase {
    /// Every migration registered in `PlayaDBImpl.setupDatabase()`, in order.
    static let allMigrations = [
        "v1-initial-schema",
        "v2-favorite-sync",
        "v3-visit-status",
        "v4-audio-tour",
        "v5-calendar-entries"
    ]

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
        XCTAssertEqual(applied, Self.allMigrations)
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

        XCTAssertEqual(applied, Self.allMigrations)
        XCTAssertEqual(favoriteCount, 1, "Pre-existing user data must survive migrator adoption")
        XCTAssertEqual(tableCount, 5, "v1 should create the tables the legacy DB was missing")
        XCTAssertEqual(backfilledStamp, "2025-08-01",
                       "v2 must backfill favorite_updated_at from updated_at for existing favorites")
    }

    // MARK: - v4 / v5

    /// Simulates an installed database that stopped at v3 (the shipping schema before
    /// the audio-tour column and calendar-entry table existed) and verifies the new
    /// migrations apply on top of it without disturbing existing rows.
    func testV4AndV5ApplyToExistingV3Database() async throws {
        // Build the v3-era database by opening the current schema and undoing the
        // v4/v5 artifacts (SQLite ≥ 3.35 supports ALTER TABLE ... DROP COLUMN).
        do {
            let current = try PlayaDBImpl(dbPath: tempDBPath)
            try await current.dbQueue.write { db in
                try db.execute(sql: "ALTER TABLE art_objects DROP COLUMN audio_tour_url")
                try db.execute(sql: "DROP TABLE event_calendar_entries")
                try db.execute(sql: """
                    DELETE FROM grdb_migrations
                    WHERE identifier IN ('v4-audio-tour', 'v5-calendar-entries')
                """)
                try db.execute(sql: """
                    INSERT INTO art_objects (uid, name, year, guided_tours, self_guided_tour_map)
                    VALUES ('legacy-art', 'Legacy Art', 2025, 0, 0)
                """)
            }

            let preMigration = try await current.dbQueue.read { db in
                try db.columns(in: "art_objects").contains { $0.name == "audio_tour_url" }
            }
            XCTAssertFalse(preMigration, "Test setup should produce a v3-era art_objects table")
        }

        let playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let (applied, hasAudioColumn, hasCalendarTable, legacyArt) = try await playaDB.dbQueue.read {
            db -> ([String], Bool, Bool, ArtObject?) in
            let applied = try String.fetchAll(db, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier")
            let hasAudioColumn = try db.columns(in: "art_objects").contains { $0.name == "audio_tour_url" }
            let hasCalendarTable = try db.tableExists("event_calendar_entries")
            let legacyArt = try ArtObject.filter(key: "legacy-art").fetchOne(db)
            return (applied, hasAudioColumn, hasCalendarTable, legacyArt)
        }

        XCTAssertEqual(applied, Self.allMigrations.sorted())
        XCTAssertTrue(hasAudioColumn, "v4 must add art_objects.audio_tour_url")
        XCTAssertTrue(hasCalendarTable, "v5 must create event_calendar_entries")

        let art = try XCTUnwrap(legacyArt, "Pre-existing art rows must survive the migrations")
        XCTAssertEqual(art.name, "Legacy Art")
        XCTAssertNil(art.audioTourUrl, "Rows predating v4 get a NULL audio tour URL")
    }

    /// The calendar-entry table carries a composite primary key so a repeated save
    /// for the same occurrence replaces rather than duplicates.
    func testCalendarEntriesTableHasCompositePrimaryKey() async throws {
        let playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let primaryKey = try await playaDB.dbQueue.read { db in
            try db.primaryKey("event_calendar_entries")
        }

        XCTAssertEqual(primaryKey.columns, ["event_id", "occurrence_key"])
    }
}
