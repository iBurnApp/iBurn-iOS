import Foundation
import CoreLocation
import MapKit
import GRDB
import PlayaAPI

/// Internal implementation of PlayaDB using GRDB
internal class PlayaDBImpl: PlayaDB {
    // MARK: - Database Connection

    internal let dbQueue: DatabaseQueue  // Internal for testing
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
        
        // Create database queue
        self.dbQueue = try DatabaseQueue(path: self.dbPath)
        
        // Initialize database schema
        try setupDatabase()
        
        // Setup reactive observations
        setupObservations()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() throws {
        try dbQueue.write { db in
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
                    donation_link TEXT
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
            
            // Create FTS5 virtual tables for full-text search
            try setupFTS5Tables(db)
            
            // Create R-Tree spatial index for geographic queries
            try setupRTreeIndex(db)
        }
    }
    
    private func setupFTS5Tables(_ db: Database) throws {
        // Create FTS5 table for art objects
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS art_objects_fts USING fts5(
                uid UNINDEXED,
                name,
                description,
                artist,
                hometown,
                category,
                content=art_objects,
                content_rowid=rowid,
                tokenize='porter unicode61'
            )
        """)
        
        // Create FTS5 table for camp objects
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS camp_objects_fts USING fts5(
                uid UNINDEXED,
                name,
                description,
                landmark,
                hometown,
                content=camp_objects,
                content_rowid=rowid,
                tokenize='porter unicode61'
            )
        """)
        
