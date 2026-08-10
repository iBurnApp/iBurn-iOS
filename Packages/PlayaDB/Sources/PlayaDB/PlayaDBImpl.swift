import Foundation
import CoreLocation
import MapKit
import GRDB
import PlayaAPI

/// Internal implementation of PlayaDB using GRDB
internal class PlayaDBImpl: PlayaDB {
    // MARK: - Database Connection

    /// On-disk databases use a DatabasePool (WAL) so reads run concurrently with
    /// writes — the first-launch seed import is one long write transaction and must
    /// not block UI reads. In-memory databases (tests) fall back to a DatabaseQueue,
    /// which is the only connection type that supports ":memory:" paths.
    internal let dbQueue: any DatabaseWriter  // Internal for testing
    private let dbPath: String

    // MARK: - Initialization

    init(dbPath: String? = nil) throws {
        // Use custom path or default to Documents directory
        if let customPath = dbPath {
            self.dbPath = customPath
        } else {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            self.dbPath = "\(documentsPath)/PlayaDB.sqlite"
        }

        if self.dbPath == ":memory:" || self.dbPath.hasPrefix("file::memory:") {
            self.dbQueue = try DatabaseQueue(path: self.dbPath)
        } else {
            self.dbQueue = try DatabasePool(path: self.dbPath)
        }

        // Initialize database schema
        try setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() throws {
        var migrator = DatabaseMigrator()

        // v1: the complete schema as of 2026-07. All DDL is idempotent
        // (IF NOT EXISTS / conditional column adds), so databases created before the
        // migrator was adopted record this migration as applied without conflicting
        // with the schema they already have. Register future schema changes as new
        // numbered migrations below — do not extend v1.
        migrator.registerMigration("v1-initial-schema") { db in
            // Create art_objects table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS art_objects (
                    uid TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    year INTEGER NOT NULL,
                    url TEXT,
                    contact_email TEXT,
                    hometown TEXT,
                    description TEXT,
                    artist TEXT,
                    category TEXT,
                    program TEXT,
                    donation_link TEXT,
                    location_string TEXT,
                    location_hour INTEGER,
                    location_minute INTEGER,
                    location_distance INTEGER,
                    location_category TEXT,
                    gps_latitude REAL,
                    gps_longitude REAL,
                    guided_tours INTEGER NOT NULL DEFAULT 0,
                    self_guided_tour_map INTEGER NOT NULL DEFAULT 0
                )
            """)
            
            // Create camp_objects table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS camp_objects (
                    uid TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    year INTEGER NOT NULL,
                    url TEXT,
                    contact_email TEXT,
                    hometown TEXT,
                    description TEXT,
                    landmark TEXT,
                    location_string TEXT,
                    location_location_string TEXT,
                    frontage TEXT,
                    intersection TEXT,
                    intersection_type TEXT,
                    dimensions TEXT,
                    exact_location TEXT,
                    gps_latitude REAL,
                    gps_longitude REAL
                )
            """)
            
            // Create event_objects table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS event_objects (
                    uid TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    year INTEGER NOT NULL,
                    event_id INTEGER,
                    description TEXT,
                    event_type_label TEXT NOT NULL,
                    event_type_code TEXT NOT NULL,
                    print_description TEXT NOT NULL DEFAULT '',
                    slug TEXT,
                    hosted_by_camp TEXT,
                    located_at_art TEXT,
                    other_location TEXT NOT NULL DEFAULT '',
                    check_location INTEGER NOT NULL DEFAULT 0,
                    url TEXT,
                    all_day INTEGER NOT NULL DEFAULT 0,
                    contact TEXT,
                    gps_latitude REAL,
                    gps_longitude REAL
                )
            """)
            
            // Create event_occurrences table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS event_occurrences (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id TEXT NOT NULL,
                    start_time TEXT NOT NULL,
                    end_time TEXT NOT NULL,
                    FOREIGN KEY (event_id) REFERENCES event_objects(uid)
                )
            """)
            
            // Create art_images table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS art_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    art_id TEXT NOT NULL,
                    thumbnail_url TEXT,
                    gallery_ref TEXT,
                    FOREIGN KEY (art_id) REFERENCES art_objects(uid)
                )
            """)
            
            // Create camp_images table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS camp_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    camp_id TEXT NOT NULL,
                    thumbnail_url TEXT,
                    FOREIGN KEY (camp_id) REFERENCES camp_objects(uid)
                )
            """)
            
            // Create mv_objects table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mv_objects (
                    uid TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    year INTEGER NOT NULL,
                    url TEXT,
                    contact_email TEXT,
                    hometown TEXT,
                    description TEXT,
                    artist TEXT,
                    donation_link TEXT,
                    tags_text TEXT
                )
            """)

            // Create mv_images table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mv_images (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    mv_id TEXT NOT NULL,
                    thumbnail_url TEXT,
                    FOREIGN KEY (mv_id) REFERENCES mv_objects(uid)
                )
            """)

            // Create mv_tags table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS mv_tags (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    mv_id TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    FOREIGN KEY (mv_id) REFERENCES mv_objects(uid)
                )
            """)

            // Create object_metadata table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS object_metadata (
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
            
            // Create update_info table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS update_info (
                    data_type TEXT PRIMARY KEY,
                    last_updated TEXT NOT NULL,
                    version TEXT,
                    total_count INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                )
            """)
            
            // Create thumbnail_colors table for cached extracted colors
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS thumbnail_colors (
                    object_id TEXT PRIMARY KEY,
                    bg_red REAL NOT NULL, bg_green REAL NOT NULL, bg_blue REAL NOT NULL, bg_alpha REAL NOT NULL,
                    primary_red REAL NOT NULL, primary_green REAL NOT NULL, primary_blue REAL NOT NULL, primary_alpha REAL NOT NULL,
                    secondary_red REAL NOT NULL, secondary_green REAL NOT NULL, secondary_blue REAL NOT NULL, secondary_alpha REAL NOT NULL,
                    detail_red REAL NOT NULL, detail_green REAL NOT NULL, detail_blue REAL NOT NULL, detail_alpha REAL NOT NULL
                )
            """)

            // Create user_map_pins table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS user_map_pins (
                    id TEXT PRIMARY KEY,
                    title TEXT,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    pin_type TEXT NOT NULL,
                    created_date TEXT NOT NULL,
                    modified_date TEXT NOT NULL
                )
            """)

            // Create indexes for performance
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_art_gps ON art_objects(gps_latitude, gps_longitude)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_camp_gps ON camp_objects(gps_latitude, gps_longitude)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_gps ON event_objects(gps_latitude, gps_longitude)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_occurrences_event_id ON event_occurrences(event_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_occurrences_start_time ON event_occurrences(start_time)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_art_images_art_id ON art_images(art_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_camp_images_camp_id ON camp_images(camp_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_mv_images_mv_id ON mv_images(mv_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_mv_tags_mv_id ON mv_tags(mv_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_mv_tags_tag ON mv_tags(tag)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_object_metadata_favorite ON object_metadata(is_favorite)")

            // Foreign key indexes for event lookups (camp crawl, event-at-art queries)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_hosted_by_camp ON event_objects(hosted_by_camp)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_located_at_art ON event_objects(located_at_art)")

            // Composite index for type+favorite queries (getFavorites, onlyFavorites filter)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_object_metadata_type_favorite ON object_metadata(object_type, is_favorite)")

            // Composite index for event occurrences (time-range queries)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_occurrences_event_start ON event_occurrences(event_id, start_time)")

            // Index for last_viewed queries (fetchRecentlyViewed)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_object_metadata_last_viewed ON object_metadata(last_viewed)")

            // end_time index: notExpired (the default list filter), happeningNow, and
            // activeWindow all constrain end_time; only start_time was indexed before.
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_event_occurrences_end_time ON event_occurrences(end_time)")

            // Migration: add first_viewed column for existing databases
            if try !db.columns(in: "object_metadata").contains(where: { $0.name == "first_viewed" }) {
                try db.execute(sql: "ALTER TABLE object_metadata ADD COLUMN first_viewed TEXT")
            }

            // Migration: add tags_text column to mv_objects
            if try !db.columns(in: "mv_objects").contains(where: { $0.name == "tags_text" }) {
                try db.execute(sql: "ALTER TABLE mv_objects ADD COLUMN tags_text TEXT")
            }

            // Migration: add tracking fields to update_info
            if try !db.columns(in: "update_info").contains(where: { $0.name == "file_name" }) {
                try db.execute(sql: "ALTER TABLE update_info ADD COLUMN file_name TEXT")
                try db.execute(sql: "ALTER TABLE update_info ADD COLUMN fetch_status TEXT NOT NULL DEFAULT 'unknown'")
                try db.execute(sql: "ALTER TABLE update_info ADD COLUMN last_checked_date TEXT")
                try db.execute(sql: "ALTER TABLE update_info ADD COLUMN fetch_date TEXT")
                try db.execute(sql: "ALTER TABLE update_info ADD COLUMN ingestion_date TEXT")
            }
        }

        // v2: dedicated favorite change stamp for last-writer-wins favorites sync.
        // `updated_at` can't be used for LWW because view tracking and notes writes
        // also bump it. Backfill existing favorites so they participate in sync.
        migrator.registerMigration("v2-favorite-sync") { db in
            try db.execute(sql: "ALTER TABLE object_metadata ADD COLUMN favorite_updated_at DATETIME")
            try db.execute(sql: "UPDATE object_metadata SET favorite_updated_at = updated_at WHERE is_favorite = 1")
        }

        // v3: visit status (raw VisitStatus: 0=unvisited, 1=visited, 2=wantToVisit)
        // with a dedicated change stamp, mirroring v2's favorite stamp, so favorite
        // and visit status can merge independently in last-writer-wins sync.
        migrator.registerMigration("v3-visit-status") { db in
            try db.execute(sql: "ALTER TABLE object_metadata ADD COLUMN visit_status INTEGER NOT NULL DEFAULT 0")
            try db.execute(sql: "ALTER TABLE object_metadata ADD COLUMN visit_status_updated_at DATETIME")
        }

        // v4: audio tour URL from the API's `audio_tour_url` field. Additive only —
        // the column is repopulated by every import, so no backfill is needed (the
        // next import writes it, and years without an audio tour leave it NULL).
        migrator.registerMigration("v4-audio-tour") { db in
            try db.execute(sql: "ALTER TABLE art_objects ADD COLUMN audio_tour_url TEXT")
        }

        // v5: per-occurrence EKEvent identifiers for calendar sync.
        //
        // Legacy (YapDatabase) stored one EKEvent identifier per event *occurrence*
        // because Yap split each API event into per-occurrence records. PlayaDB keeps
        // one row per API event plus an `event_occurrences` child table, so calendar
        // bookkeeping needs its own per-occurrence key.
        //
        // Key choice: (event_id, occurrence_key) where `occurrence_key` is the
        // occurrence's start time formatted as a fixed ISO-8601 UTC string
        // (see `EventCalendarEntry.occurrenceKey(for:)`). `event_occurrences.id` is an
        // AUTOINCREMENT rowid that `importFromData` wipes and reissues on every import,
        // so rowids can never survive a data refresh; the (event uid, start instant)
        // pair is the natural key that does. Start times also survive import unchanged
        // — only end times are ever rewritten (see `correctedOccurrenceTimes`).
        //
        // This table is intentionally NOT touched by `importFromData` (like
        // `object_metadata`, `thumbnail_colors` and `user_map_pins`), so calendar
        // identifiers survive data refreshes.
        migrator.registerMigration("v5-calendar-entries") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS event_calendar_entries (
                    event_id TEXT NOT NULL,
                    occurrence_key TEXT NOT NULL,
                    ek_event_identifier TEXT NOT NULL,
                    PRIMARY KEY (event_id, occurrence_key)
                )
            """)
        }

        // v6: soft deletes for user map pins. Pin sync exchanges whole snapshots
        // with last-writer-wins on modified_date; without a tombstone, a row
        // missing from a peer's snapshot is ambiguous ("never created there" vs
        // "deleted there") and deleted pins resurrect on the next push.
        //
        // Numbered v6, not v4: this was authored in parallel on `watchos-updates`,
        // which claimed v4 before `2026-updates` landed v4-audio-tour and
        // v5-calendar-entries. GRDB matches migrations by identifier string, so the
        // rename is what stops an install that already ran the old `v4-pin-sync`
        // from re-running this ALTER and failing on "duplicate column name".
        migrator.registerMigration("v6-pin-sync") { db in
            try db.execute(sql: "ALTER TABLE user_map_pins ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0")
        }

        try migrator.migrate(dbQueue)

        // Open-time maintenance rather than migrations: the FTS/R*Tree helpers carry
        // their own self-repair logic (legacy trigger replacement, minT-variant drop)
        // and are re-invoked by imports; the backfill and metadata fold are
        // data-dependent and idempotent.
        try dbQueue.write { db in
            // Create FTS5 virtual tables for full-text search
            try self.setupFTS5Tables(db)

            // Create R-Tree spatial index for geographic queries
            try self.setupRTreeIndex(db)

            // Backfill the occurrence index for installs whose DB predates it (existing users
            // don't re-import; PlayaDBSeeder only imports when update_info is empty).
            let occRtreeCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrence_rtree") ?? 0
            let occCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrences") ?? 0
            if occRtreeCount == 0, occCount > 0 {
                try self.rebuildOccurrenceRTree(db)
            }

            // Migration: fold occurrence-keyed event metadata into parent event rows.
            try self.migrateOccurrenceKeyedMetadata(db)

            // Migration: split legacy series favorites (one row on the bare event uid)
            // into per-occurrence rows. Runs after the fold above so rows it rescued are
            // included. Data-dependent: no-ops until event_occurrences is populated.
            try self.foldLegacyEventFavorites(db)

            // Migration: collapse duplicate home/bike pins written by the pre-upsert
            // placement path (see `collapseDuplicateSingletonPins`).
            try Self.collapseDuplicateSingletonPins(db)
        }
    }
    
    /// Content table + indexed columns backing each external-content FTS5 table.
    /// The FTS table is named "\(table)_fts" and always carries a leading
    /// `uid UNINDEXED` column so search results can be joined back by uid.
    private struct FTSTableConfig {
        let table: String
        let indexedColumns: [String]

        var ftsTable: String { "\(table)_fts" }
        var allColumns: [String] { ["uid"] + indexedColumns }
    }

    private static let ftsTableConfigs: [FTSTableConfig] = [
        FTSTableConfig(table: "art_objects", indexedColumns: ["name", "description", "artist", "hometown", "category"]),
        FTSTableConfig(table: "camp_objects", indexedColumns: ["name", "description", "landmark", "hometown"]),
        FTSTableConfig(table: "event_objects", indexedColumns: ["name", "description", "event_type_label", "print_description"]),
        FTSTableConfig(table: "mv_objects", indexedColumns: ["name", "description", "artist", "hometown", "tags_text"]),
    ]

    private func setupFTS5Tables(_ db: Database) throws {
        for config in Self.ftsTableConfigs {
            let indexed = config.indexedColumns.joined(separator: ",\n                    ")
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS \(config.ftsTable) USING fts5(
                    uid UNINDEXED,
                    \(indexed),
                    content=\(config.table),
                    content_rowid=rowid,
                    tokenize='porter unicode61'
                )
            """)
            try setupFTS5Triggers(db, config: config)
        }
    }

    /// Keeps an external-content FTS5 table in sync with its content table.
    ///
    /// External-content tables must be updated with FTS5's special 'delete' command,
    /// passing the OLD column values — a plain `DELETE FROM fts WHERE rowid = …` makes
    /// FTS5 read the content table for the values to un-index, but inside an AFTER
    /// DELETE/UPDATE trigger that row is already gone/changed, silently corrupting the
    /// index. Earlier versions shipped plain-DELETE triggers; those are detected below,
    /// replaced, and the index rebuilt once.
    private func setupFTS5Triggers(_ db: Database, config: FTSTableConfig) throws {
        let columnList = config.allColumns.joined(separator: ", ")
        let newValues = config.allColumns.map { "new.\($0)" }.joined(separator: ", ")
        let oldValues = config.allColumns.map { "old.\($0)" }.joined(separator: ", ")

        let ftsInsert = """
            INSERT INTO \(config.ftsTable)(rowid, \(columnList))
                    VALUES (new.rowid, \(newValues));
            """
        let ftsDelete = """
            INSERT INTO \(config.ftsTable)(\(config.ftsTable), rowid, \(columnList))
                    VALUES ('delete', old.rowid, \(oldValues));
            """

        // Migration: drop legacy triggers that used plain DELETE (index-corrupting).
        let legacyDeleteTriggerSQL = try String.fetchOne(db, sql: """
            SELECT sql FROM sqlite_master WHERE type = 'trigger' AND name = ?
            """, arguments: ["\(config.table)_ad"])
        let hadCorruptingTriggers: Bool
        if let sql = legacyDeleteTriggerSQL, !sql.contains("'delete'") {
            hadCorruptingTriggers = true
            try db.execute(sql: "DROP TRIGGER IF EXISTS \(config.table)_ai")
            try db.execute(sql: "DROP TRIGGER IF EXISTS \(config.table)_ad")
            try db.execute(sql: "DROP TRIGGER IF EXISTS \(config.table)_au")
        } else {
            hadCorruptingTriggers = false
        }

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS \(config.table)_ai AFTER INSERT ON \(config.table) BEGIN
                \(ftsInsert)
            END
        """)
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS \(config.table)_ad AFTER DELETE ON \(config.table) BEGIN
                \(ftsDelete)
            END
        """)
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS \(config.table)_au AFTER UPDATE ON \(config.table) BEGIN
                \(ftsDelete)
                \(ftsInsert)
            END
        """)

        if hadCorruptingTriggers {
            // The old triggers may have left the index inconsistent with the content table.
            try db.execute(sql: "INSERT INTO \(config.ftsTable)(\(config.ftsTable)) VALUES('rebuild')")
        }
    }

    /// Drops the FTS and spatial per-row sync triggers so bulk imports don't pay
    /// per-row index maintenance. The import rebuilds every index wholesale and
    /// recreates the triggers (setupFTS5Tables / setupRTreeIndex) before committing.
    private static func dropIndexSyncTriggers(_ db: Database) throws {
        for config in ftsTableConfigs {
            for suffix in ["ai", "ad", "au"] {
                try db.execute(sql: "DROP TRIGGER IF EXISTS \(config.table)_\(suffix)")
            }
        }
        for trigger in [
            "art_spatial_insert", "art_spatial_delete", "art_spatial_update",
            "camp_spatial_insert", "camp_spatial_delete", "camp_spatial_update",
            "event_spatial_insert", "event_spatial_delete", "event_spatial_update",
            "event_occurrence_rtree_insert", "event_occurrence_rtree_delete",
            "event_occurrence_rtree_event_update",
        ] {
            try db.execute(sql: "DROP TRIGGER IF EXISTS \(trigger)")
        }
    }
    
    private func setupRTreeIndex(_ db: Database) throws {
        // Create R-Tree virtual table for spatial indexing
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS spatial_index USING rtree(
                id,
                minLat, maxLat,
                minLon, maxLon
            )
        """)
        
        // Create a mapping table to track which object each spatial entry refers to
        try db.execute(sql: """
            CREATE TABLE IF NOT EXISTS spatial_objects (
                spatial_id INTEGER PRIMARY KEY,
                object_type TEXT NOT NULL,
                object_uid TEXT NOT NULL,
                UNIQUE(object_type, object_uid)
            )
        """)
        
        // Insert/delete/update triggers keeping the point R*Tree in sync for each
        // GPS-bearing object table. The update triggers matter for the embargo drop:
        // if location data ever arrives as an in-place UPDATE of gps columns rather
        // than a full reimport, the R*Tree must follow or region queries silently
        // miss those rows.
        let spatialTables: [(type: String, table: String)] = [
            ("art", "art_objects"),
            ("camp", "camp_objects"),
            ("event", "event_objects"),
        ]
        for config in spatialTables {
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS \(config.type)_spatial_insert AFTER INSERT ON \(config.table)
                WHEN NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL
                BEGIN
                    INSERT INTO spatial_objects (object_type, object_uid) VALUES ('\(config.type)', NEW.uid);
                    INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                    VALUES (last_insert_rowid(), NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude);
                END
            """)

            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS \(config.type)_spatial_delete AFTER DELETE ON \(config.table)
                WHEN OLD.gps_latitude IS NOT NULL AND OLD.gps_longitude IS NOT NULL
                BEGIN
                    DELETE FROM spatial_index WHERE id = (
                        SELECT spatial_id FROM spatial_objects
                        WHERE object_type = '\(config.type)' AND object_uid = OLD.uid
                    );
                    DELETE FROM spatial_objects WHERE object_type = '\(config.type)' AND object_uid = OLD.uid;
                END
            """)

            // Drop any stale entry, then re-add when the new coordinate is usable.
            // The second insert is keyed off the mapping table (not last_insert_rowid)
            // so the NULL-coordinate case degrades to two no-op inserts.
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS \(config.type)_spatial_update
                AFTER UPDATE OF gps_latitude, gps_longitude ON \(config.table)
                BEGIN
                    DELETE FROM spatial_index WHERE id = (
                        SELECT spatial_id FROM spatial_objects
                        WHERE object_type = '\(config.type)' AND object_uid = NEW.uid
                    );
                    DELETE FROM spatial_objects WHERE object_type = '\(config.type)' AND object_uid = NEW.uid;
                    INSERT INTO spatial_objects (object_type, object_uid)
                    SELECT '\(config.type)', NEW.uid
                    WHERE NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL;
                    INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                    SELECT so.spatial_id, NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude
                    FROM spatial_objects so
                    WHERE so.object_type = '\(config.type)' AND so.object_uid = NEW.uid
                      AND NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL;
                END
            """)
        }

        // Spatial R*Tree over event occurrences (point index keyed by event_occurrences.id,
        // so no mapping table is needed). lat/lon come from the parent event's denormalized
        // GPS; this is a pure spatial prefilter for region-scoped event queries.
        //
        // Migration: an earlier version added minT/maxT time columns. They were never queried
        // (occurrenceIDsInRegion is spatial-only) and, for occurrences whose stored date
        // strings don't parse via SQLite strftime (or whose end precedes start), produced
        // minT > maxT and tripped the rtree's (minT<=maxT) constraint — failing the seed
        // import outright. Drop that variant and recreate the index spatial-only.
        let rtreeColumns = try Row.fetchAll(db, sql: "PRAGMA table_info(event_occurrence_rtree)")
            .compactMap { $0["name"] as String? }
        if rtreeColumns.contains("minT") {
            try db.execute(sql: "DROP TRIGGER IF EXISTS event_occurrence_rtree_insert")
            try db.execute(sql: "DROP TRIGGER IF EXISTS event_occurrence_rtree_delete")
            try db.execute(sql: "DROP TABLE IF EXISTS event_occurrence_rtree")
        }
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS event_occurrence_rtree USING rtree(
                id,
                minLat, maxLat,
                minLon, maxLon
            )
        """)

        // Maintain the occurrence index on direct writes (import also rebuilds it wholesale).
        // lat/lon come from the parent event's denormalized GPS.
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_occurrence_rtree_insert
            AFTER INSERT ON event_occurrences
            WHEN EXISTS (
                SELECT 1 FROM event_objects e
                WHERE e.uid = NEW.event_id
                  AND e.gps_latitude IS NOT NULL AND e.gps_longitude IS NOT NULL
            )
            BEGIN
                INSERT OR REPLACE INTO event_occurrence_rtree (id, minLat, maxLat, minLon, maxLon)
                SELECT NEW.id, e.gps_latitude, e.gps_latitude, e.gps_longitude, e.gps_longitude
                FROM event_objects e WHERE e.uid = NEW.event_id;
            END
        """)
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_occurrence_rtree_delete
            AFTER DELETE ON event_occurrences
            BEGIN
                DELETE FROM event_occurrence_rtree WHERE id = OLD.id;
            END
        """)

        // Event GPS updates must also refresh the denormalized occurrence R*Tree.
        // Created after event_occurrence_rtree exists — SQLite validates referenced
        // tables when the trigger is created.
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_occurrence_rtree_event_update
            AFTER UPDATE OF gps_latitude, gps_longitude ON event_objects
            BEGIN
                DELETE FROM event_occurrence_rtree WHERE id IN (
                    SELECT id FROM event_occurrences WHERE event_id = NEW.uid
                );
                INSERT OR REPLACE INTO event_occurrence_rtree (id, minLat, maxLat, minLon, maxLon)
                SELECT o.id, NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude
                FROM event_occurrences o
                WHERE o.event_id = NEW.uid
                  AND NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL;
            END
        """)
    }

    /// Rebuild the occurrence spatial index from current data. Indexes each occurrence whose
    /// parent event has GPS, using the event's denormalized coordinate as a point.
    func rebuildOccurrenceRTree(_ db: Database) throws {
        try db.execute(sql: "DELETE FROM event_occurrence_rtree")
        try db.execute(sql: """
            INSERT OR REPLACE INTO event_occurrence_rtree (id, minLat, maxLat, minLon, maxLon)
            SELECT o.id, e.gps_latitude, e.gps_latitude, e.gps_longitude, e.gps_longitude
            FROM event_occurrences o
            JOIN event_objects e ON e.uid = o.event_id
            WHERE e.gps_latitude IS NOT NULL AND e.gps_longitude IS NOT NULL
            """)
    }

    /// Occurrence ids whose host location falls within `region`, via the spatial R*Tree.
    /// Time filtering stays in SQL. Used to push event region filtering into the query
    /// instead of filtering rows client-side.
    private func occurrenceIDsInRegion(_ db: Database, region: MKCoordinateRegion) throws -> [Int64] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        return try Int64.fetchAll(db, sql: """
            SELECT id FROM event_occurrence_rtree
            WHERE maxLat >= ? AND minLat <= ? AND maxLon >= ? AND minLon <= ?
            """, arguments: [minLat, maxLat, minLon, maxLon])
    }

    // MARK: - Data Access Methods
    
    func fetchArt() async throws -> [ArtObject] {
        try await dbQueue.read { db in
            try ArtObject.fetchAll(db)
        }
    }

    func fetchCamps() async throws -> [CampObject] {
        try await dbQueue.read { db in
            try CampObject.fetchAll(db)
        }
    }

    func fetchEvents() async throws -> [EventObjectOccurrence] {
        try await dbQueue.read { db in
            let events = try EventObject.fetchAll(db)
            return try eventObjectOccurrences(for: events, db: db)
        }
    }
    
    func fetchEvents(on date: Date) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            // Find occurrences that overlap with this day
            // Event overlaps if: starts before day ends AND ends after day starts
            let occurrences = try EventOccurrence
                .filter(Column("start_time") < dayEnd && Column("end_time") > dayStart)
                .fetchAll(db)

            return try eventObjectOccurrences(for: occurrences, db: db)
        }
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            let occurrences = try EventOccurrence
                .filter(Column("start_time") < endDate && Column("end_time") > startDate)
                .fetchAll(db)

            return try eventObjectOccurrences(for: occurrences, db: db)
        }
    }
    
    func fetchCurrentEvents(_ now: Date = Date()) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            let occurrences = try EventOccurrence
                .filter(Column("start_time") <= now && Column("end_time") > now)
                .fetchAll(db)

            return try eventObjectOccurrences(for: occurrences, db: db)
        }
    }
    
    func fetchUpcomingEvents(within hours: Int = 24, from now: Date = Date()) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            let futureTime = now.addingTimeInterval(TimeInterval(hours * 3600))

            let occurrences = try EventOccurrence
                .filter(Column("start_time") > now && Column("start_time") <= futureTime)
                .order(Column("start_time"))
                .fetchAll(db)

            return try eventObjectOccurrences(for: occurrences, db: db)
        }
    }
    
    func fetchObjects(in region: MKCoordinateRegion) async throws -> [any DataObject] {
        let result = try await dbQueue.read { db -> ([ArtObject], [CampObject], [EventObject]) in
            // Calculate bounding box
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2

            // Use R-Tree spatial index for efficient querying
            let spatialSQL = """
                SELECT so.object_type, so.object_uid
                FROM spatial_index si
                JOIN spatial_objects so ON si.id = so.spatial_id
                WHERE si.minLat >= ? AND si.maxLat <= ?
                  AND si.minLon >= ? AND si.maxLon <= ?
            """

            let rows = try Row.fetchAll(db, sql: spatialSQL, arguments: [minLat, maxLat, minLon, maxLon])

            // Group UIDs by type for batch fetching
            var artUIDs: [String] = []
            var campUIDs: [String] = []
            var eventUIDs: [String] = []

            for row in rows {
                let objectType: String = row["object_type"]
                let objectUID: String = row["object_uid"]

                switch objectType {
                case "art":
                    artUIDs.append(objectUID)
                case "camp":
                    campUIDs.append(objectUID)
                case "event":
                    eventUIDs.append(objectUID)
                default:
                    break
                }
            }

            let artObjects = try ArtObject
                .filter(artUIDs.contains(Column("uid")))
                .fetchAll(db)
            let campObjects = try CampObject
                .filter(campUIDs.contains(Column("uid")))
                .fetchAll(db)
            let eventObjects = try EventObject
                .filter(eventUIDs.contains(Column("uid")))
                .fetchAll(db)

            return (artObjects, campObjects, eventObjects)
        }

        var objects: [any DataObject] = []
        objects.append(contentsOf: result.0)
        objects.append(contentsOf: result.1)
        objects.append(contentsOf: result.2)
        return objects
    }
    
    func searchObjects(_ query: String) async throws -> [any DataObject] {
        let result = try await dbQueue.read { db -> ([ArtObject], [CampObject], [EventObject], [MutantVehicleObject]) in
            // Prepare search query for FTS5
            // Wrap in double quotes to treat as a phrase, escaping internal quotes
            let sanitized = query
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sanitized.isEmpty else {
                return ([], [], [], [])
            }
            let ftsQuery = "\"\(sanitized)\""

            let artSQL = """
                SELECT art_objects.*
                FROM art_objects
                JOIN art_objects_fts ON art_objects.rowid = art_objects_fts.rowid
                WHERE art_objects_fts MATCH ?
                ORDER BY rank
            """
            let artObjects = try ArtObject.fetchAll(db, sql: artSQL, arguments: [ftsQuery])

            let campSQL = """
                SELECT camp_objects.*
                FROM camp_objects
                JOIN camp_objects_fts ON camp_objects.rowid = camp_objects_fts.rowid
                WHERE camp_objects_fts MATCH ?
                ORDER BY rank
            """
            let campObjects = try CampObject.fetchAll(db, sql: campSQL, arguments: [ftsQuery])

            let eventSQL = """
                SELECT event_objects.*
                FROM event_objects
                JOIN event_objects_fts ON event_objects.rowid = event_objects_fts.rowid
                WHERE event_objects_fts MATCH ?
                ORDER BY rank
            """
            let eventObjects = try EventObject.fetchAll(db, sql: eventSQL, arguments: [ftsQuery])

            let mvSQL = """
                SELECT mv_objects.*
                FROM mv_objects
                JOIN mv_objects_fts ON mv_objects.rowid = mv_objects_fts.rowid
                WHERE mv_objects_fts MATCH ?
                ORDER BY rank
            """
            let mvObjects = try MutantVehicleObject.fetchAll(db, sql: mvSQL, arguments: [ftsQuery])

            return (artObjects, campObjects, eventObjects, mvObjects)
        }

        var objects: [any DataObject] = []
        objects.append(contentsOf: result.0)
        objects.append(contentsOf: result.1)
        objects.append(contentsOf: result.2)
        objects.append(contentsOf: result.3)
        return objects
    }

    // MARK: - Single Object Fetch

    func fetchArt(uid: String) async throws -> ArtObject? {
        try await dbQueue.read { db in
            try ArtObject.filter(Column("uid") == uid).fetchOne(db)
        }
    }

    func fetchCamp(uid: String) async throws -> CampObject? {
        try await dbQueue.read { db in
            try CampObject.filter(Column("uid") == uid).fetchOne(db)
        }
    }

    func fetchEvent(uid: String) async throws -> EventObject? {
        try await dbQueue.read { db in
            try EventObject.filter(Column("uid") == uid).fetchOne(db)
        }
    }

    func fetchOccurrences(forEventUID uid: String) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            guard let event = try EventObject.filter(Column("uid") == uid).fetchOne(db) else {
                return []
            }
            return try eventObjectOccurrences(for: [event], db: db)
        }
        return events.sorted { $0.startDate < $1.startDate }
    }

    func fetchEvents(hostedByCampUID campUID: String) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            let eventObjects = try EventObject
                .filter(Column("hosted_by_camp") == campUID)
                .fetchAll(db)
            return try eventObjectOccurrences(for: eventObjects, db: db)
        }
        return events.sorted { $0.startDate < $1.startDate }
    }

    func fetchEvents(locatedAtArtUID artUID: String) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            let eventObjects = try EventObject
                .filter(Column("located_at_art") == artUID)
                .fetchAll(db)
            return try eventObjectOccurrences(for: eventObjects, db: db)
        }
        return events.sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Mutant Vehicle Data Access

    func fetchMutantVehicles() async throws -> [MutantVehicleObject] {
        try await dbQueue.read { db in
            try MutantVehicleObject.fetchAll(db)
        }
    }

    func fetchMutantVehicles(filter: MutantVehicleFilter) async throws -> [MutantVehicleObject] {
        try await dbQueue.read { db in
            try self.mutantVehicleRequest(filter: filter).fetchAll(db)
        }
    }

    func fetchMutantVehicle(uid: String) async throws -> MutantVehicleObject? {
        try await dbQueue.read { db in
            try MutantVehicleObject.filter(Column("uid") == uid).fetchOne(db)
        }
    }

    func fetchMutantVehicleImageURLs() async throws -> [String: URL] {
        try await fetchFirstThumbnailURLs(table: "mv_images", ownerColumn: "mv_id")
    }

    func fetchArtImageURLs() async throws -> [String: URL] {
        try await fetchFirstThumbnailURLs(table: "art_images", ownerColumn: "art_id")
    }

    func fetchCampImageURLs() async throws -> [String: URL] {
        try await fetchFirstThumbnailURLs(table: "camp_images", ownerColumn: "camp_id")
    }

    /// First (lowest-id) thumbnail URL per owning object, aggregated in SQL rather
    /// than decoding every image row. SQLite's bare-column-with-MIN semantics
    /// guarantee thumbnail_url comes from the MIN(id) row.
    private func fetchFirstThumbnailURLs(table: String, ownerColumn: String) async throws -> [String: URL] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT \(ownerColumn) AS owner_id, thumbnail_url, MIN(id)
                FROM \(table)
                WHERE thumbnail_url IS NOT NULL
                GROUP BY \(ownerColumn)
                """)
            var result: [String: URL] = [:]
            for row in rows {
                let ownerId: String = row["owner_id"]
                if let urlString: String = row["thumbnail_url"], let url = URL(string: urlString) {
                    result[ownerId] = url
                }
            }
            return result
        }
    }

    // MARK: - Filtered Data Access (Internal Request Builders)

    /// Build an art query from filter options (internal - uses GRDB types)
    internal func artRequest(filter: ArtFilter) -> QueryInterfaceRequest<ArtObject> {
        var request = ArtObject.all()

        // Apply year filter
        if let year = filter.year {
            request = request.forYear(year)
        }

        // Apply region filter (also filters to only objects with GPS coordinates)
        if let region = filter.region {
            request = request.inRegion(region).withLocation()
        }

        // Apply text search filter
        if let searchText = filter.searchText {
            request = request.matching(searchText: searchText)
        }

        // Apply favorites filter
        if filter.onlyFavorites {
            request = request.onlyFavorites(ofType: .art)
        }

        if filter.onlyWithEvents {
            request = request.withEvents()
        }

        // Apply audio-tour filter (nil = no filter)
        if let hasAudioTour = filter.hasAudioTour {
            request = request.hasAudioTour(hasAudioTour)
        }

        // Default ordering
        return request.orderedByName()
    }

    /// Build a camp query from filter options (internal - uses GRDB types)
    internal func campRequest(filter: CampFilter) -> QueryInterfaceRequest<CampObject> {
        var request = CampObject.all()

        // Apply year filter
        if let year = filter.year {
            request = request.forYear(year)
        }

        // Apply region filter (also filters to only objects with GPS coordinates)
        if let region = filter.region {
            request = request.inRegion(region).withLocation()
        }

        // Apply text search filter
        if let searchText = filter.searchText {
            request = request.matching(searchText: searchText)
        }

        // Apply favorites filter
        if filter.onlyFavorites {
            request = request.onlyFavorites(ofType: .camp)
        }

        // Default ordering
        return request.orderedByName()
    }

    /// Build a mutant vehicle query from filter options
    internal func mutantVehicleRequest(filter: MutantVehicleFilter) -> QueryInterfaceRequest<MutantVehicleObject> {
        var request = MutantVehicleObject.all()

        if let year = filter.year {
            request = request.forYear(year)
        }

        if let searchText = filter.searchText {
            request = request.matching(searchText: searchText)
        }

        if filter.onlyFavorites {
            request = request.onlyFavorites(ofType: .mutantVehicle)
        }

        if let tag = filter.tag {
            request = request.filter(sql: """
                EXISTS (
                    SELECT 1
                    FROM mv_tags
                    WHERE mv_tags.mv_id = mv_objects.uid
                      AND mv_tags.tag = ?
                )
            """, arguments: [tag])
        }

        return request.orderedByName()
    }

    /// Build an event occurrence query from filter options (internal - uses GRDB types).
    /// `matchingEventUIDs` constrains occurrences to events whose UIDs match an FTS query;
    /// pass `nil` to skip search filtering.
    internal func eventOccurrenceRequest(
        filter: EventFilter,
        matchingEventUIDs: Set<String>? = nil
    ) -> QueryInterfaceRequest<EventOccurrence> {
        var request = EventOccurrence.all()

        // Apply time-based filters
        if filter.happeningNow {
            // Only currently happening events (overrides other time filters)
            request = request.happeningNow()
        } else if let hours = filter.startingWithinHours {
            // Events starting within N hours
            request = request.startingWithin(hours: hours)
        } else if !filter.includeExpired {
            // Exclude expired events
            request = request.notExpired()
        }

        // Apply date range filters
        if let startDate = filter.startDate {
            request = request.filter(EventOccurrence.Columns.startTime >= startDate)
        }
        if let endDate = filter.endDate {
            request = request.filter(EventOccurrence.Columns.startTime < endDate)
        }

        // Overlap window: occurrences whose [start, end) interval intersects the window.
        // Same predicate form as fetchEvents(from:to:); unlike startDate/endDate this keeps
        // events already in progress when the window opened.
        if let window = filter.activeWindow {
            request = request
                .filter(EventOccurrence.Columns.startTime < window.end)
                .filter(EventOccurrence.Columns.endTime > window.start)
        }

        // Max-duration cap: hide occurrences whose [start, end) span EXCEEDS maxDuration
        // seconds. Applied here so every filtered path (joined browse + non-joined search/
        // fetch) inherits it uniformly.
        //
        // start_time/end_time are stored as TEXT (GRDB's default Date encoding,
        // "YYYY-MM-DD HH:MM:SS.SSS", UTC), so the span is computed in SQL via julianday()
        // (fractional days) scaled to seconds — matching the notExpired()/happeningNow()
        // date-comparison idioms elsewhere, which also rely on GRDB's TEXT date encoding.
        // Inclusive (<=): an occurrence exactly at the limit stays visible. The 0.5s
        // tolerance absorbs julianday()'s double-precision rounding (worst case ~1e-4 s at
        // these magnitudes) so an exactly-at-limit occurrence is never dropped by float
        // error; it stays far below the 60s granularity of real event durations.
        if let maxDuration = filter.maxDuration {
            request = request.filter(sql: """
                (julianday(event_occurrences.end_time) - julianday(event_occurrences.start_time)) * 86400.0 <= ? + 0.5
                """, arguments: [maxDuration])
        }

        // FTS5 search constraint (UIDs pre-resolved against event_objects_fts)
        if let uids = matchingEventUIDs {
            request = request.filter(uids.contains(EventOccurrence.Columns.eventId))
        }

        // Default ordering by start time
        return request.orderedByStartTime()
    }

    /// JOIN-based variant of `eventObjectOccurrences(filter:db:)` that fetches occurrence +
    /// parent event + host (camp or art) in a single SQL JOIN. Replaces the prior
    /// 4-sequential-query pattern (occurrences → events IN(…) → camps IN(…) → arts IN(…)).
    ///
    /// Pushes favorites / year / event-type filters into SQL. Region/bbox filter remains
    /// client-side (sparse GPS on events; no spatial index payoff).
    internal func eventObjectOccurrencesJoined(
        filter: EventFilter,
        db: Database
    ) throws -> [EventObjectOccurrence] {
        // FTS5 pre-resolve against event_objects_fts (same pattern as the non-joined helper).
        let matchingEventUIDs: Set<String>?
        if let searchText = filter.searchText, !searchText.isEmpty {
            let uids = try EventObject.all()
                .matching(searchText: searchText)
                .select(EventObject.Columns.uid, as: String.self)
                .fetchAll(db)
            matchingEventUIDs = Set(uids)
        } else {
            matchingEventUIDs = nil
        }

        // Base occurrence query (date/time/notExpired/search constraints applied via existing helper).
        // `forKey("event")` overrides GRDB's default scope key (destination type name) so the
        // joined row exposes the EventObject row under `row.scopes["event"]`, matching
        // EventOccurrenceJoinedRow.init(row:).
        let eventAssociation = EventOccurrence.event.forKey("event")
        var request = eventOccurrenceRequest(
            filter: filter,
            matchingEventUIDs: matchingEventUIDs
        )
        .including(required: eventAssociation
            .including(optional: EventObject.hostedCamp)
            .including(optional: EventObject.locatedArt))

        // Push remaining filters into SQL.
        //
        // Favorites are keyed per occurrence (`EventFavoriteKey`), whose id embeds an
        // ISO-8601 rendering of the start instant. Rather than have SQLite re-derive that
        // string from the stored date, SQL narrows to events with *any* favorited row and
        // the exact per-occurrence rule runs in Swift below — same rule, same one place.
        let favoriteIndex: EventFavoriteIndex?
        if filter.onlyFavorites {
            let index = try EventFavoriteIndex.load(db)
            let candidates = index.candidateEventUIDs
            guard !candidates.isEmpty else { return [] }
            request = request.filter(candidates.contains(EventOccurrence.Columns.eventId))
            favoriteIndex = index
        } else {
            favoriteIndex = nil
        }
        if let year = filter.year {
            request = request.joining(required: eventAssociation
                .filter(EventObject.Columns.year == year))
        }
        if let codes = filter.eventTypeCodes, !codes.isEmpty {
            request = request.joining(required: eventAssociation
                .filter(codes.contains(EventObject.Columns.eventTypeCode)))
        }
        // Region → indexed prefilter on occurrence ids (R*Tree), matching the non-joined path.
        if let region = filter.region {
            let regionIDs = try occurrenceIDsInRegion(db, region: region)
            request = request.filter(regionIDs.contains(EventOccurrence.Columns.id))
        }

        let joined = try EventOccurrenceJoinedRow.fetchAll(db, request)
        let inflated = joined.map { $0.toEventObjectOccurrence() }
        guard let favoriteIndex else { return inflated }
        return inflated.filter { favoriteIndex.isFavorite($0) }
    }

    private func eventObjectOccurrences(
        filter: EventFilter,
        db: Database
    ) throws -> [EventObjectOccurrence] {
        // Pre-resolve FTS5 search to event UIDs against event_objects_fts (parent table).
        // .matching(searchText:) keys off RowDecoder.databaseTableName + "_fts", and the
        // events FTS table indexes EventObject columns (name/description/event_type_label/
        // print_description), not EventOccurrence — so the match must run on EventObject.
        let matchingEventUIDs: Set<String>?
        if let searchText = filter.searchText, !searchText.isEmpty {
            let uids = try EventObject.all()
                .matching(searchText: searchText)
                .select(EventObject.Columns.uid, as: String.self)
                .fetchAll(db)
            matchingEventUIDs = Set(uids)
        } else {
            matchingEventUIDs = nil
        }

        var occurrenceRequest = eventOccurrenceRequest(
            filter: filter,
            matchingEventUIDs: matchingEventUIDs
        )
        // Region → indexed prefilter on occurrence ids (R*Tree). Time/type stay exact below.
        if let region = filter.region {
            let regionIDs = try occurrenceIDsInRegion(db, region: region)
            occurrenceRequest = occurrenceRequest.filter(regionIDs.contains(EventOccurrence.Columns.id))
        }
        // Same narrowing as `eventObjectOccurrencesJoined`: events with any favorited row
        // in SQL, the exact per-occurrence rule in Swift.
        let favoriteIndex: EventFavoriteIndex?
        if filter.onlyFavorites {
            let index = try EventFavoriteIndex.load(db)
            let candidates = index.candidateEventUIDs
            guard !candidates.isEmpty else { return [] }
            occurrenceRequest = occurrenceRequest
                .filter(candidates.contains(EventOccurrence.Columns.eventId))
            favoriteIndex = index
        } else {
            favoriteIndex = nil
        }

        let occurrences = try occurrenceRequest.fetchAll(db)

        let pairs = try eventObjectOccurrences(for: occurrences, db: db)

        return pairs.filter { pair in
            let event = pair.event

            if let favoriteIndex, !favoriteIndex.isFavorite(pair) {
                return false
            }

            if let year = filter.year, event.year != year {
                return false
            }

            // Region is filtered in SQL via the occurrence R*Tree prefilter (see above).

            if let allowedTypes = filter.eventTypeCodes, !allowedTypes.isEmpty {
                if !allowedTypes.contains(event.eventTypeCode) {
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Filtered Data Access (Public API)

    func fetchArt(filter: ArtFilter) async throws -> [ArtObject] {
        try await dbQueue.read { db in
            try artRequest(filter: filter).fetchAll(db)
        }
    }

    func fetchCamps(filter: CampFilter) async throws -> [CampObject] {
        try await dbQueue.read { db in
            try campRequest(filter: filter).fetchAll(db)
        }
    }

    func fetchEvents(filter: EventFilter) async throws -> [EventObjectOccurrence] {
        try await dbQueue.read { db in
            try eventObjectOccurrences(filter: filter, db: db)
        }
    }

    // MARK: - Filtered Observation Helpers

    /// Metadata region for list observations, narrowed to the columns list rows
    /// actually render (favorite state, notes). Excludes first/last_viewed and the
    /// timestamps so detail-screen "mark viewed" writes don't re-run list queries —
    /// with the full-table region, every setLastViewed re-ran the 8k-row event JOIN.
    /// Row inserts/deletes still trigger regardless of column selection.
    private var listMetadataRegion: any DatabaseRegionConvertible {
        ObjectMetadata.select(
            ObjectMetadata.Columns.objectType,
            ObjectMetadata.Columns.objectId,
            ObjectMetadata.Columns.isFavorite,
            ObjectMetadata.Columns.userNotes
        )
    }

    /// Observe objects as fully-inflated ListRows. Fetches objects, metadata, and
    /// thumbnail colors in a single read transaction.
    /// - Parameter regions: Explicit observation regions. When provided, only changes to these
    ///   regions trigger re-evaluation. The fetch closure can read from any table freely.
    ///   When nil, GRDB auto-tracks all tables accessed in the fetch closure.
    /// - Parameter favoriteIdentity: When the object's favorite bit lives on a *different*
    ///   `object_metadata` row than its notes/visits/views — which is the case for event
    ///   occurrences (see ``EventFavoriteKey``) — this returns that row's id, and the
    ///   inflated `ListRow.metadata` gets `isFavorite` overlaid from it.
    private func observeListRows<T: Equatable>(
        type: DataObjectType,
        ids: @escaping ([T]) -> [String],
        favoriteIdentity: (@Sendable (T) -> String)? = nil,
        regions: [any DatabaseRegionConvertible]? = nil,
        value: @escaping @Sendable (Database) throws -> [T],
        onChange: @escaping ([ListRow<T>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        let typeRaw = type.rawValue
        let fetch: @Sendable (Database) throws -> [ListRow<T>] = { db in
            let objects = try value(db)
            let objectIDs = ids(objects)
            guard !objectIDs.isEmpty else { return [] }

            // Batch fetch full metadata in same transaction
            let allMeta = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == typeRaw)
                .filter(objectIDs.contains(ObjectMetadata.Columns.objectId))
                .fetchAll(db)
            let metaByID = Dictionary(uniqueKeysWithValues: allMeta.map { ($0.objectId, $0) })

            // Batch fetch thumbnail colors in same transaction
            let allColors = try ThumbnailColors
                .filter(objectIDs.contains(ThumbnailColors.Columns.objectId))
                .fetchAll(db)
            let colorsByID = Dictionary(uniqueKeysWithValues: allColors.map { ($0.objectId, $0) })

            // One read of the event metadata slice covers every row's favorite overlay.
            let favoriteIndex = favoriteIdentity == nil ? nil : try EventFavoriteIndex.load(db)

            return objects.map { obj in
                let uid = ids([obj]).first ?? ""
                var metadata = metaByID[uid]
                if let favoriteIdentity, let favoriteIndex {
                    let isFavorite = favoriteIndex.isFavorite(identity: favoriteIdentity(obj))
                    if metadata != nil {
                        metadata?.isFavorite = isFavorite
                    } else if isFavorite {
                        // No parent row (never viewed, no notes) but the occurrence is
                        // favorited: synthesize the record the row needs to draw a
                        // filled heart. Not persisted — it's a read-time projection.
                        // Fixed timestamps, not `Date()`: these values feed the
                        // observation's `removeDuplicates`, and a fresh `now` on every
                        // fetch would make every emission look like a change.
                        metadata = ObjectMetadata(
                            objectType: typeRaw,
                            objectId: uid,
                            isFavorite: true,
                            createdAt: .distantPast,
                            updatedAt: .distantPast
                        )
                    }
                }
                return ListRow(
                    object: obj,
                    metadata: metadata,
                    thumbnailColors: colorsByID[uid]
                )
            }
        }

        // removeDuplicates: broad tracked regions (whole object_metadata / thumbnail_colors
        // tables) mean unrelated writes re-run the fetch; suppress emissions whose result
        // is value-identical so the UI doesn't re-diff thousands of rows for nothing.
        let observation: ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<[ListRow<T>]>>>
        if let regions {
            observation = ValueObservation.tracking(regions: regions, fetch: fetch).removeDuplicates()
        } else {
            observation = ValueObservation.tracking(fetch).removeDuplicates()
        }
        let cancellable = observation.start(
            in: dbQueue,
            onError: onError,
            onChange: onChange
        )
        return PlayaDBObservationToken(cancellable)
    }

    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ListRow<ArtObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        // FTS/spatial subquery tables only change via art_objects triggers or the
        // import (which rewrites art_objects too), so tracking the content table
        // covers them. event_objects matters only for the onlyWithEvents EXISTS.
        var regions: [any DatabaseRegionConvertible] = [
            ArtObject.all(), listMetadataRegion, ThumbnailColors.all()
        ]
        if filter.onlyWithEvents {
            regions.append(EventObject.all())
        }
        return observeListRows(
            type: .art,
            ids: { $0.map(\.uid) },
            regions: regions,
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.artRequest(filter: filter).fetchAll(db)
            },
            onChange: onChange,
            onError: onError
        )
    }

    func observeCamps(
        filter: CampFilter,
        onChange: @escaping ([ListRow<CampObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observeListRows(
            type: .camp,
            ids: { $0.map(\.uid) },
            regions: [CampObject.all(), listMetadataRegion, ThumbnailColors.all()],
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.campRequest(filter: filter).fetchAll(db)
            },
            onChange: onChange,
            onError: onError
        )
    }

    func observeEvents(
        filter: EventFilter,
        onChange: @escaping ([ListRow<EventObjectOccurrence>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        // Tracked regions: event tables drive membership/order; narrowed metadata and
        // ThumbnailColors feed ListRow inflation (favorite toggles must refresh hearts
        // and the favorites-only map layer; cached-color writes refresh row chrome).
        // Camp/art tables are intentionally excluded — the fetch JOINs them for host
        // data, but host edits don't reshuffle the event list.
        observeListRows(
            type: .event,
            ids: { $0.map { $0.event.uid } },
            favoriteIdentity: { $0.favoriteIdentity },
            regions: [
                EventOccurrence.all(),
                EventObject.all(),
                listMetadataRegion,
                ThumbnailColors.all(),
                Table("event_occurrence_rtree")
            ],
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.eventObjectOccurrences(filter: filter, db: db)
            },
            onChange: onChange,
            onError: onError
        )
    }

    func observeMutantVehicles(
        filter: MutantVehicleFilter,
        onChange: @escaping ([ListRow<MutantVehicleObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        var regions: [any DatabaseRegionConvertible] = [
            MutantVehicleObject.all(), listMetadataRegion, ThumbnailColors.all()
        ]
        if filter.tag != nil {
            regions.append(Table("mv_tags"))
        }
        return observeListRows(
            type: .mutantVehicle,
            ids: { $0.map(\.uid) },
            regions: regions,
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.mutantVehicleRequest(filter: filter).fetchAll(db)
            },
            onChange: onChange,
            onError: onError
        )
    }

    func observeEventsByHour(
        filter: EventFilter,
        onChange: @escaping ([EventHourSection]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observeEvents(filter: filter, onChange: { rows in
            onChange(Self.groupByHour(rows))
        }, onError: onError)
    }

    func observeEventsByDayThenHour(
        filter: EventFilter,
        onChange: @escaping ([Date: [EventHourSection]]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        // Tracked regions: event tables drive bucket membership/order; narrowed metadata is
        // needed so favorite toggles refresh the heart UI; ThumbnailColors so cached-color
        // writes refresh the row chrome. Camp/art tables are intentionally excluded — host
        // edits don't reshuffle the event list.
        observeListRows(
            type: .event,
            ids: { $0.map { $0.event.uid } },
            favoriteIdentity: { $0.favoriteIdentity },
            regions: [
                EventOccurrence.all(),
                EventObject.all(),
                listMetadataRegion,
                ThumbnailColors.all(),
                Table("event_occurrence_rtree")
            ],
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.eventObjectOccurrencesJoined(filter: filter, db: db)
            },
            onChange: { rows in
                onChange(Self.bucketByDayThenHour(rows))
            },
            onError: onError
        )
    }

    /// Groups rows by start-time hour-of-day in the device's current calendar.
    /// Sections are sorted ascending; rows within a section preserve input order
    /// (which is `orderedByStartTime` from `eventOccurrenceRequest`).
    static func groupByHour(_ rows: [ListRow<EventObjectOccurrence>]) -> [EventHourSection] {
        let calendar = Calendar.current
        return Dictionary(grouping: rows, by: { calendar.component(.hour, from: $0.object.startDate) })
            .sorted { $0.key < $1.key }
            .map { EventHourSection(hour: $0.key, rows: $0.value) }
    }

    /// Single-pass split of rows pre-sorted by start time into `[Date(startOfDay): [hour sections]]`.
    /// Day-tab UI then reads `bucket[selectedDay]` with no DB hit.
    ///
    /// Calendar boundaries are cached across consecutive rows: since input is sorted by
    /// start_time, most rows fall into the same hour as their predecessor, so we only
    /// call `Calendar.startOfDay`/`component` when the row crosses a boundary. Avoids
    /// ~16k Calendar method calls for a 8k-row dataset (devices show 50–100x latency
    /// without this — Calendar isn't free under thermal load).
    static func bucketByDayThenHour(_ rows: [ListRow<EventObjectOccurrence>]) -> [Date: [EventHourSection]] {
        let calendar = Calendar.current
        var result: [Date: [EventHourSection]] = [:]
        var currentDay: Date?
        var currentDayEnd: Date?       // exclusive upper bound (day + 1d) for cheap "same day?" check
        var currentHour: Int?
        var currentHourStart: Date?    // start instant of current hour
        var currentHourEnd: Date?      // start instant of next hour
        var currentRows: [ListRow<EventObjectOccurrence>] = []
        var currentDaySections: [EventHourSection] = []

        func flushHour() {
            guard let h = currentHour, !currentRows.isEmpty else { return }
            currentDaySections.append(EventHourSection(hour: h, rows: currentRows))
            currentRows = []
        }
        func flushDay() {
            flushHour()
            if let d = currentDay, !currentDaySections.isEmpty {
                result[d] = currentDaySections
            }
            currentDaySections = []
        }

        for row in rows {
            let start = row.object.startDate

            // Day boundary check via cached interval (no Calendar call if same day as previous row).
            if let dayEnd = currentDayEnd, start < dayEnd, let day = currentDay, start >= day {
                // Same day — fall through to hour check.
            } else {
                flushDay()
                let day = calendar.startOfDay(for: start)
                currentDay = day
                currentDayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
                currentHour = nil
                currentHourStart = nil
                currentHourEnd = nil
            }

            // Hour boundary check via cached interval (no Calendar call if same hour).
            if let hourEnd = currentHourEnd, start < hourEnd, let hourStart = currentHourStart, start >= hourStart {
                // Same hour — append below.
            } else {
                flushHour()
                let hour = calendar.component(.hour, from: start)
                currentHour = hour
                if let day = currentDay {
                    currentHourStart = calendar.date(byAdding: .hour, value: hour, to: day)
                    currentHourEnd = currentHourStart.flatMap {
                        calendar.date(byAdding: .hour, value: 1, to: $0)
                    }
                }
            }

            currentRows.append(row)
        }
        flushDay()
        return result
    }

    // MARK: - Thumbnail Colors

    func saveThumbnailColors(_ colors: ThumbnailColors) async throws {
        try await dbQueue.write { db in
            var colors = colors
            try colors.save(db, onConflict: .replace)
        }
    }

    func saveThumbnailColorsBatch(_ batch: [ThumbnailColors]) async throws {
        try await dbQueue.write { db in
            for var colors in batch {
                try colors.save(db, onConflict: .replace)
            }
        }
    }

    func fetchThumbnailColors(objectId: String) async throws -> ThumbnailColors? {
        try await dbQueue.read { db in
            try ThumbnailColors
                .filter(ThumbnailColors.Columns.objectId == objectId)
                .fetchOne(db)
        }
    }

    // MARK: - Distribution

    func compactForDistribution() async throws {
        try await dbQueue.writeWithoutTransaction { db in
            // VACUUM rebuilds the file (reclaiming import churn), then the truncating
            // checkpoint empties the WAL so PlayaDB.sqlite stands alone.
            try db.execute(sql: "VACUUM")
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }

    func fetchCachedColorObjectIDs() async throws -> Set<String> {
        try await dbQueue.read { db in
            let ids = try String.fetchAll(db, sql: "SELECT object_id FROM thumbnail_colors")
            return Set(ids)
        }
    }

    // MARK: - User Map Pins

    /// Upserts the pin, and — for the singleton types — retires whatever else was
    /// holding that type.
    ///
    /// Home and bike are one-per-device by design (see `UserMapPinType.singletonTypes`).
    /// Enforcing that here rather than in the UI is what makes a double tap on the map's
    /// bike button harmless: the second write supersedes the first instead of leaving two
    /// rows behind, no matter how the two taps interleave.
    func saveUserMapPin(_ pin: UserMapPin) async throws {
        try await dbQueue.write { db in
            var pin = pin
            try pin.save(db, onConflict: .replace)
            try Self.retireOtherSingletonPins(db, keeping: pin)
        }
    }

    /// Tombstones every *other* live row sharing `pin`'s type, when that type is a
    /// singleton. Soft-deleted rather than hard-deleted so the collapse survives sync:
    /// a row that simply vanished here would come straight back from the peer's snapshot.
    private static func retireOtherSingletonPins(_ db: Database, keeping pin: UserMapPin) throws {
        guard UserMapPinType(pinTypeString: pin.pinType).isSingleton, !pin.isDeleted else { return }
        let losers = try UserMapPin
            .filter(UserMapPin.Columns.pinType == pin.pinType)
            .filter(UserMapPin.Columns.isDeleted == false)
            .filter(UserMapPin.Columns.id != pin.id)
            .fetchAll(db)
        try tombstone(losers, in: db)
    }

    /// Marks each pin deleted with a stamp strictly newer than the one it replaces, so
    /// last-writer-wins on the peer resolves in the tombstone's favour.
    private static func tombstone(_ pins: some Sequence<UserMapPin>, in db: Database) throws {
        let now = Date()
        for pin in pins {
            var tombstoned = pin
            tombstoned.isDeleted = true
            tombstoned.modifiedDate = max(now, pin.modifiedDate.addingTimeInterval(1))
            try tombstoned.update(db)
        }
    }

    /// Folds pre-existing duplicate home/bike rows down to one live row per type.
    ///
    /// Placing a home or bike used to be "ask the database whether one exists, insert if
    /// not", with the insert unawaited — so two quick taps could both miss and both write.
    /// `saveUserMapPin` now upserts by type, but databases written by earlier builds still
    /// carry the duplicates, which show up as stacked pins on the map. Run at open, next
    /// to the other data-dependent folds. Idempotent, and it writes nothing at all in the
    /// overwhelmingly common case of at most one live row per type.
    static func collapseDuplicateSingletonPins(_ db: Database) throws {
        for type in UserMapPinType.singletonTypes {
            let live = try UserMapPin
                .filter(UserMapPin.Columns.pinType == type.rawValue)
                .filter(UserMapPin.Columns.isDeleted == false)
                .fetchAll(db)
            guard live.count > 1 else { continue }
            // Newest edit wins, with creation date and id as tie-breakers so two devices
            // folding the same rows independently keep the same survivor.
            let ordered = live.sorted { lhs, rhs in
                if lhs.modifiedDate != rhs.modifiedDate { return lhs.modifiedDate < rhs.modifiedDate }
                if lhs.createdDate != rhs.createdDate { return lhs.createdDate < rhs.createdDate }
                return lhs.id < rhs.id
            }
            try tombstone(ordered.dropLast(), in: db)
        }
    }

    /// Soft delete: the row becomes a tombstone so the deletion can win a
    /// last-writer-wins merge on the peer device. Every read path below filters
    /// tombstones out, so callers see a normal delete.
    func deleteUserMapPin(id: String) async throws {
        _ = try await dbQueue.write { db in
            try db.execute(
                sql: "UPDATE user_map_pins SET is_deleted = 1, modified_date = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    func fetchUserMapPins() async throws -> [UserMapPin] {
        try await dbQueue.read { db in
            try Self.liveUserMapPins(db)
        }
    }

    func observeUserMapPins(onChange: @escaping ([UserMapPin]) -> Void) -> PlayaDBObservationToken {
        let observation = ValueObservation.tracking { db in
            try Self.liveUserMapPins(db)
        }.removeDuplicates()
        let cancellable = observation.start(
            in: dbQueue,
            onError: { error in
                print("UserMapPin observation error: \(error)")
            },
            onChange: { pins in
                DispatchQueue.main.async {
                    onChange(pins)
                }
            }
        )
        return PlayaDBObservationToken(cancellable)
    }

    // MARK: - Calendar Entries

    func saveCalendarEntry(_ entry: EventCalendarEntry) async throws {
        try await dbQueue.write { db in
            var entry = entry
            try entry.save(db, onConflict: .replace)
        }
    }

    func fetchCalendarEntries(eventId: String) async throws -> [EventCalendarEntry] {
        try await dbQueue.read { db in
            try EventCalendarEntry
                .filter(EventCalendarEntry.Columns.eventId == eventId)
                .order(EventCalendarEntry.Columns.occurrenceKey)
                .fetchAll(db)
        }
    }

    func deleteCalendarEntries(eventId: String) async throws {
        _ = try await dbQueue.write { db in
            try EventCalendarEntry
                .filter(EventCalendarEntry.Columns.eventId == eventId)
                .deleteAll(db)
        }
    }

    func deleteCalendarEntry(eventId: String, occurrenceKey: String) async throws {
        _ = try await dbQueue.write { db in
            try EventCalendarEntry
                .filter(EventCalendarEntry.Columns.eventId == eventId)
                .filter(EventCalendarEntry.Columns.occurrenceKey == occurrenceKey)
                .deleteAll(db)
        }
    }

    func fetchAllCalendarEntries() async throws -> [EventCalendarEntry] {
        try await dbQueue.read { db in
            try EventCalendarEntry
                .order(EventCalendarEntry.Columns.eventId, EventCalendarEntry.Columns.occurrenceKey)
                .fetchAll(db)
        }
    }

    // MARK: - User Map Pin Sync

    func userMapPinSyncSnapshot() async throws -> [UserMapPin] {
        try await dbQueue.read { db in
            try Self.userMapPinSyncItems(db)
        }
    }

    @discardableResult
    func applyUserMapPinSync(_ pins: [UserMapPin]) async throws -> [UserMapPin] {
        try await dbQueue.write { db in
            var applied: [UserMapPin] = []
            for incoming in pins {
                guard !incoming.id.isEmpty else { continue }
                let existing = try UserMapPin.fetchOne(db, key: incoming.id)

                guard var merged = existing else {
                    // A tombstone for a pin this device never had says nothing
                    // worth storing — skip it so the table only ever holds pins
                    // we actually saw.
                    guard !incoming.isDeleted else { continue }
                    var newPin = incoming
                    try newPin.insert(db)
                    applied.append(newPin)
                    continue
                }

                // Last-writer-wins on the whole row: title, coordinate, type and
                // the tombstone flag all move together, so a strictly newer
                // stamp is the only thing that can overwrite local state.
                guard incoming.modifiedDate > merged.modifiedDate else { continue }
                merged.title = incoming.title
                merged.latitude = incoming.latitude
                merged.longitude = incoming.longitude
                merged.pinType = incoming.pinType
                merged.isDeleted = incoming.isDeleted
                merged.modifiedDate = incoming.modifiedDate
                // Creation is a fact about the pin, not a field to race over.
                merged.createdDate = min(merged.createdDate, incoming.createdDate)

                // Never write when nothing changed: applying a peer's snapshot
                // must not re-fire the local observation, or the two devices
                // ping-pong pushes forever.
                guard merged != existing else { continue }
                try merged.update(db)
                applied.append(merged)
            }
            return applied
        }
    }

    @discardableResult
    func observeUserMapPinSyncState(
        onChange: @escaping ([UserMapPin]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        let observation = ValueObservation.tracking { db in
            try Self.userMapPinSyncItems(db)
        }.removeDuplicates()
        let cancellable = observation.start(
            in: dbQueue,
            onError: onError,
            onChange: { pins in
                DispatchQueue.main.async {
                    onChange(pins)
                }
            }
        )
        return PlayaDBObservationToken(cancellable)
    }

    /// Pins visible to the app: tombstones excluded.
    private static func liveUserMapPins(_ db: Database) throws -> [UserMapPin] {
        try UserMapPin
            .filter(UserMapPin.Columns.isDeleted == false)
            .order(UserMapPin.Columns.createdDate)
            .fetchAll(db)
    }

    /// Everything a peer needs to converge, tombstones included.
    private static func userMapPinSyncItems(_ db: Database) throws -> [UserMapPin] {
        try UserMapPin.order(UserMapPin.Columns.id).fetchAll(db)
    }

    func observeUpdateInfo(onChange: @escaping ([UpdateInfo]) -> Void, onError: @escaping (Error) -> Void) -> PlayaDBObservationToken {
        let observation = ValueObservation.tracking { db in
            try UpdateInfo.fetchAll(db)
        }.removeDuplicates()
        let cancellable = observation.start(
            in: dbQueue,
            onError: onError,
            onChange: { infos in
                DispatchQueue.main.async {
                    onChange(infos)
                }
            }
        )
        return PlayaDBObservationToken(cancellable)
    }

    // MARK: - Favorite Sync

    /// Shared query for snapshot + observation: every row whose favorite or
    /// visit status has ever been explicitly set (non-nil stamp on either
    /// field), deterministically ordered.
    private static func favoriteSyncItems(_ db: Database) throws -> [FavoriteSyncItem] {
        let rows = try ObjectMetadata
            .filter(ObjectMetadata.Columns.favoriteUpdatedAt != nil
                    || ObjectMetadata.Columns.visitStatusUpdatedAt != nil)
            .order(ObjectMetadata.Columns.objectType, ObjectMetadata.Columns.objectId)
            .fetchAll(db)
        return rows.map { metadata in
            FavoriteSyncItem(
                objectType: metadata.objectType,
                objectId: metadata.objectId,
                isFavorite: metadata.isFavorite,
                favoriteUpdatedAt: metadata.favoriteUpdatedAt,
                visitStatus: metadata.visitStatus,
                visitStatusUpdatedAt: metadata.visitStatusUpdatedAt
            )
        }
    }

    func favoriteSyncSnapshot() async throws -> [FavoriteSyncItem] {
        try await dbQueue.read { db in
            try Self.favoriteSyncItems(db)
        }
    }

    @discardableResult
    func applyFavoriteSync(_ items: [FavoriteSyncItem]) async throws -> [FavoriteSyncItem] {
        try await dbQueue.write { db in
            var applied: [FavoriteSyncItem] = []
            for item in items {
                guard DataObjectType(rawValue: item.objectType) != nil else { continue }

                let existingMetadata = try ObjectMetadata
                    .filter(ObjectMetadata.Columns.objectType == item.objectType)
                    .filter(ObjectMetadata.Columns.objectId == item.objectId)
                    .fetchOne(db)

                // A visit field is only meaningful when it carries a stamp and a
                // raw value we recognize.
                let incomingVisitValid = item.visitStatusUpdatedAt != nil
                    && VisitStatus(rawValue: item.visitStatus) != nil

                if var metadata = existingMetadata {
                    // Per-field last-writer-wins: favorite and visit status merge
                    // independently, each on its own dedicated stamp.
                    var changedColumns: [ObjectMetadata.Columns] = []

                    if let incomingStamp = item.favoriteUpdatedAt,
                       metadata.isFavorite != item.isFavorite,
                       metadata.favoriteUpdatedAt.map({ incomingStamp > $0 }) ?? true {
                        metadata.isFavorite = item.isFavorite
                        metadata.favoriteUpdatedAt = incomingStamp
                        changedColumns += [.isFavorite, .favoriteUpdatedAt]
                    }

                    if incomingVisitValid,
                       let incomingStamp = item.visitStatusUpdatedAt,
                       metadata.visitStatus != item.visitStatus,
                       metadata.visitStatusUpdatedAt.map({ incomingStamp > $0 }) ?? true {
                        metadata.visitStatus = item.visitStatus
                        metadata.visitStatusUpdatedAt = incomingStamp
                        changedColumns += [.visitStatus, .visitStatusUpdatedAt]
                    }

                    // Nothing applied: never write, so applying a peer's snapshot
                    // doesn't re-fire observations (and cause push loops).
                    guard !changedColumns.isEmpty else { continue }
                    metadata.updatedAt = Date()
                    changedColumns.append(.updatedAt)
                    try metadata.update(db, columns: changedColumns)
                    applied.append(item)
                } else {
                    // No local row: only materialize when the incoming item has
                    // something non-default to say. Stamps are set only for the
                    // fields the item actually carries.
                    let hasFavoriteField = item.favoriteUpdatedAt != nil
                    let insertWorthy = (hasFavoriteField && item.isFavorite)
                        || (incomingVisitValid && item.visitStatus != VisitStatus.unvisited.rawValue)
                    guard insertWorthy else { continue }
                    var newMetadata = ObjectMetadata(
                        objectType: item.objectType,
                        objectId: item.objectId,
                        isFavorite: hasFavoriteField ? item.isFavorite : false,
                        favoriteUpdatedAt: hasFavoriteField ? item.favoriteUpdatedAt : nil,
                        visitStatus: incomingVisitValid ? item.visitStatus : 0,
                        visitStatusUpdatedAt: incomingVisitValid ? item.visitStatusUpdatedAt : nil
                    )
                    try newMetadata.insert(db)
                    applied.append(item)
                }
            }
            return applied
        }
    }

    @discardableResult
    func observeFavoriteSyncState(onChange: @escaping ([FavoriteSyncItem]) -> Void, onError: @escaping (Error) -> Void) -> PlayaDBObservationToken {
        let observation = ValueObservation.tracking { db in
            try Self.favoriteSyncItems(db)
        }.removeDuplicates()
        let cancellable = observation.start(
            in: dbQueue,
            onError: onError,
            onChange: { items in
                DispatchQueue.main.async {
                    onChange(items)
                }
            }
        )
        return PlayaDBObservationToken(cancellable)
    }

    // MARK: - Metadata Helpers

    /// Metadata identity for an object's *non-favorite* fields (notes, visit status,
    /// view history). Event occurrences share their parent event's row here: "I visited
    /// this" and "my note about this" are statements about the event, not about one
    /// morning of it. (`EventObjectOccurrence.uid` is a synthesized
    /// "<eventUID>_<occurrenceID>" that never matches the event_objects table, and whose
    /// numeric half is reissued by every import — it is never a storage key.)
    ///
    /// Favorites are the exception and are keyed per occurrence — see
    /// ``favoriteTarget(for:)`` and ``EventFavoriteKey``.
    private func metadataIdentity(for object: any DataObject) -> (type: DataObjectType, uid: String) {
        if let occurrence = object as? EventObjectOccurrence {
            return (.event, occurrence.event.uid)
        }
        return (object.objectType, object.uid)
    }

    /// What a favorite write or read is actually about.
    private enum FavoriteTarget {
        /// One `object_metadata` row: any non-event object, or one event occurrence
        /// (whose objectID is the ``EventFavoriteKey`` composite).
        case single(type: DataObjectType, objectID: String)
        /// Every occurrence of one event. A bare `EventObject` has no occurrence to
        /// point at, so its heart means the whole series (Detail opened on an event
        /// rather than on a specific showing).
        case eventSeries(eventUID: String)
    }

    /// Where an object's favorite bit lives. Event occurrences get their own row so
    /// favoriting Tuesday's yoga leaves Wednesday's alone.
    private func favoriteTarget(for object: any DataObject) -> FavoriteTarget {
        if let occurrence = object as? EventObjectOccurrence {
            return .single(type: .event, objectID: occurrence.favoriteIdentity)
        }
        if let event = object as? EventObject {
            return .eventSeries(eventUID: event.uid)
        }
        return .single(type: object.objectType, objectID: object.uid)
    }

    /// Resolves an occurrence's favorite state, honoring the legacy parent-uid row.
    /// See ``EventFavoriteKey`` for the precedence rule.
    private static func isFavoriteOccurrence(identity: String, db: Database) throws -> Bool {
        if let own = try Bool.fetchOne(db, sql: """
            SELECT is_favorite FROM object_metadata WHERE object_type = ? AND object_id = ?
            """, arguments: [DataObjectType.event.rawValue, identity]) {
            return own
        }
        let parentUID = EventFavoriteKey.eventUID(from: identity)
        return try Bool.fetchOne(db, sql: """
            SELECT is_favorite FROM object_metadata WHERE object_type = ? AND object_id = ?
            """, arguments: [DataObjectType.event.rawValue, parentUID]) ?? false
    }

    /// Every occurrence identity of one event, oldest first.
    private static func occurrenceIdentities(eventUID: String, db: Database) throws -> [String] {
        let startDates = try Date.fetchAll(db, sql: """
            SELECT start_time FROM event_occurrences WHERE event_id = ? ORDER BY start_time
            """, arguments: [eventUID])
        return startDates.map { EventFavoriteKey.objectID(eventUID: eventUID, startDate: $0) }
    }

    /// Merges legacy occurrence-keyed event metadata rows ("<eventUID>_<occID>") into
    /// their parent event's row. Earlier versions wrote favorites through
    /// EventObjectOccurrence.uid, producing rows invisible to the JOIN-based favorite
    /// filter and to ListRow metadata inflation (both keyed by the event uid).
    private func migrateOccurrenceKeyedMetadata(_ db: Database) throws {
        let candidates = try ObjectMetadata
            .filter(ObjectMetadata.Columns.objectType == DataObjectType.event.rawValue)
            .filter(sql: "instr(object_id, '_') > 0")
            .fetchAll(db)
        guard !candidates.isEmpty else { return }

        for synthetic in candidates {
            guard let separator = synthetic.objectId.lastIndex(of: "_") else { continue }
            let parentUID = String(synthetic.objectId[..<separator])
            let suffix = synthetic.objectId[synthetic.objectId.index(after: separator)...]
            guard !parentUID.isEmpty, Int64(suffix) != nil else { continue }
            guard try EventObject.filter(Column("uid") == parentUID).fetchCount(db) > 0 else { continue }

            if var parent = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == DataObjectType.event.rawValue)
                .filter(ObjectMetadata.Columns.objectId == parentUID)
                .fetchOne(db) {
                parent.isFavorite = parent.isFavorite || synthetic.isFavorite
                parent.firstViewed = [parent.firstViewed, synthetic.firstViewed].compactMap { $0 }.min()
                parent.lastViewed = [parent.lastViewed, synthetic.lastViewed].compactMap { $0 }.max()
                parent.userNotes = parent.userNotes ?? synthetic.userNotes
                parent.updatedAt = Date()
                try parent.update(db)
            } else {
                var moved = synthetic
                moved.objectId = parentUID
                moved.updatedAt = Date()
                try moved.insert(db)
            }

            try db.execute(sql: """
                DELETE FROM object_metadata WHERE object_type = ? AND object_id = ?
                """, arguments: [DataObjectType.event.rawValue, synthetic.objectId])
        }
    }

    /// Promotes legacy series favorites (a favorited row keyed by the bare event uid)
    /// into explicit per-occurrence rows.
    ///
    /// Before per-occurrence favorites, favoriting any showing of a recurring event wrote
    /// one row under the parent uid, which meant *every* occurrence read as favorited.
    /// That intent is preserved literally: each occurrence of the event gets its own row
    /// carrying the parent's `is_favorite` and `favorite_updated_at`.
    ///
    /// Notes:
    /// - **The parent row is left favorited.** It stays the fallback for occurrences that
    ///   have no row of their own — including ones a later data refresh adds, and ones a
    ///   peer running an older build knows about. Clearing it would also push an
    ///   "unfavorited" edit at those peers through `favoriteSyncItems`.
    /// - **Explicit occurrence rows are never overwritten**, so a user who has already
    ///   unfavorited one showing keeps that decision.
    /// - **Data-dependent and idempotent.** Events with no occurrences yet (the fold can
    ///   run before the first import or seed restore) are skipped and picked up on a later
    ///   open; occurrences that already have a row are skipped every time after the first.
    private func foldLegacyEventFavorites(_ db: Database) throws {
        let parentRows = try ObjectMetadata
            .filter(ObjectMetadata.Columns.objectType == DataObjectType.event.rawValue)
            .filter(ObjectMetadata.Columns.isFavorite == true)
            .fetchAll(db)
            .filter { !EventFavoriteKey.isComposite($0.objectId) }
        guard !parentRows.isEmpty else { return }

        for parent in parentRows {
            let identities = try Self.occurrenceIdentities(eventUID: parent.objectId, db: db)
            guard !identities.isEmpty else { continue }

            let existing = try ObjectMetadata
                .select(ObjectMetadata.Columns.objectId, as: String.self)
                .filter(ObjectMetadata.Columns.objectType == DataObjectType.event.rawValue)
                .filter(identities.contains(ObjectMetadata.Columns.objectId))
                .fetchSet(db)

            for identity in identities where !existing.contains(identity) {
                var row = ObjectMetadata(
                    objectType: DataObjectType.event.rawValue,
                    objectId: identity,
                    isFavorite: true,
                    favoriteUpdatedAt: parent.favoriteUpdatedAt ?? parent.updatedAt
                )
                try row.insert(db)
            }
        }
    }

    private func ensureMetadata(for type: DataObjectType, ids: [String]) async throws {
        try await ensureMetadata(for: [(type, ids)])
    }

    private func ensureMetadata(for items: [(DataObjectType, [String])]) async throws {
        let nonEmpty = items.filter { !$0.1.isEmpty }
        guard !nonEmpty.isEmpty else { return }

        try await dbQueue.write { db in
            let now = Date()
            for (type, ids) in nonEmpty {
                let uniqueIds = Set(ids)
                let existingIds = try Set(
                    String.fetchAll(
                        db,
                        ObjectMetadata
                            .select(ObjectMetadata.Columns.objectId)
                            .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                            .filter(uniqueIds.contains(ObjectMetadata.Columns.objectId))
                    )
                )

                for id in uniqueIds.subtracting(existingIds) {
                    var metadata = ObjectMetadata(
                        objectType: type.rawValue,
                        objectId: id,
                        createdAt: now,
                        updatedAt: now
                    )
                    try metadata.insert(db)
                }
            }
        }
    }

    // MARK: - Event Occurrence Batch Helpers

    /// Fetch occurrences for a set of events, batch-resolving host camp/art in the same transaction.
    private func eventObjectOccurrences(for events: [EventObject], db: Database) throws -> [EventObjectOccurrence] {
        guard !events.isEmpty else { return [] }
        let eventsByUID = Dictionary(uniqueKeysWithValues: events.map { ($0.uid, $0) })
        let occurrences = try EventOccurrence
            .filter(eventsByUID.keys.contains(Column("event_id")))
            .fetchAll(db)

        let hosts = try batchResolveHosts(for: events, db: db)

        return occurrences.compactMap { occ in
            guard let event = eventsByUID[occ.eventId] else { return nil }
            return EventObjectOccurrence(event: event, occurrence: occ, host: hosts[event.uid])
        }
    }

    /// Fetch parent events + host data for a set of occurrences via batch queries.
    private func eventObjectOccurrences(for occurrences: [EventOccurrence], db: Database) throws -> [EventObjectOccurrence] {
        guard !occurrences.isEmpty else { return [] }
        let eventIDs = Set(occurrences.map(\.eventId))
        let events = try EventObject
            .filter(eventIDs.contains(Column("uid")))
            .fetchAll(db)
        let eventsByUID = Dictionary(uniqueKeysWithValues: events.map { ($0.uid, $0) })

        let hosts = try batchResolveHosts(for: events, db: db)

        return occurrences.compactMap { occ in
            guard let event = eventsByUID[occ.eventId] else { return nil }
            return EventObjectOccurrence(event: event, occurrence: occ, host: hosts[event.uid])
        }
    }

    /// Batch-fetch host camp/art objects for a set of events (2 queries max).
    /// Returns a dictionary mapping event UID → PlaceDataObject.
    private func batchResolveHosts(for events: [EventObject], db: Database) throws -> [String: any PlaceDataObject] {
        let campUIDs = Set(events.compactMap(\.hostedByCamp))
        let artUIDs = Set(events.compactMap(\.locatedAtArt))

        var campsByUID: [String: CampObject] = [:]
        if !campUIDs.isEmpty {
            let camps = try CampObject
                .filter(campUIDs.contains(Column("uid")))
                .fetchAll(db)
            campsByUID = Dictionary(uniqueKeysWithValues: camps.map { ($0.uid, $0) })
        }

        var artsByUID: [String: ArtObject] = [:]
        if !artUIDs.isEmpty {
            let arts = try ArtObject
                .filter(artUIDs.contains(Column("uid")))
                .fetchAll(db)
            artsByUID = Dictionary(uniqueKeysWithValues: arts.map { ($0.uid, $0) })
        }

        var hosts: [String: any PlaceDataObject] = [:]
        for event in events {
            if let campUID = event.hostedByCamp, let camp = campsByUID[campUID] {
                hosts[event.uid] = camp
            } else if let artUID = event.locatedAtArt, let art = artsByUID[artUID] {
                hosts[event.uid] = art
            }
        }
        return hosts
    }

    func metadata(for object: any DataObject) async throws -> ObjectMetadata {
        let identity = metadataIdentity(for: object)
        let favorite = favoriteTarget(for: object)
        try await ensureMetadata(for: identity.type, ids: [identity.uid])

        return try await dbQueue.read { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == identity.type.rawValue)
                .filter(ObjectMetadata.Columns.objectId == identity.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }
            // Notes/visits/views come from the row above; the favorite bit may live on a
            // different (occurrence-keyed) row. Overlay it so callers see one coherent
            // record — the merge belongs here, not in every screen.
            switch favorite {
            case let .single(_, objectID) where objectID != identity.uid:
                metadata.isFavorite = try Self.isFavoriteOccurrence(identity: objectID, db: db)
            case let .eventSeries(eventUID):
                let identities = try Self.occurrenceIdentities(eventUID: eventUID, db: db)
                metadata.isFavorite = try Self.isFavoriteSeries(
                    eventUID: eventUID, identities: identities, db: db)
            case .single:
                break
            }
            return metadata
        }
    }

    /// Whether *any* showing of an event is favorited — what a bare `EventObject`'s heart
    /// answers. Falls back to the parent row for events with no occurrences on file.
    private static func isFavoriteSeries(
        eventUID: String,
        identities: [String],
        db: Database
    ) throws -> Bool {
        guard !identities.isEmpty else {
            return try Bool.fetchOne(db, sql: """
                SELECT is_favorite FROM object_metadata WHERE object_type = ? AND object_id = ?
                """, arguments: [DataObjectType.event.rawValue, eventUID]) ?? false
        }
        for identity in identities {
            if try isFavoriteOccurrence(identity: identity, db: db) { return true }
        }
        return false
    }

    /// Writes one favorite row, creating it when needed. Returns whether anything changed.
    @discardableResult
    private static func writeFavorite(
        _ isFavorite: Bool,
        type: DataObjectType,
        objectID: String,
        currentValue: Bool,
        db: Database
    ) throws -> Bool {
        let existing = try ObjectMetadata
            .filter(ObjectMetadata.Columns.objectType == type.rawValue)
            .filter(ObjectMetadata.Columns.objectId == objectID)
            .fetchOne(db)

        if var metadata = existing {
            guard metadata.isFavorite != isFavorite else { return false }
            metadata.isFavorite = isFavorite
            metadata.favoriteUpdatedAt = Date()
            metadata.updatedAt = Date()
            try metadata.update(db, columns: [
                ObjectMetadata.Columns.isFavorite,
                ObjectMetadata.Columns.favoriteUpdatedAt,
                ObjectMetadata.Columns.updatedAt,
            ])
            return true
        }

        // No row of our own. `currentValue` may still be true — an occurrence inheriting a
        // legacy parent favorite — in which case a `false` row has to be materialized to
        // out-vote the parent (see `EventFavoriteKey`). Only a no-op `false` is skipped.
        guard isFavorite || currentValue else { return false }
        var newMetadata = ObjectMetadata(
            objectType: type.rawValue,
            objectId: objectID,
            isFavorite: isFavorite,
            favoriteUpdatedAt: Date()
        )
        try newMetadata.insert(db)
        return true
    }

    /// Sets every occurrence of an event to `isFavorite`, plus the parent row so the
    /// series answer survives a later data refresh adding occurrences.
    /// Returns the number of rows actually changed.
    @discardableResult
    private static func writeSeriesFavorite(
        _ isFavorite: Bool,
        eventUID: String,
        db: Database
    ) throws -> Int {
        var changed = 0
        for identity in try occurrenceIdentities(eventUID: eventUID, db: db) {
            let current = try isFavoriteOccurrence(identity: identity, db: db)
            if try writeFavorite(isFavorite, type: .event, objectID: identity,
                                 currentValue: current, db: db) {
                changed += 1
            }
        }
        let parentCurrent = try Bool.fetchOne(db, sql: """
            SELECT is_favorite FROM object_metadata WHERE object_type = ? AND object_id = ?
            """, arguments: [DataObjectType.event.rawValue, eventUID]) ?? false
        if try writeFavorite(isFavorite, type: .event, objectID: eventUID,
                             currentValue: parentCurrent, db: db) {
            changed += 1
        }
        return changed
    }

    // MARK: - Metadata Operations
    
    func getFavorites() async throws -> [any DataObject] {
        return try await dbQueue.read { db in
            let favoriteMetadata = try ObjectMetadata
                .filter(Column("is_favorite") == true)
                .fetchAll(db)

            // Group by type for batch fetching
            var artIDs: [String] = [], campIDs: [String] = []
            var eventIDs: [String] = [], mvIDs: [String] = []
            for meta in favoriteMetadata {
                switch meta.dataObjectType {
                case .art: artIDs.append(meta.objectId)
                case .camp: campIDs.append(meta.objectId)
                // Favorites for events are per occurrence, but this API answers in whole
                // `EventObject`s — collapse composite ids back to the parent uid so an
                // event with any favorited showing appears exactly once. Callers that
                // need the showings use `fetchFavoriteEvents`.
                case .event: eventIDs.append(EventFavoriteKey.eventUID(from: meta.objectId))
                case .mutantVehicle: mvIDs.append(meta.objectId)
                case .none: break
                }
            }

            var objects: [any DataObject] = []
            if !artIDs.isEmpty {
                objects += try ArtObject.filter(artIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !campIDs.isEmpty {
                objects += try CampObject.filter(campIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !eventIDs.isEmpty {
                objects += try EventObject.filter(eventIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !mvIDs.isEmpty {
                objects += try MutantVehicleObject.filter(mvIDs.contains(Column("uid"))).fetchAll(db)
            }
            return objects
        }
    }
    
    func toggleFavorite(_ object: any DataObject) async throws {
        let target = favoriteTarget(for: object)
        let postedType: DataObjectType
        switch target {
        case let .single(type, _): postedType = type
        case .eventSeries: postedType = .event
        }
        let result = try await dbQueue.write { db -> (uid: String, isFavorite: Bool) in
            switch target {
            case let .single(type, objectID):
                // Current state, not "the row we happen to have": an occurrence with no
                // row of its own can still read favorited through the legacy parent row,
                // and tapping its heart has to turn that *off*.
                let current = type == .event
                    ? try Self.isFavoriteOccurrence(identity: objectID, db: db)
                    : try ObjectMetadata
                        .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                        .filter(ObjectMetadata.Columns.objectId == objectID)
                        .fetchOne(db)?.isFavorite ?? false
                try Self.writeFavorite(!current, type: type, objectID: objectID,
                                       currentValue: current, db: db)
                return (objectID, !current)
            case let .eventSeries(eventUID):
                let identities = try Self.occurrenceIdentities(eventUID: eventUID, db: db)
                let current = try Self.isFavoriteSeries(
                    eventUID: eventUID, identities: identities, db: db)
                try Self.writeSeriesFavorite(!current, eventUID: eventUID, db: db)
                return (eventUID, !current)
            }
        }
        // Every screen that toggles a heart funnels through here, which is what makes this
        // the one place a "someone just favorited this" signal can be posted once. See
        // `FavoriteChangeNotification.swift`. For event occurrences the uid is the
        // ``EventFavoriteKey`` composite, which is what lets an observer tell "one showing"
        // from "the whole series" (see `FavoriteSeriesToastCoordinator` in the app).
        PlayaDBFavoriteChange.post(
            objectType: postedType.rawValue,
            uid: result.uid,
            isFavorite: result.isFavorite
        )
    }

    func setFavorite(_ isFavorite: Bool, for object: any DataObject) async throws {
        let target = favoriteTarget(for: object)
        try await dbQueue.write { db in
            switch target {
            case let .single(type, objectID):
                let current = type == .event
                    ? try Self.isFavoriteOccurrence(identity: objectID, db: db)
                    : try ObjectMetadata
                        .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                        .filter(ObjectMetadata.Columns.objectId == objectID)
                        .fetchOne(db)?.isFavorite ?? false
                try Self.writeFavorite(isFavorite, type: type, objectID: objectID,
                                       currentValue: current, db: db)
            case let .eventSeries(eventUID):
                try Self.writeSeriesFavorite(isFavorite, eventUID: eventUID, db: db)
            }
        }
    }

    func setFavorite(_ isFavorite: Bool, forEventSeries eventUID: String) async throws -> Int {
        try await dbQueue.write { db in
            try Self.writeSeriesFavorite(isFavorite, eventUID: eventUID, db: db)
        }
    }

    func favoriteOccurrences(forEventUID uid: String) async throws -> [EventObjectOccurrence] {
        try await dbQueue.read { db in
            let index = try EventFavoriteIndex.load(db)
            let occurrences = try EventOccurrence
                .filter(EventOccurrence.Columns.eventId == uid)
                .order(EventOccurrence.Columns.startTime)
                .fetchAll(db)
            let inflated = try self.eventObjectOccurrences(for: occurrences, db: db)
            return inflated.filter { index.isFavorite($0) }
        }
    }

    func favoriteIdentifiers(among objects: [any DataObject]) async throws -> Set<String> {
        guard !objects.isEmpty else { return [] }

        // Non-event objects answer to their own uid; event occurrences answer to their
        // ``EventFavoriteKey`` composite, so two showings of one event are asked about
        // separately (which is the whole point).
        var mutableIDsByType: [DataObjectType: Set<String>] = [:]
        var occurrenceIdentities: Set<String> = []
        var seriesUIDs: Set<String> = []
        for object in objects {
            switch favoriteTarget(for: object) {
            case let .single(type, objectID) where type == .event:
                occurrenceIdentities.insert(objectID)
            case let .single(type, objectID):
                mutableIDsByType[type, default: []].insert(objectID)
            case let .eventSeries(eventUID):
                seriesUIDs.insert(eventUID)
            }
        }
        let idsByType = mutableIDsByType
        let occurrences = occurrenceIdentities
        let series = seriesUIDs

        return try await dbQueue.read { db in
            var favorites: Set<String> = []
            for (type, ids) in idsByType {
                let favorited = try ObjectMetadata
                    .select(ObjectMetadata.Columns.objectId, as: String.self)
                    .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                    .filter(ObjectMetadata.Columns.isFavorite == true)
                    .filter(ids.contains(ObjectMetadata.Columns.objectId))
                    .fetchAll(db)
                favorites.formUnion(favorited)
            }
            if !occurrences.isEmpty || !series.isEmpty {
                let index = try EventFavoriteIndex.load(db)
                for identity in occurrences where index.isFavorite(identity: identity) {
                    favorites.insert(identity)
                }
                for eventUID in series {
                    let identities = try Self.occurrenceIdentities(eventUID: eventUID, db: db)
                    if index.isAnyFavorite(eventUID: eventUID, occurrenceIdentities: identities) {
                        favorites.insert(eventUID)
                    }
                }
            }
            return favorites
        }
    }

    func setVisitStatus(_ status: VisitStatus, for object: any DataObject) async throws {
        let identity = metadataIdentity(for: object)
        try await dbQueue.write { db in
            let objectType = identity.type.rawValue
            let objectId = identity.uid

            let existingMetadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == objectType)
                .filter(ObjectMetadata.Columns.objectId == objectId)
                .fetchOne(db)

            if var metadata = existingMetadata {
                guard metadata.visitStatus != status.rawValue else { return }
                metadata.visitStatus = status.rawValue
                metadata.visitStatusUpdatedAt = Date()
                metadata.updatedAt = Date()
                try metadata.update(db, columns: [
                    ObjectMetadata.Columns.visitStatus,
                    ObjectMetadata.Columns.visitStatusUpdatedAt,
                    ObjectMetadata.Columns.updatedAt,
                ])
            } else {
                // Unvisited is the default state: don't create junk rows for it.
                guard status != .unvisited else { return }
                var newMetadata = ObjectMetadata(
                    objectType: objectType,
                    objectId: objectId,
                    visitStatus: status.rawValue,
                    visitStatusUpdatedAt: Date()
                )
                try newMetadata.insert(db)
            }
        }
    }

    func fetchObjects(visitStatus status: VisitStatus) async throws -> [any DataObject] {
        return try await dbQueue.read { db in
            let matchingMetadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.visitStatus == status.rawValue)
                .fetchAll(db)

            // Group by type for batch fetching
            var artIDs: [String] = [], campIDs: [String] = []
            var eventIDs: [String] = [], mvIDs: [String] = []
            for meta in matchingMetadata {
                switch meta.dataObjectType {
                case .art: artIDs.append(meta.objectId)
                case .camp: campIDs.append(meta.objectId)
                case .event: eventIDs.append(meta.objectId)
                case .mutantVehicle: mvIDs.append(meta.objectId)
                case .none: break
                }
            }

            var objects: [any DataObject] = []
            if !artIDs.isEmpty {
                objects += try ArtObject.filter(artIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !campIDs.isEmpty {
                objects += try CampObject.filter(campIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !eventIDs.isEmpty {
                objects += try EventObject.filter(eventIDs.contains(Column("uid"))).fetchAll(db)
            }
            if !mvIDs.isEmpty {
                objects += try MutantVehicleObject.filter(mvIDs.contains(Column("uid"))).fetchAll(db)
            }
            return objects
        }
    }

    func isFavorite(_ object: any DataObject) async throws -> Bool {
        let target = favoriteTarget(for: object)
        return try await dbQueue.read { db in
            switch target {
            case let .single(type, objectID) where type == .event:
                return try Self.isFavoriteOccurrence(identity: objectID, db: db)
            case let .single(type, objectID):
                return try ObjectMetadata
                    .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                    .filter(ObjectMetadata.Columns.objectId == objectID)
                    .fetchOne(db)?.isFavorite ?? false
            case let .eventSeries(eventUID):
                let identities = try Self.occurrenceIdentities(eventUID: eventUID, db: db)
                return try Self.isFavoriteSeries(
                    eventUID: eventUID, identities: identities, db: db)
            }
        }
    }

    func setUserNotes(_ notes: String?, for object: any DataObject) async throws {
        let identity = metadataIdentity(for: object)
        try await ensureMetadata(for: identity.type, ids: [identity.uid])

        try await dbQueue.write { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == identity.type.rawValue)
                .filter(ObjectMetadata.Columns.objectId == identity.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }

            let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata.userNotes = (trimmed?.isEmpty == true) ? nil : trimmed
            metadata.updatedAt = Date()
            try metadata.update(db, columns: [
                ObjectMetadata.Columns.userNotes,
                ObjectMetadata.Columns.updatedAt,
            ])
        }
    }

    func setLastViewed(_ date: Date, for object: any DataObject) async throws {
        let identity = metadataIdentity(for: object)
        try await ensureMetadata(for: identity.type, ids: [identity.uid])

        try await dbQueue.write { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == identity.type.rawValue)
                .filter(ObjectMetadata.Columns.objectId == identity.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }

            if metadata.firstViewed == nil {
                metadata.firstViewed = date
            }
            metadata.lastViewed = date
            metadata.updatedAt = Date()
            // Column-limited update: a full-row UPDATE would touch is_favorite and
            // re-fire every list observation (their regions include that column).
            try metadata.update(db, columns: [
                ObjectMetadata.Columns.firstViewed,
                ObjectMetadata.Columns.lastViewed,
                ObjectMetadata.Columns.updatedAt,
            ])
        }
    }
    
    // MARK: - Recently Viewed & Favorite Events

    func fetchRecentlyViewed(limit: Int) async throws -> [any DataObject] {
        try await dbQueue.read { db in
            let metadataRows = try ObjectMetadata
                .filter(ObjectMetadata.Columns.lastViewed != nil)
                .order(ObjectMetadata.Columns.lastViewed.desc)
                .limit(limit)
                .fetchAll(db)

            // Group by type for batch fetching
            var artIDs: [String] = [], campIDs: [String] = []
            var eventIDs: [String] = [], mvIDs: [String] = []
            for meta in metadataRows {
                switch meta.dataObjectType {
                case .art: artIDs.append(meta.objectId)
                case .camp: campIDs.append(meta.objectId)
                case .event: eventIDs.append(meta.objectId)
                case .mutantVehicle: mvIDs.append(meta.objectId)
                case .none: break
                }
            }

            // Batch fetch each type
            var objectsByUID: [String: any DataObject] = [:]
            if !artIDs.isEmpty {
                for obj in try ArtObject.filter(artIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !campIDs.isEmpty {
                for obj in try CampObject.filter(campIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !eventIDs.isEmpty {
                for obj in try EventObject.filter(eventIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !mvIDs.isEmpty {
                for obj in try MutantVehicleObject.filter(mvIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }

            // Preserve original ordering (most recently viewed first)
            return metadataRows.compactMap { objectsByUID[$0.objectId] }
        }
    }

    func fetchRecentlyViewedWithDates(limit: Int) async throws -> [(object: any DataObject, firstViewed: Date?, lastViewed: Date)] {
        try await dbQueue.read { db in
            let metadataRows = try ObjectMetadata
                .filter(ObjectMetadata.Columns.lastViewed != nil)
                .order(ObjectMetadata.Columns.lastViewed.desc)
                .limit(limit)
                .fetchAll(db)

            // Group by type for batch fetching
            var artIDs: [String] = [], campIDs: [String] = []
            var eventIDs: [String] = [], mvIDs: [String] = []
            for meta in metadataRows {
                switch meta.dataObjectType {
                case .art: artIDs.append(meta.objectId)
                case .camp: campIDs.append(meta.objectId)
                case .event: eventIDs.append(meta.objectId)
                case .mutantVehicle: mvIDs.append(meta.objectId)
                case .none: break
                }
            }

            var objectsByUID: [String: any DataObject] = [:]
            if !artIDs.isEmpty {
                for obj in try ArtObject.filter(artIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !campIDs.isEmpty {
                for obj in try CampObject.filter(campIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !eventIDs.isEmpty {
                for obj in try EventObject.filter(eventIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }
            if !mvIDs.isEmpty {
                for obj in try MutantVehicleObject.filter(mvIDs.contains(Column("uid"))).fetchAll(db) {
                    objectsByUID[obj.uid] = obj
                }
            }

            return metadataRows.compactMap { meta in
                guard let obj = objectsByUID[meta.objectId],
                      let lastViewed = meta.lastViewed else { return nil }
                return (object: obj, firstViewed: meta.firstViewed, lastViewed: lastViewed)
            }
        }
    }

    func clearLastViewed(for object: any DataObject) async throws {
        let identity = metadataIdentity(for: object)
        try await dbQueue.write { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == identity.type.rawValue)
                .filter(ObjectMetadata.Columns.objectId == identity.uid)
                .fetchOne(db) else { return }

            metadata.lastViewed = nil
            metadata.updatedAt = Date()
            try metadata.update(db, columns: [
                ObjectMetadata.Columns.lastViewed,
                ObjectMetadata.Columns.updatedAt,
            ])
        }
    }

    func clearAllRecentlyViewed() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: """
                UPDATE object_metadata SET last_viewed = NULL, updated_at = ?
                WHERE last_viewed IS NOT NULL
            """, arguments: [Date()])
        }
    }

    /// Every favorited *occurrence*, oldest first.
    ///
    /// Since favorites became per occurrence this returns exactly the showings the user
    /// picked — not every showing of an event with one favorited showing, which is what
    /// the Favorites screen used to list.
    func fetchFavoriteEvents() async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            let index = try EventFavoriteIndex.load(db)
            let candidates = index.candidateEventUIDs
            guard !candidates.isEmpty else { return [] }

            let occurrences = try EventOccurrence
                .filter(candidates.contains(EventOccurrence.Columns.eventId))
                .fetchAll(db)
            let inflated = try eventObjectOccurrences(for: occurrences, db: db)
            return inflated.filter { index.isFavorite($0) }
        }
        return events.sorted { $0.startDate < $1.startDate }
    }

    func fetchObjects(byUIDs uids: [String]) async throws -> [any DataObject] {
        guard !uids.isEmpty else { return [] }
        return try await dbQueue.read { db in
            let uidSet = Set(uids)
            var objects: [any DataObject] = []
            objects += try ArtObject.filter(uidSet.contains(Column("uid"))).fetchAll(db)
            objects += try CampObject.filter(uidSet.contains(Column("uid"))).fetchAll(db)
            objects += try EventObject.filter(uidSet.contains(Column("uid"))).fetchAll(db)
            objects += try MutantVehicleObject.filter(uidSet.contains(Column("uid"))).fetchAll(db)
            return objects
        }
    }

    // MARK: - Data Import

    func importFromPlayaAPI() async throws {
        // Load data from bundles and parse
        let artData = try BundleDataLoader.loadArt()
        let campData = try BundleDataLoader.loadCamps()
        let eventData = try BundleDataLoader.loadEvents()
        let updateData = try? BundleDataLoader.loadUpdateInfo()

        try await importFromData(artData: artData, campData: campData, eventData: eventData, mvData: nil, updateData: updateData)
    }

    func needsImport(bundleUpdateData: Data) async throws -> Bool {
        let bundleInfo = try APIParserFactory.create().parseUpdateInfo(from: bundleUpdateData)
        let storedInfo = try await getUpdateInfo()
        guard !storedInfo.isEmpty else { return true }

        let storedByType = Dictionary(uniqueKeysWithValues: storedInfo.map { ($0.dataType, $0) })
        let bundleByType: [(DataObjectType, FileUpdateInfo?)] = [
            (.art, bundleInfo.art),
            (.camp, bundleInfo.camps),
            (.event, bundleInfo.events),
            (.mutantVehicle, bundleInfo.mv)
        ]
        for (type, fileInfo) in bundleByType {
            guard let fileInfo else { continue }
            guard let stored = storedByType[type.rawValue] else { return true }
            if fileInfo.updated > stored.lastUpdated { return true }
        }
        return false
    }

    func importFromData(artData: Data, campData: Data, eventData: Data, mvData: Data?, updateData: Data?) async throws {
        let apiParser = APIParserFactory.create()
        let importStart = CFAbsoluteTimeGetCurrent()

        // Per-type source timestamps from update.json; fall back to import time so that
        // `needsImport` comparisons remain conservative for data imported without metadata.
        let bundleUpdateInfo = updateData.flatMap { try? apiParser.parseUpdateInfo(from: $0) }

        try await dbQueue.write { db in
            // The import wholesale-rebuilds the FTS and spatial indexes below, so the
            // per-row sync triggers are pure overhead during the bulk delete + insert.
            // Drop them for the duration of the transaction and recreate afterwards.
            try Self.dropIndexSyncTriggers(db)

            // Clear update_info first (required for re-imports — primary key conflict otherwise)
            try UpdateInfo.deleteAll(db)

            // Step 1: Import art objects first
            let apiArtObjects = try apiParser.parseArt(from: artData)

            // Clear existing art data
            try ArtImage.deleteAll(db)
            try ArtObject.deleteAll(db)

            // uid → denormalized GPS for event location resolution (avoids per-event lookups)
            var artGPS: [String: (lat: Double?, lon: Double?)] = [:]
            artGPS.reserveCapacity(apiArtObjects.count)

            for apiArt in apiArtObjects {
                var artObject = try self.convertArtObject(from: apiArt)
                try artObject.insert(db)
                artGPS[artObject.uid] = (artObject.gpsLatitude, artObject.gpsLongitude)

                // Insert art images
                for apiImage in apiArt.images {
                    var artImage = ArtImage(
                        id: nil,
                        artId: apiArt.uid.value,
                        thumbnailUrl: apiImage.thumbnailUrl,
                        galleryRef: apiImage.galleryRef
                    )
                    try artImage.insert(db)
                }
            }

            // Step 2: Import camp objects
            let apiCampObjects = try apiParser.parseCamps(from: campData)

            // Clear existing camp data
            try CampImage.deleteAll(db)
            try CampObject.deleteAll(db)

            var campGPS: [String: (lat: Double?, lon: Double?)] = [:]
            campGPS.reserveCapacity(apiCampObjects.count)

            for apiCamp in apiCampObjects {
                var campObject = try self.convertCampObject(from: apiCamp)
                try campObject.insert(db)
                campGPS[campObject.uid] = (campObject.gpsLatitude, campObject.gpsLongitude)

                // Insert camp images
                for apiImage in apiCamp.images {
                    var campImage = CampImage(
                        id: nil,
                        campId: apiCamp.uid.value,
                        thumbnailUrl: apiImage.thumbnailUrl
                    )
                    try campImage.insert(db)
                }
            }

            // Step 3: Import events with relationship resolution
            let apiEventObjects = try apiParser.parseEvents(from: eventData)

            // Clear existing event data
            try EventOccurrence.deleteAll(db)
            try EventObject.deleteAll(db)

            // Track unique events to handle duplicates in data
            var processedEventUIDs = Set<String>()
            var duplicateEventCount = 0
            var correctedOccurrenceCount = 0

            for apiEvent in apiEventObjects {
                // Skip duplicate events (keep first occurrence)
                if processedEventUIDs.contains(apiEvent.uid.value) {
                    duplicateEventCount += 1
                    continue
                }
                processedEventUIDs.insert(apiEvent.uid.value)

                var eventObject = try self.convertEventObject(from: apiEvent)

                // Resolve camp relationship and copy GPS coordinates
                if let campId = apiEvent.hostedByCamp?.value, let gps = campGPS[campId] {
                    eventObject.gpsLatitude = gps.lat
                    eventObject.gpsLongitude = gps.lon
                }

                // Resolve art relationship and copy GPS coordinates
                if let artId = apiEvent.locatedAtArt?.value, let gps = artGPS[artId] {
                    eventObject.gpsLatitude = gps.lat
                    eventObject.gpsLongitude = gps.lon
                }

                try eventObject.insert(db)

                // Insert event occurrences with time correction
                for apiOccurrence in apiEvent.occurrenceSet {
                    let corrected = Self.correctedOccurrenceTimes(
                        startTime: apiOccurrence.startTime,
                        endTime: apiOccurrence.endTime
                    )
                    if corrected.endTime != apiOccurrence.endTime {
                        correctedOccurrenceCount += 1
                    }
                    var eventOccurrence = EventOccurrence(
                        id: nil,
                        eventId: apiEvent.uid.value,
                        startTime: corrected.startTime,
                        endTime: corrected.endTime
                    )
                    try eventOccurrence.insert(db)
                }
            }

            if duplicateEventCount > 0 {
                print("PlayaDB: Skipped \(duplicateEventCount) duplicate event UIDs during import")
            }
            if correctedOccurrenceCount > 0 {
                print("PlayaDB: Corrected \(correctedOccurrenceCount) event occurrence times during import")
            }
            
            // Step 3b: Import mutant vehicles (if data provided)
            var mvCount = 0
            if let mvData = mvData {
                let apiMVObjects = try apiParser.parseMutantVehicles(from: mvData)
                mvCount = apiMVObjects.count

                // Clear existing MV data
                try MutantVehicleTag.deleteAll(db)
                try MutantVehicleImage.deleteAll(db)
                try MutantVehicleObject.deleteAll(db)

                for apiMV in apiMVObjects {
                    var mvObject = self.convertMutantVehicleObject(from: apiMV)
                    mvObject.tagsText = apiMV.tags.isEmpty ? nil : apiMV.tags.joined(separator: " ")
                    try mvObject.insert(db)

                    for apiImage in apiMV.images {
                        var mvImage = MutantVehicleImage(
                            mvId: apiMV.uid.value,
                            thumbnailUrl: apiImage.thumbnailUrl
                        )
                        try mvImage.insert(db)
                    }

                    for tagString in apiMV.tags {
                        var mvTag = MutantVehicleTag(
                            mvId: apiMV.uid.value,
                            tag: tagString
                        )
                        try mvTag.insert(db)
                    }
                }
            }

            // Step 4: Rebuild FTS indexes wholesale (sync triggers were dropped above)
            try db.execute(sql: "INSERT INTO art_objects_fts(art_objects_fts) VALUES('rebuild')")
            try db.execute(sql: "INSERT INTO camp_objects_fts(camp_objects_fts) VALUES('rebuild')")
            try db.execute(sql: "INSERT INTO event_objects_fts(event_objects_fts) VALUES('rebuild')")
            if mvData != nil {
                try db.execute(sql: "INSERT INTO mv_objects_fts(mv_objects_fts) VALUES('rebuild')")
            }

            // Step 4b: Rebuild spatial index set-based (object rows already carry GPS)
            try db.execute(sql: "DELETE FROM spatial_index")
            try db.execute(sql: "DELETE FROM spatial_objects")
            for (type, table) in [("art", "art_objects"), ("camp", "camp_objects"), ("event", "event_objects")] {
                try db.execute(sql: """
                    INSERT INTO spatial_objects (object_type, object_uid)
                    SELECT '\(type)', uid FROM \(table)
                    WHERE gps_latitude IS NOT NULL AND gps_longitude IS NOT NULL
                    """)
                try db.execute(sql: """
                    INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                    SELECT so.spatial_id, t.gps_latitude, t.gps_latitude, t.gps_longitude, t.gps_longitude
                    FROM spatial_objects so
                    JOIN \(table) t ON t.uid = so.object_uid
                    WHERE so.object_type = '\(type)'
                    """)
            }

            // Step 4c: Rebuild the occurrence spatial index.
            try rebuildOccurrenceRTree(db)

            // Step 4d: Recreate the per-row sync triggers dropped at the start.
            try self.setupFTS5Tables(db)
            try self.setupRTreeIndex(db)

            // Step 5: Update import info
            let now = Date()

            var artUpdateInfo = UpdateInfo(
                dataType: DataObjectType.art.rawValue,
                lastUpdated: bundleUpdateInfo?.art?.updated ?? now,
                totalCount: apiArtObjects.count,
                createdAt: now,
                fetchStatus: "complete",
                fetchDate: now,
                ingestionDate: now
            )
            try artUpdateInfo.insert(db)

            var campUpdateInfo = UpdateInfo(
                dataType: DataObjectType.camp.rawValue,
                lastUpdated: bundleUpdateInfo?.camps?.updated ?? now,
                totalCount: apiCampObjects.count,
                createdAt: now,
                fetchStatus: "complete",
                fetchDate: now,
                ingestionDate: now
            )
            try campUpdateInfo.insert(db)

            var eventUpdateInfo = UpdateInfo(
                dataType: DataObjectType.event.rawValue,
                lastUpdated: bundleUpdateInfo?.events?.updated ?? now,
                totalCount: apiEventObjects.count,
                createdAt: now,
                fetchStatus: "complete",
                fetchDate: now,
                ingestionDate: now
            )
            try eventUpdateInfo.insert(db)

            if mvData != nil {
                var mvUpdateInfo = UpdateInfo(
                    dataType: DataObjectType.mutantVehicle.rawValue,
                    lastUpdated: bundleUpdateInfo?.mv?.updated ?? now,
                    totalCount: mvCount,
                    createdAt: now,
                    fetchStatus: "complete",
                    fetchDate: now,
                    ingestionDate: now
                )
                try mvUpdateInfo.insert(db)
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - importStart
        print(String(format: "PlayaDB: Import completed in %.2fs", elapsed))
    }

    // MARK: - Data Conversion Methods
    
    private func convertArtObject(from apiArt: Art) throws -> ArtObject {
        return ArtObject(
            uid: apiArt.uid.value,
            name: apiArt.name,
            year: apiArt.year,
            url: apiArt.url,
            contactEmail: apiArt.contactEmail,
            hometown: apiArt.hometown,
            description: apiArt.description,
            artist: apiArt.artist,
            category: apiArt.category,
            program: apiArt.program,
            donationLink: apiArt.donationLink,
            locationString: apiArt.locationString,
            locationHour: apiArt.location?.hour,
            locationMinute: apiArt.location?.minute,
            locationDistance: apiArt.location?.distance,
            locationCategory: apiArt.location?.category,
            gpsLatitude: apiArt.location?.gpsLatitude,
            gpsLongitude: apiArt.location?.gpsLongitude,
            guidedTours: apiArt.guidedTours,
            selfGuidedTourMap: apiArt.selfGuidedTourMap,
            audioTourUrl: apiArt.audioTourUrl
        )
    }
    
    private func convertCampObject(from apiCamp: Camp) throws -> CampObject {
        return CampObject(
            uid: apiCamp.uid.value,
            name: apiCamp.name,
            year: apiCamp.year,
            url: apiCamp.url,
            contactEmail: apiCamp.contactEmail,
            hometown: apiCamp.hometown,
            description: apiCamp.description,
            landmark: apiCamp.landmark,
            locationString: apiCamp.locationString,
            locationLocationString: apiCamp.location?.string,
            frontage: apiCamp.location?.frontage,
            intersection: apiCamp.location?.intersection,
            intersectionType: apiCamp.location?.intersectionType,
            dimensions: apiCamp.location?.dimensions,
            exactLocation: apiCamp.location?.exactLocation,
            gpsLatitude: apiCamp.location?.gpsLatitude,
            gpsLongitude: apiCamp.location?.gpsLongitude
        )
    }
    
    private func convertEventObject(from apiEvent: Event) throws -> EventObject {
        return EventObject(
            uid: apiEvent.uid.value,
            name: apiEvent.title,
            year: apiEvent.year,
            eventId: apiEvent.eventId,
            description: apiEvent.description,
            eventTypeLabel: apiEvent.eventType.label,
            eventTypeCode: apiEvent.eventType.type.rawValue,
            printDescription: apiEvent.printDescription,
            slug: apiEvent.slug,
            hostedByCamp: apiEvent.hostedByCamp?.value,
            locatedAtArt: apiEvent.locatedAtArt?.value,
            otherLocation: apiEvent.otherLocation,
            checkLocation: apiEvent.checkLocation,
            url: apiEvent.url,
            allDay: apiEvent.allDay,
            contact: apiEvent.contact,
            gpsLatitude: nil, // Will be resolved from relationships
            gpsLongitude: nil  // Will be resolved from relationships
        )
    }
    
    // MARK: - Event Occurrence Time Correction

    /// Maximum reasonable duration for a single event occurrence (24 hours).
    /// Occurrences exceeding this are assumed to have corrupted end dates.
    private static let maxReasonableOccurrenceDuration: TimeInterval = 24 * 60 * 60

    /// Calendar configured for Black Rock City timezone (Pacific Time)
    private static var playaCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }()

    /// Corrects corrupted event occurrence times from the API.
    ///
    /// The PlayaEvents API returns occurrences where the end date is on the wrong day
    /// but the time-of-day component is correct. This fixes both negative durations
    /// (end before start) and excessively long durations (end days after start).
    ///
    /// Algorithm: take the time-of-day from endTime, apply it to startTime's calendar date.
    /// If the result is still before startTime, add 1 day (midnight crossing).
    static func correctedOccurrenceTimes(
        startTime: Date,
        endTime: Date,
        calendar: Calendar = PlayaDBImpl.playaCalendar
    ) -> (startTime: Date, endTime: Date) {
        let duration = endTime.timeIntervalSince(startTime)

        // Normal duration: no correction needed
        if duration >= 0 && duration <= maxReasonableOccurrenceDuration {
            return (startTime, endTime)
        }

        // Extract time-of-day from endTime, apply to startTime's date
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: endTime)
        guard let correctedEnd = calendar.date(
            bySettingHour: endComponents.hour ?? 0,
            minute: endComponents.minute ?? 0,
            second: endComponents.second ?? 0,
            of: startTime
        ) else {
            return (startTime, endTime)
        }

        // If correctedEnd is before startTime, the event crosses midnight
        if correctedEnd < startTime {
            guard let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: correctedEnd) else {
                return (startTime, endTime)
            }
            return (startTime, nextDayEnd)
        }

        return (startTime, correctedEnd)
    }

    private func convertMutantVehicleObject(from apiMV: MutantVehicle) -> MutantVehicleObject {
        MutantVehicleObject(
            uid: apiMV.uid.value,
            name: apiMV.name,
            year: apiMV.year,
            url: apiMV.url,
            contactEmail: apiMV.contactEmail,
            hometown: apiMV.hometown,
            description: apiMV.description,
            artist: apiMV.artist,
            donationLink: apiMV.donationLink
        )
    }

    func getUpdateInfo() async throws -> [UpdateInfo] {
        return try await dbQueue.read { db in
            try UpdateInfo.fetchAll(db)
        }
    }
}

// MARK: - Error Types

enum PlayaDBError: Error {
    case notImplemented(String)
    case databaseError(String)
    case importError(String)
    case metadataNotFound
    
    var localizedDescription: String {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .importError(let message):
            return "Import error: \(message)"
        case .metadataNotFound:
            return "Metadata not found for requested object"
        }
    }
}
