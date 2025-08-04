import Foundation
import CoreLocation
import MapKit
import GRDB
import PlayaAPI

/// Internal implementation of PlayaDB using GRDB
internal class PlayaDBImpl: PlayaDB {
    // MARK: - Database Connection
    
    private let dbQueue: DatabaseQueue
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
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_object_metadata_favorite ON object_metadata(is_favorite)")
        }
    }
    
    // MARK: - Data Access Methods
    
    func fetchArt() async throws -> [ArtObject] {
        return try await dbQueue.read { db in
            try ArtObject.fetchAll(db)
        }
    }
    
    func fetchCamps() async throws -> [CampObject] {
        return try await dbQueue.read { db in
            try CampObject.fetchAll(db)
        }
    }
    
    func fetchEvents() async throws -> [EventObjectOccurrence] {
        return try await dbQueue.read { db in
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
        return try await dbQueue.read { db in
            var objects: [any DataObject] = []
            
            // Calculate bounding box
            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2
            
            // Fetch art objects in region
            let artObjects = try ArtObject
                .filter(Column("gps_latitude") >= minLat)
                .filter(Column("gps_latitude") <= maxLat)
                .filter(Column("gps_longitude") >= minLon)
                .filter(Column("gps_longitude") <= maxLon)
                .fetchAll(db)
            objects.append(contentsOf: artObjects)
            
            // Fetch camp objects in region
            let campObjects = try CampObject
                .filter(Column("gps_latitude") >= minLat)
                .filter(Column("gps_latitude") <= maxLat)
                .filter(Column("gps_longitude") >= minLon)
                .filter(Column("gps_longitude") <= maxLon)
                .fetchAll(db)
            objects.append(contentsOf: campObjects)
            
            // Fetch event objects in region
            let eventObjects = try EventObject
                .filter(Column("gps_latitude") >= minLat)
                .filter(Column("gps_latitude") <= maxLat)
                .filter(Column("gps_longitude") >= minLon)
                .filter(Column("gps_longitude") <= maxLon)
                .fetchAll(db)
            objects.append(contentsOf: eventObjects)
            
            return objects
        }
    }
    
    func searchObjects(_ query: String) async throws -> [any DataObject] {
        // Basic string search for now (FTS5 will be added later)
        return try await dbQueue.read { db in
            var objects: [any DataObject] = []
            let searchPattern = "%\(query)%"
            
            // Search art objects
            let artObjects = try ArtObject
                .filter(Column("name").like(searchPattern) || Column("description").like(searchPattern) || Column("artist").like(searchPattern))
                .fetchAll(db)
            objects.append(contentsOf: artObjects)
            
            // Search camp objects
            let campObjects = try CampObject
                .filter(Column("name").like(searchPattern) || Column("description").like(searchPattern) || Column("landmark").like(searchPattern))
                .fetchAll(db)
            objects.append(contentsOf: campObjects)
            
            // Search event objects
            let eventObjects = try EventObject
                .filter(Column("name").like(searchPattern) || Column("description").like(searchPattern) || Column("event_type_label").like(searchPattern))
                .fetchAll(db)
            objects.append(contentsOf: eventObjects)
            
            return objects
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
            
            // Get existing metadata
            let existingMetadata = try ObjectMetadata
                .filter(Column("object_type") == objectType && Column("object_id") == objectId)
                .fetchOne(db)
            
            if let metadata = existingMetadata {
                // Update existing metadata
                let newFavoriteStatus = !metadata.isFavorite
                let now = Date()
                var updatedMetadata = metadata
                updatedMetadata.isFavorite = newFavoriteStatus
                updatedMetadata.updatedAt = now
                try updatedMetadata.update(db)
            } else {
                // Create new metadata
                var newMetadata = ObjectMetadata(
                    objectType: objectType,
                    objectId: objectId,
                    isFavorite: true
                )
                try newMetadata.insert(db)
            }
        }
    }
    
    func isFavorite(_ object: any DataObject) async throws -> Bool {
        return try await dbQueue.read { db in
            let objectType = object.objectType.rawValue
            let objectId = object.uid
            
            let metadata = try ObjectMetadata
                .filter(Column("object_type") == objectType && Column("object_id") == objectId)
                .fetchOne(db)
            
            return metadata?.isFavorite ?? false
        }
    }
    
    // MARK: - Data Import
    
    func importFromPlayaAPI() async throws {
        let apiParser = APIParserFactory.create()
        
        // Load data from bundles and parse
        let artData = try BundleDataLoader.loadArt()
        let campData = try BundleDataLoader.loadCamps()
        let eventData = try BundleDataLoader.loadEvents()
        
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
            
            for apiEvent in apiEventObjects {
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
            
            // Step 4: Update import info
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
    
    func getUpdateInfo() async throws -> [UpdateInfo] {
        return try await dbQueue.read { db in
            try UpdateInfo.fetchAll(db)
        }
    }
    
    // MARK: - Reactive Data Access (placeholder)
    
    var allArt: [ArtObject] {
        // TODO: Implement reactive data access
        []
    }
    
    var allCamps: [CampObject] {
        // TODO: Implement reactive data access
        []
    }
    
    var allEvents: [EventObjectOccurrence] {
        // TODO: Implement reactive data access
        []
    }
    
    var favorites: [ObjectMetadata] {
        // TODO: Implement reactive data access
        []
    }
}

// MARK: - Error Types

enum PlayaDBError: Error {
    case notImplemented(String)
    case databaseError(String)
    case importError(String)
    
    var localizedDescription: String {
        switch self {
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .importError(let message):
            return "Import error: \(message)"
        }
    }
}