        // Create FTS5 table for event objects
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS event_objects_fts USING fts5(
                uid UNINDEXED,
                name,
                description,
                event_type_label,
                print_description,
                content=event_objects,
                content_rowid=rowid,
                tokenize='porter unicode61'
            )
        """)
        
        // Create triggers to keep FTS tables in sync
        
        // Art triggers
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS art_objects_ai AFTER INSERT ON art_objects BEGIN
                INSERT INTO art_objects_fts(rowid, uid, name, description, artist, hometown, category)
                VALUES (new.rowid, new.uid, new.name, new.description, new.artist, new.hometown, new.category);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS art_objects_ad AFTER DELETE ON art_objects BEGIN
                DELETE FROM art_objects_fts WHERE rowid = old.rowid;
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS art_objects_au AFTER UPDATE ON art_objects BEGIN
                DELETE FROM art_objects_fts WHERE rowid = old.rowid;
                INSERT INTO art_objects_fts(rowid, uid, name, description, artist, hometown, category)
                VALUES (new.rowid, new.uid, new.name, new.description, new.artist, new.hometown, new.category);
            END
        """)
        
        // Camp triggers
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS camp_objects_ai AFTER INSERT ON camp_objects BEGIN
                INSERT INTO camp_objects_fts(rowid, uid, name, description, landmark, hometown)
                VALUES (new.rowid, new.uid, new.name, new.description, new.landmark, new.hometown);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS camp_objects_ad AFTER DELETE ON camp_objects BEGIN
                DELETE FROM camp_objects_fts WHERE rowid = old.rowid;
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS camp_objects_au AFTER UPDATE ON camp_objects BEGIN
                DELETE FROM camp_objects_fts WHERE rowid = old.rowid;
                INSERT INTO camp_objects_fts(rowid, uid, name, description, landmark, hometown)
                VALUES (new.rowid, new.uid, new.name, new.description, new.landmark, new.hometown);
            END
        """)
        
        // Event triggers
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_objects_ai AFTER INSERT ON event_objects BEGIN
                INSERT INTO event_objects_fts(rowid, uid, name, description, event_type_label, print_description)
                VALUES (new.rowid, new.uid, new.name, new.description, new.event_type_label, new.print_description);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_objects_ad AFTER DELETE ON event_objects BEGIN
                DELETE FROM event_objects_fts WHERE rowid = old.rowid;
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_objects_au AFTER UPDATE ON event_objects BEGIN
                DELETE FROM event_objects_fts WHERE rowid = old.rowid;
                INSERT INTO event_objects_fts(rowid, uid, name, description, event_type_label, print_description)
                VALUES (new.rowid, new.uid, new.name, new.description, new.event_type_label, new.print_description);
            END
        """)

        // Create FTS5 table for mutant vehicle objects
        try db.execute(sql: """
            CREATE VIRTUAL TABLE IF NOT EXISTS mv_objects_fts USING fts5(
                uid UNINDEXED,
                name,
                description,
                artist,
                hometown,
                content=mv_objects,
                content_rowid=rowid,
                tokenize='porter unicode61'
            )
        """)

        // MV triggers
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS mv_objects_ai AFTER INSERT ON mv_objects BEGIN
                INSERT INTO mv_objects_fts(rowid, uid, name, description, artist, hometown)
                VALUES (new.rowid, new.uid, new.name, new.description, new.artist, new.hometown);
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS mv_objects_ad AFTER DELETE ON mv_objects BEGIN
                DELETE FROM mv_objects_fts WHERE rowid = old.rowid;
            END
        """)

        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS mv_objects_au AFTER UPDATE ON mv_objects BEGIN
                DELETE FROM mv_objects_fts WHERE rowid = old.rowid;
                INSERT INTO mv_objects_fts(rowid, uid, name, description, artist, hometown)
                VALUES (new.rowid, new.uid, new.name, new.description, new.artist, new.hometown);
            END
        """)
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
        
        // Create triggers to maintain spatial index for art objects
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS art_spatial_insert AFTER INSERT ON art_objects
            WHEN NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL
            BEGIN
                INSERT INTO spatial_objects (object_type, object_uid) VALUES ('art', NEW.uid);
                INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                VALUES (last_insert_rowid(), NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS art_spatial_delete AFTER DELETE ON art_objects
            WHEN OLD.gps_latitude IS NOT NULL AND OLD.gps_longitude IS NOT NULL
            BEGIN
                DELETE FROM spatial_index WHERE id = (
                    SELECT spatial_id FROM spatial_objects 
                    WHERE object_type = 'art' AND object_uid = OLD.uid
                );
                DELETE FROM spatial_objects WHERE object_type = 'art' AND object_uid = OLD.uid;
            END
        """)
        
        // Create triggers for camp objects
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS camp_spatial_insert AFTER INSERT ON camp_objects
            WHEN NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL
            BEGIN
                INSERT INTO spatial_objects (object_type, object_uid) VALUES ('camp', NEW.uid);
                INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                VALUES (last_insert_rowid(), NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS camp_spatial_delete AFTER DELETE ON camp_objects
            WHEN OLD.gps_latitude IS NOT NULL AND OLD.gps_longitude IS NOT NULL
            BEGIN
                DELETE FROM spatial_index WHERE id = (
                    SELECT spatial_id FROM spatial_objects 
                    WHERE object_type = 'camp' AND object_uid = OLD.uid
                );
                DELETE FROM spatial_objects WHERE object_type = 'camp' AND object_uid = OLD.uid;
            END
        """)
        
        // Create triggers for event objects
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_spatial_insert AFTER INSERT ON event_objects
            WHEN NEW.gps_latitude IS NOT NULL AND NEW.gps_longitude IS NOT NULL
            BEGIN
                INSERT INTO spatial_objects (object_type, object_uid) VALUES ('event', NEW.uid);
                INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon)
                VALUES (last_insert_rowid(), NEW.gps_latitude, NEW.gps_latitude, NEW.gps_longitude, NEW.gps_longitude);
            END
        """)
        
        try db.execute(sql: """
            CREATE TRIGGER IF NOT EXISTS event_spatial_delete AFTER DELETE ON event_objects
            WHEN OLD.gps_latitude IS NOT NULL AND OLD.gps_longitude IS NOT NULL
            BEGIN
                DELETE FROM spatial_index WHERE id = (
                    SELECT spatial_id FROM spatial_objects 
                    WHERE object_type = 'event' AND object_uid = OLD.uid
                );
                DELETE FROM spatial_objects WHERE object_type = 'event' AND object_uid = OLD.uid;
            END
        """)
    }
    
    // MARK: - Data Access Methods
    
    func fetchArt() async throws -> [ArtObject] {
        let art = try await dbQueue.read { db in
            try ArtObject.fetchAll(db)
        }
        try await ensureMetadata(for: .art, ids: art.map(\.uid))
        return art
    }
    
    func fetchCamps() async throws -> [CampObject] {
        let camps = try await dbQueue.read { db in
            try CampObject.fetchAll(db)
        }
        try await ensureMetadata(for: .camp, ids: camps.map(\.uid))
        return camps
    }
    
    func fetchEvents() async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db in
            // Fetch events with their occurrences
            let events = try EventObject.including(all: EventObject.occurrences).fetchAll(db)
            
            // Convert to EventObjectOccurrence instances
            var eventObjectOccurrences: [EventObjectOccurrence] = []
            for event in events {
                let occurrences = try event.occurrences.fetchAll(db)
                for occurrence in occurrences {
                    eventObjectOccurrences.append(EventObjectOccurrence(event: event, occurrence: occurrence))
                }
            }
            
            return eventObjectOccurrences
        }
        try await ensureMetadata(for: .event, ids: events.map { $0.event.uid })
        return events
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
                .including(required: EventOccurrence.event)
                .fetchAll(db)
            
            // Convert to EventObjectOccurrence instances
            return try occurrences.map { occurrence in
                let event = try occurrence.event.fetchOne(db)!
                return EventObjectOccurrence(event: event, occurrence: occurrence)
            }
        }
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            // Find occurrences that overlap with this date range
            let occurrences = try EventOccurrence
                .filter(Column("start_time") < endDate && Column("end_time") > startDate)
                .including(required: EventOccurrence.event)
                .fetchAll(db)
            
            // Convert to EventObjectOccurrence instances
            return try occurrences.map { occurrence in
                let event = try occurrence.event.fetchOne(db)!
                return EventObjectOccurrence(event: event, occurrence: occurrence)
            }
        }
    }
    
    func fetchCurrentEvents(_ now: Date = Date()) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            // Find occurrences happening right now
            let occurrences = try EventOccurrence
                .filter(Column("start_time") <= now && Column("end_time") > now)
                .including(required: EventOccurrence.event)
                .fetchAll(db)
            
            // Convert to EventObjectOccurrence instances
            return try occurrences.map { occurrence in
                let event = try occurrence.event.fetchOne(db)!
                return EventObjectOccurrence(event: event, occurrence: occurrence)
            }
        }
    }
    
    func fetchUpcomingEvents(within hours: Int = 24, from now: Date = Date()) async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
            let futureTime = now.addingTimeInterval(TimeInterval(hours * 3600))
            
            // Find occurrences starting within the next N hours
            let occurrences = try EventOccurrence
                .filter(Column("start_time") > now && Column("start_time") <= futureTime)
                .including(required: EventOccurrence.event)
                .order(Column("start_time"))
                .fetchAll(db)
            
            // Convert to EventObjectOccurrence instances
            return try occurrences.map { occurrence in
                let event = try occurrence.event.fetchOne(db)!
                return EventObjectOccurrence(event: event, occurrence: occurrence)
            }
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

        try await ensureMetadata(for: .art, ids: result.0.map(\.uid))
        try await ensureMetadata(for: .camp, ids: result.1.map(\.uid))
        try await ensureMetadata(for: .event, ids: result.2.map(\.uid))

        var objects: [any DataObject] = []
        objects.append(contentsOf: result.0)
        objects.append(contentsOf: result.1)
        objects.append(contentsOf: result.2)
        return objects
    }
    
    func searchObjects(_ query: String) async throws -> [any DataObject] {
        let result = try await dbQueue.read { db -> ([ArtObject], [CampObject], [EventObject], [MutantVehicleObject]) in
            // Prepare search query for FTS5 (escape special characters)
            let ftsQuery = query.replacingOccurrences(of: "\"", with: "\"\"")

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

        try await ensureMetadata(for: .art, ids: result.0.map(\.uid))
        try await ensureMetadata(for: .camp, ids: result.1.map(\.uid))
        try await ensureMetadata(for: .event, ids: result.2.map(\.uid))
        try await ensureMetadata(for: .mutantVehicle, ids: result.3.map(\.uid))

        var objects: [any DataObject] = []
        objects.append(contentsOf: result.0)
        objects.append(contentsOf: result.1)
        objects.append(contentsOf: result.2)
        objects.append(contentsOf: result.3)
        return objects
    }

    // MARK: - Single Object Fetch

    func fetchArt(uid: String) async throws -> ArtObject? {
        let art = try await dbQueue.read { db in
            try ArtObject.filter(Column("uid") == uid).fetchOne(db)
        }
        if let art {
            try await ensureMetadata(for: .art, ids: [art.uid])
        }
        return art
    }

    func fetchCamp(uid: String) async throws -> CampObject? {
        let camp = try await dbQueue.read { db in
            try CampObject.filter(Column("uid") == uid).fetchOne(db)
        }
        if let camp {
            try await ensureMetadata(for: .camp, ids: [camp.uid])
        }
        return camp
    }

    func fetchEvent(uid: String) async throws -> EventObject? {
        let event = try await dbQueue.read { db in
            try EventObject.filter(Column("uid") == uid).fetchOne(db)
        }
        if let event {
            try await ensureMetadata(for: .event, ids: [event.uid])
        }
        return event
    }

    func fetchEvents(hostedByCampUID campUID: String) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            let eventObjects = try EventObject
                .filter(Column("hosted_by_camp") == campUID)
                .fetchAll(db)
            var result: [EventObjectOccurrence] = []
            for event in eventObjects {
                let occurrences = try event.occurrences.fetchAll(db)
                for occ in occurrences {
                    result.append(EventObjectOccurrence(event: event, occurrence: occ))
                }
            }
            return result
        }
        let sorted = events.sorted { $0.startDate < $1.startDate }
        try await ensureMetadata(for: .event, ids: sorted.map { $0.event.uid })
        return sorted
    }

    func fetchEvents(locatedAtArtUID artUID: String) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db -> [EventObjectOccurrence] in
            let eventObjects = try EventObject
                .filter(Column("located_at_art") == artUID)
                .fetchAll(db)
            var result: [EventObjectOccurrence] = []
            for event in eventObjects {
                let occurrences = try event.occurrences.fetchAll(db)
                for occ in occurrences {
                    result.append(EventObjectOccurrence(event: event, occurrence: occ))
                }
            }
            return result
        }
        let sorted = events.sorted { $0.startDate < $1.startDate }
        try await ensureMetadata(for: .event, ids: sorted.map { $0.event.uid })
        return sorted
    }

    // MARK: - Mutant Vehicle Data Access

    func fetchMutantVehicles() async throws -> [MutantVehicleObject] {
        let mvs = try await dbQueue.read { db in
            try MutantVehicleObject.fetchAll(db)
        }
        try await ensureMetadata(for: .mutantVehicle, ids: mvs.map(\.uid))
        return mvs
    }

    func fetchMutantVehicles(filter: MutantVehicleFilter) async throws -> [MutantVehicleObject] {
        let mvs = try await dbQueue.read { db in
            try self.mutantVehicleRequest(filter: filter).fetchAll(db)
        }
        try await ensureMetadata(for: .mutantVehicle, ids: mvs.map(\.uid))
        return mvs
    }

    func fetchMutantVehicle(uid: String) async throws -> MutantVehicleObject? {
        let mv = try await dbQueue.read { db in
            try MutantVehicleObject.filter(Column("uid") == uid).fetchOne(db)
        }
        if let mv {
            try await ensureMetadata(for: .mutantVehicle, ids: [mv.uid])
        }
        return mv
    }

    func fetchMutantVehicleImageURLs() async throws -> [String: URL] {
        try await dbQueue.read { db in
            let images = try MutantVehicleImage
                .filter(MutantVehicleImage.Columns.thumbnailUrl != nil)
                .fetchAll(db)
            var result: [String: URL] = [:]
            for image in images {
                if let url = image.thumbnailUrl, result[image.mvId] == nil {
                    result[image.mvId] = url
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

    /// Build an event occurrence query from filter options (internal - uses GRDB types)
    internal func eventOccurrenceRequest(filter: EventFilter) -> QueryInterfaceRequest<EventOccurrence> {
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

        // Default ordering by start time
        return request.orderedByStartTime()
    }

    private func eventObjectOccurrences(
        filter: EventFilter,
        db: Database
    ) throws -> [EventObjectOccurrence] {
        let occurrenceRequest = eventOccurrenceRequest(filter: filter)
            .including(required: EventOccurrence.event)

        let occurrences = try occurrenceRequest.fetchAll(db)
        let favoriteEventIds: Set<String>
        if filter.onlyFavorites {
            let metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == DataObjectType.event.rawValue)
                .filter(ObjectMetadata.Columns.isFavorite == true)
                .fetchAll(db)
            favoriteEventIds = Set(metadata.map(\.objectId))
        } else {
            favoriteEventIds = []
        }

        var eventObjectOccurrences: [EventObjectOccurrence] = []
        for occurrence in occurrences {
            guard let event = try occurrence.event.fetchOne(db) else {
                continue
            }

            var includeEvent = true
            if filter.onlyFavorites && !favoriteEventIds.contains(event.uid) {
                includeEvent = false
            }

            if let year = filter.year, event.year != year {
                includeEvent = false
            }

            if let region = filter.region {
                if let lat = event.gpsLatitude, let lon = event.gpsLongitude {
                    let minLat = region.center.latitude - region.span.latitudeDelta / 2
                    let maxLat = region.center.latitude + region.span.latitudeDelta / 2
                    let minLon = region.center.longitude - region.span.longitudeDelta / 2
                    let maxLon = region.center.longitude + region.span.longitudeDelta / 2

                    if lat < minLat || lat > maxLat || lon < minLon || lon > maxLon {
                        includeEvent = false
                    }
                } else {
                    includeEvent = false
                }
            }

            if let searchText = filter.searchText, !searchText.isEmpty {
                let lowerSearch = searchText.lowercased()
                let nameMatch = event.name.lowercased().contains(lowerSearch)
                let descMatch = event.description?.lowercased().contains(lowerSearch) ?? false
                if !nameMatch && !descMatch {
                    includeEvent = false
                }
            }

            if let allowedTypes = filter.eventTypeCodes, !allowedTypes.isEmpty {
                if !allowedTypes.contains(event.eventTypeCode) {
                    includeEvent = false
                }
            }

            if includeEvent {
                eventObjectOccurrences.append(EventObjectOccurrence(event: event, occurrence: occurrence))
            }
        }

        return eventObjectOccurrences
    }

    // MARK: - Filtered Data Access (Public API)

    func fetchArt(filter: ArtFilter) async throws -> [ArtObject] {
        let art = try await dbQueue.read { db in
            try artRequest(filter: filter).fetchAll(db)
        }
        try await ensureMetadata(for: .art, ids: art.map(\.uid))
        return art
    }

    func fetchCamps(filter: CampFilter) async throws -> [CampObject] {
        let camps = try await dbQueue.read { db in
            try campRequest(filter: filter).fetchAll(db)
        }
        try await ensureMetadata(for: .camp, ids: camps.map(\.uid))
        return camps
    }

    func fetchEvents(filter: EventFilter) async throws -> [EventObjectOccurrence] {
        let events = try await dbQueue.read { db in
            try eventObjectOccurrences(filter: filter, db: db)
        }
        try await ensureMetadata(for: .event, ids: events.map { $0.event.uid })
        return events
    }

    // MARK: - Filtered Observation Helpers

    private func observe<T>(
        type: DataObjectType?,
        ids: @escaping ([T]) -> [String],
        value: @escaping @Sendable (Database) throws -> [T],
        onChange: @escaping ([T]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        let observation = ValueObservation.tracking(value)
        let cancellable = observation.start(
            in: dbQueue,
            onError: onError,
            onChange: { [weak self] values in
                if let type = type {
                    let identifiers = ids(values)
                    if !identifiers.isEmpty {
                        Task {
                            try? await self?.ensureMetadata(for: type, ids: identifiers)
                        }
                    }
                }
                onChange(values)
            }
        )
        return PlayaDBObservationToken(cancellable)
    }

    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ArtObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observe(
            type: .art,
            ids: { $0.map(\.uid) },
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
        onChange: @escaping ([CampObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observe(
            type: .camp,
            ids: { $0.map(\.uid) },
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
        onChange: @escaping ([EventObjectOccurrence]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observe(
            type: .event,
            ids: { $0.map { $0.event.uid } },
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
        onChange: @escaping ([MutantVehicleObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken {
        observe(
            type: .mutantVehicle,
            ids: { $0.map(\.uid) },
            value: { [weak self, filter] db in
                guard let self else { return [] }
                return try self.mutantVehicleRequest(filter: filter).fetchAll(db)
            },
            onChange: onChange,
            onError: onError
        )
    }

    // MARK: - Metadata Helpers

    private func ensureMetadata(for type: DataObjectType, ids: [String]) async throws {
        let uniqueIds = Set(ids)
        guard !uniqueIds.isEmpty else { return }

        try await dbQueue.write { db in
            let existingIds = try Set(
                String.fetchAll(
                    db,
                    ObjectMetadata
                        .select(ObjectMetadata.Columns.objectId)
                        .filter(ObjectMetadata.Columns.objectType == type.rawValue)
                        .filter(uniqueIds.contains(ObjectMetadata.Columns.objectId))
                )
            )

            let missingIds = uniqueIds.subtracting(existingIds)
            guard !missingIds.isEmpty else { return }

            let now = Date()
            for id in missingIds {
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

    func metadata(for object: any DataObject) async throws -> ObjectMetadata {
        try await ensureMetadata(for: object.objectType, ids: [object.uid])

        return try await dbQueue.read { db in
            guard let metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == object.objectType.rawValue)
                .filter(ObjectMetadata.Columns.objectId == object.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }
            return metadata
        }
    }

    // MARK: - Metadata Operations
    
    func getFavorites() async throws -> [any DataObject] {
        return try await dbQueue.read { db in
            var objects: [any DataObject] = []
            
            // Get favorite metadata  
            let favoriteMetadata = try ObjectMetadata
                .filter(Column("is_favorite") == true)
                .fetchAll(db)
            
            // Fetch corresponding objects
            for metadata in favoriteMetadata {
                switch metadata.dataObjectType {
                case .art:
                    if let artObject = try ArtObject.filter(Column("uid") == metadata.objectId).fetchOne(db) {
                        objects.append(artObject)
                    }
                case .camp:
                    if let campObject = try CampObject.filter(Column("uid") == metadata.objectId).fetchOne(db) {
                        objects.append(campObject)
                    }
                case .event:
                    if let eventObject = try EventObject.filter(Column("uid") == metadata.objectId).fetchOne(db) {
                        objects.append(eventObject)
                    }
                case .mutantVehicle:
                    if let mvObject = try MutantVehicleObject.filter(Column("uid") == metadata.objectId).fetchOne(db) {
                        objects.append(mvObject)
                    }
                case .none:
                    continue
                }
            }
            
            return objects
        }
    }
    
    func toggleFavorite(_ object: any DataObject) async throws {
        try await dbQueue.write { db in
            let objectType = object.objectType.rawValue
            let objectId = object.uid

            let existingMetadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == objectType)
                .filter(ObjectMetadata.Columns.objectId == objectId)
                .fetchOne(db)

            if var metadata = existingMetadata {
                metadata.isFavorite = !metadata.isFavorite
                metadata.updatedAt = Date()
                try metadata.update(db)
            } else {
                var newMetadata = ObjectMetadata(
                    objectType: objectType,
                    objectId: objectId,
                    isFavorite: true
                )
                try newMetadata.insert(db)
            }
        }
    }

    func setFavorite(_ isFavorite: Bool, for object: any DataObject) async throws {
        try await dbQueue.write { db in
            let objectType = object.objectType.rawValue
            let objectId = object.uid

            let existingMetadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == objectType)
                .filter(ObjectMetadata.Columns.objectId == objectId)
                .fetchOne(db)

            if var metadata = existingMetadata {
                guard metadata.isFavorite != isFavorite else { return }
                metadata.isFavorite = isFavorite
                metadata.updatedAt = Date()
                try metadata.update(db)
            } else {
                var newMetadata = ObjectMetadata(
                    objectType: objectType,
                    objectId: objectId,
                    isFavorite: isFavorite
                )
                try newMetadata.insert(db)
            }
        }
    }

    func isFavorite(_ object: any DataObject) async throws -> Bool {
        try await dbQueue.read { db in
            let objectType = object.objectType.rawValue
            let objectId = object.uid

            let metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == objectType)
                .filter(ObjectMetadata.Columns.objectId == objectId)
                .fetchOne(db)

            return metadata?.isFavorite ?? false
        }
    }

    func setUserNotes(_ notes: String?, for object: any DataObject) async throws {
        try await ensureMetadata(for: object.objectType, ids: [object.uid])

        try await dbQueue.write { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == object.objectType.rawValue)
                .filter(ObjectMetadata.Columns.objectId == object.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }

            let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata.userNotes = (trimmed?.isEmpty == true) ? nil : trimmed
            metadata.updatedAt = Date()
            try metadata.update(db)
        }
    }

    func setLastViewed(_ date: Date, for object: any DataObject) async throws {
        try await ensureMetadata(for: object.objectType, ids: [object.uid])

        try await dbQueue.write { db in
            guard var metadata = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == object.objectType.rawValue)
                .filter(ObjectMetadata.Columns.objectId == object.uid)
                .fetchOne(db) else {
                throw PlayaDBError.metadataNotFound
            }

            metadata.lastViewed = date
            metadata.updatedAt = Date()
            try metadata.update(db)
        }
    }
    
    // MARK: - Data Import
    
    func importFromPlayaAPI() async throws {
        // Load data from bundles and parse
        let artData = try BundleDataLoader.loadArt()
        let campData = try BundleDataLoader.loadCamps()
        let eventData = try BundleDataLoader.loadEvents()
        
        try await importFromData(artData: artData, campData: campData, eventData: eventData)
    }
    
    func importFromData(artData: Data, campData: Data, eventData: Data, mvData: Data?) async throws {
        let apiParser = APIParserFactory.create()
        
        try await dbQueue.write { db in
            // Step 1: Import art objects first
            let apiArtObjects = try apiParser.parseArt(from: artData)
            
            // Clear existing art data
            try ArtImage.deleteAll(db)
            try ArtObject.deleteAll(db)
            
            for apiArt in apiArtObjects {
                var artObject = try self.convertArtObject(from: apiArt)
                try artObject.insert(db)
                
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
            
            for apiCamp in apiCampObjects {
                var campObject = try self.convertCampObject(from: apiCamp)
                try campObject.insert(db)
                
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
            
            for apiEvent in apiEventObjects {
                // Skip duplicate events (keep first occurrence)
                if processedEventUIDs.contains(apiEvent.uid.value) {
                    print("Warning: Skipping duplicate event UID: \(apiEvent.uid.value)")
                    
                    // Still add the occurrences for this duplicate event
                    for apiOccurrence in apiEvent.occurrenceSet {
                        var eventOccurrence = EventOccurrence(
                            id: nil,
                            eventId: apiEvent.uid.value,
                            startTime: apiOccurrence.startTime,
                            endTime: apiOccurrence.endTime
                        )
                        try eventOccurrence.insert(db)
                    }
                    continue
                }
                processedEventUIDs.insert(apiEvent.uid.value)
                
                var eventObject = try self.convertEventObject(from: apiEvent)
                
                // Resolve camp relationship and copy GPS coordinates
                if let campId = apiEvent.hostedByCamp?.value {
                    if let campObject = try CampObject.fetchOne(db, key: campId) {
                        eventObject.gpsLatitude = campObject.gpsLatitude
                        eventObject.gpsLongitude = campObject.gpsLongitude
                    }
                }
                
                // Resolve art relationship and copy GPS coordinates
                if let artId = apiEvent.locatedAtArt?.value {
                    if let artObject = try ArtObject.fetchOne(db, key: artId) {
                        eventObject.gpsLatitude = artObject.gpsLatitude
                        eventObject.gpsLongitude = artObject.gpsLongitude
                    }
                }
                
                try eventObject.insert(db)
                
                // Insert event occurrences
                for apiOccurrence in apiEvent.occurrenceSet {
                    var eventOccurrence = EventOccurrence(
                        id: nil,
                        eventId: apiEvent.uid.value,
                        startTime: apiOccurrence.startTime,
                        endTime: apiOccurrence.endTime
                    )
                    try eventOccurrence.insert(db)
                }
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

            // Step 4: Rebuild FTS indexes (in case triggers weren't created yet)
            try db.execute(sql: "INSERT INTO art_objects_fts(art_objects_fts) VALUES('rebuild')")
            try db.execute(sql: "INSERT INTO camp_objects_fts(camp_objects_fts) VALUES('rebuild')")
            try db.execute(sql: "INSERT INTO event_objects_fts(event_objects_fts) VALUES('rebuild')")
            if mvData != nil {
                try db.execute(sql: "INSERT INTO mv_objects_fts(mv_objects_fts) VALUES('rebuild')")
            }
            
            // Step 4b: Rebuild spatial index
            // Clear existing spatial data
            try db.execute(sql: "DELETE FROM spatial_index")
            try db.execute(sql: "DELETE FROM spatial_objects")
            
            // Re-insert all objects with GPS coordinates
            let spatialArt = try ArtObject.filter(Column("gps_latitude") != nil).fetchAll(db)
            for art in spatialArt {
                if let lat = art.gpsLatitude, let lon = art.gpsLongitude {
                    try db.execute(sql: "INSERT INTO spatial_objects (object_type, object_uid) VALUES (?, ?)", 
                                  arguments: ["art", art.uid])
                    let spatialId = db.lastInsertedRowID
                    try db.execute(sql: "INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon) VALUES (?, ?, ?, ?, ?)",
                                  arguments: [spatialId, lat, lat, lon, lon])
                }
            }
            
            let spatialCamps = try CampObject.filter(Column("gps_latitude") != nil).fetchAll(db)
            for camp in spatialCamps {
                if let lat = camp.gpsLatitude, let lon = camp.gpsLongitude {
                    try db.execute(sql: "INSERT INTO spatial_objects (object_type, object_uid) VALUES (?, ?)", 
                                  arguments: ["camp", camp.uid])
                    let spatialId = db.lastInsertedRowID
                    try db.execute(sql: "INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon) VALUES (?, ?, ?, ?, ?)",
                                  arguments: [spatialId, lat, lat, lon, lon])
                }
            }
            
            let spatialEvents = try EventObject.filter(Column("gps_latitude") != nil).fetchAll(db)
            for event in spatialEvents {
                if let lat = event.gpsLatitude, let lon = event.gpsLongitude {
                    try db.execute(sql: "INSERT INTO spatial_objects (object_type, object_uid) VALUES (?, ?)", 
                                  arguments: ["event", event.uid])
                    let spatialId = db.lastInsertedRowID
                    try db.execute(sql: "INSERT INTO spatial_index (id, minLat, maxLat, minLon, maxLon) VALUES (?, ?, ?, ?, ?)",
                                  arguments: [spatialId, lat, lat, lon, lon])
                }
            }
            
            // Step 5: Update import info
            let now = Date()
            
            var artUpdateInfo = UpdateInfo(
                dataType: DataObjectType.art.rawValue,
                lastUpdated: now,
                version: nil,
                totalCount: apiArtObjects.count,
                createdAt: now
            )
            try artUpdateInfo.insert(db)
            
            var campUpdateInfo = UpdateInfo(
                dataType: DataObjectType.camp.rawValue,
                lastUpdated: now,
                version: nil,
                totalCount: apiCampObjects.count,
                createdAt: now
            )
            try campUpdateInfo.insert(db)
            
            var eventUpdateInfo = UpdateInfo(
                dataType: DataObjectType.event.rawValue,
                lastUpdated: now,
                version: nil,
                totalCount: apiEventObjects.count,
                createdAt: now
            )
            try eventUpdateInfo.insert(db)

            if mvData != nil {
                var mvUpdateInfo = UpdateInfo(
                    dataType: DataObjectType.mutantVehicle.rawValue,
                    lastUpdated: now,
                    version: nil,
                    totalCount: mvCount,
                    createdAt: now
                )
                try mvUpdateInfo.insert(db)
            }
        }
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
            selfGuidedTourMap: apiArt.selfGuidedTourMap
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
    
    // MARK: - Reactive Data Access
    
    private var _allArt: [ArtObject] = []
    private var _allCamps: [CampObject] = []
    private var _allEvents: [EventObjectOccurrence] = []
    private var _allMutantVehicles: [MutantVehicleObject] = []
    private var _favorites: [ObjectMetadata] = []
    
    private var observations: [DatabaseCancellable] = []
    
    var allArt: [ArtObject] {
        _allArt
    }
    
    var allCamps: [CampObject] {
        _allCamps
    }
    
    var allEvents: [EventObjectOccurrence] {
        _allEvents
    }

    var allMutantVehicles: [MutantVehicleObject] {
        _allMutantVehicles
    }
    
    var favorites: [ObjectMetadata] {
        _favorites
    }
    
    private func setupObservations() {
        // Observe art objects
        let artObservation = ValueObservation.tracking { db in
            try ArtObject.fetchAll(db)
        }
        let artCancellable = artObservation.start(
            in: dbQueue,
            onError: { error in
                print("Error observing art objects: \(error)")
            },
            onChange: { [weak self] artObjects in
                if !artObjects.isEmpty {
                    Task {
                        try? await self?.ensureMetadata(for: .art, ids: artObjects.map(\.uid))
                    }
                }
                self?._allArt = artObjects
            }
        )
        
        // Observe camp objects
        let campObservation = ValueObservation.tracking { db in
            try CampObject.fetchAll(db)
        }
        let campCancellable = campObservation.start(
            in: dbQueue,
            onError: { error in
                print("Error observing camp objects: \(error)")
            },
            onChange: { [weak self] campObjects in
                if !campObjects.isEmpty {
                    Task {
                        try? await self?.ensureMetadata(for: .camp, ids: campObjects.map(\.uid))
                    }
                }
                self?._allCamps = campObjects
            }
        )
        
        // Observe event objects with occurrences
        let eventObservation = ValueObservation.tracking { db in
            let events = try EventObject.including(all: EventObject.occurrences).fetchAll(db)
            var eventObjectOccurrences: [EventObjectOccurrence] = []
            for event in events {
                let occurrences = try event.occurrences.fetchAll(db)
                for occurrence in occurrences {
                    eventObjectOccurrences.append(EventObjectOccurrence(event: event, occurrence: occurrence))
                }
            }
            return eventObjectOccurrences
        }
        let eventCancellable = eventObservation.start(
            in: dbQueue,
            onError: { error in
                print("Error observing events: \(error)")
            },
            onChange: { [weak self] eventObjectOccurrences in
                if !eventObjectOccurrences.isEmpty {
                    Task {
                        try? await self?.ensureMetadata(for: .event, ids: eventObjectOccurrences.map { $0.event.uid })
                    }
                }
                self?._allEvents = eventObjectOccurrences
            }
        )
        
        // Observe mutant vehicle objects
        let mvObservation = ValueObservation.tracking { db in
            try MutantVehicleObject.fetchAll(db)
        }
        let mvCancellable = mvObservation.start(
            in: dbQueue,
            onError: { error in
                print("Error observing mutant vehicles: \(error)")
            },
            onChange: { [weak self] mvObjects in
                if !mvObjects.isEmpty {
                    Task {
                        try? await self?.ensureMetadata(for: .mutantVehicle, ids: mvObjects.map(\.uid))
                    }
                }
                self?._allMutantVehicles = mvObjects
            }
        )

        // Observe favorites
        let favoritesObservation = ValueObservation.tracking { db in
            try ObjectMetadata.filter(Column("is_favorite") == true).fetchAll(db)
        }
        let favoritesCancellable = favoritesObservation.start(
            in: dbQueue,
            onError: { error in
                print("Error observing favorites: \(error)")
            },
            onChange: { [weak self] favoriteMetadata in
                self?._favorites = favoriteMetadata
            }
        )
        
        // Store cancellables
        observations = [
            artCancellable,
            campCancellable,
            eventCancellable,
            mvCancellable,
            favoritesCancellable
        ]
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
