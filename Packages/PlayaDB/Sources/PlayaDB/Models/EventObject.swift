import Foundation
import CoreLocation
import GRDB

/// Event object with complete API field mapping
public struct EventObject: DataObject, Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "event_objects"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case uid
        case name
        case year
        case eventId = "event_id"
        case description
        case eventTypeLabel = "event_type_label"
        case eventTypeCode = "event_type_code"
        case printDescription = "print_description"
        case slug
        case hostedByCamp = "hosted_by_camp"
        case locatedAtArt = "located_at_art"
        case otherLocation = "other_location"
        case checkLocation = "check_location"
        case url
        case allDay = "all_day"
        case contact
        case gpsLatitude = "gps_latitude"
        case gpsLongitude = "gps_longitude"
    }
    
    // MARK: - Primary Data (from PlayaAPI.Event)
    
    /// Unique identifier
    public var uid: String
    
    /// Event title - using title as name for DataObject protocol
    public var name: String
    
    /// Year of the event
    public var year: Int
    
    /// Event ID
    public var eventId: Int?
    
    /// Description of the event
    public var description: String?
    
    /// Event type label
    public var eventTypeLabel: String
    
    /// Event type code
    public var eventTypeCode: String
    
    /// Print description
    public var printDescription: String
    
    /// URL slug
    public var slug: String?
    
    /// Hosted by camp ID
    public var hostedByCamp: String?
    
    /// Located at art ID
    public var locatedAtArt: String?
    
    /// Other location string
    public var otherLocation: String
    
    /// Check location flag
    public var checkLocation: Bool
    
    /// Website URL
    public var url: URL?
    
    /// All day event flag
    public var allDay: Bool
    
    /// Contact information
    public var contact: String?
    
    // MARK: - GPS Coordinates (copied from host camp/art during import)
    
    /// GPS latitude
    public var gpsLatitude: Double?
    
    /// GPS longitude
    public var gpsLongitude: Double?
    
    public init(
        uid: String,
        name: String,
        year: Int,
        eventId: Int? = nil,
        description: String? = nil,
        eventTypeLabel: String,
        eventTypeCode: String,
        printDescription: String = "",
        slug: String? = nil,
        hostedByCamp: String? = nil,
        locatedAtArt: String? = nil,
        otherLocation: String = "",
        checkLocation: Bool = false,
        url: URL? = nil,
        allDay: Bool = false,
        contact: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.uid = uid
        self.name = name
        self.year = year
        self.eventId = eventId
        self.description = description
        self.eventTypeLabel = eventTypeLabel
        self.eventTypeCode = eventTypeCode
        self.printDescription = printDescription
        self.slug = slug
        self.hostedByCamp = hostedByCamp
        self.locatedAtArt = locatedAtArt
        self.otherLocation = otherLocation
        self.checkLocation = checkLocation
        self.url = url
        self.allDay = allDay
        self.contact = contact
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}

// MARK: - DataObject Protocol Conformance

public extension EventObject {
    /// DataObject type
    var objectType: DataObjectType { .event }
    
    /// Geographic location from GPS coordinates (copied from host camp/art during import)
    var location: CLLocation? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    /// Whether this event has location information
    var hasLocation: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
}

// MARK: - Computed Properties

public extension EventObject {
    /// Whether this event has contact information
    var hasContact: Bool {
        contact != nil || url != nil
    }
    
    /// Whether this event has a slug
    var hasSlug: Bool {
        slug != nil && !slug!.isEmpty
    }
    
    /// Whether this event is hosted by a camp
    var isHostedByCamp: Bool {
        hostedByCamp != nil
    }
    
    /// Whether this event is located at an art installation
    var isLocatedAtArt: Bool {
        locatedAtArt != nil
    }
    
    /// Whether this event has other location information
    var hasOtherLocation: Bool {
        !otherLocation.isEmpty
    }
    
    /// Whether this event has GPS coordinates
    var hasGPSLocation: Bool {
        location != nil
    }
    
    /// Whether this event has a print description
    var hasPrintDescription: Bool {
        !printDescription.isEmpty
    }
    
    /// Primary location string for display
    var primaryLocationString: String? {
        if isHostedByCamp {
            return "Hosted by Camp" // Would resolve camp name through PlayaDB
        } else if isLocatedAtArt {
            return "Located at Art" // Would resolve art name through PlayaDB
        } else if hasOtherLocation {
            return otherLocation
        }
        return nil
    }
}

// MARK: - GRDB Relationships

public extension EventObject {
    /// Define relationship to event occurrences
    static let occurrences = hasMany(EventOccurrence.self, using: ForeignKey(["event_id"]))
    
    /// Associated occurrences request
    var occurrences: QueryInterfaceRequest<EventOccurrence> {
        request(for: EventObject.occurrences)
    }
}

/// Event occurrence model
public struct EventOccurrence: Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "event_occurrences"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case eventId = "event_id"
        case startTime = "start_time"
        case endTime = "end_time"
    }
    /// Auto-incremented ID
    public var id: Int64?
    
    /// Reference to parent event object
    public var eventId: String
    
    /// Start time of the occurrence
    public var startTime: Date
    
    /// End time of the occurrence
    public var endTime: Date
    
    public init(
        id: Int64? = nil,
        eventId: String,
        startTime: Date,
        endTime: Date
    ) {
        self.id = id
        self.eventId = eventId
        self.startTime = startTime
        self.endTime = endTime
    }
    
    // Update id after insertion
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

// MARK: - Computed Properties

public extension EventOccurrence {
    /// Duration of the event occurrence in seconds
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Whether the event occurrence is currently happening
    func isCurrentlyHappening(_ now: Date = Date()) -> Bool {
        return now >= startTime && now <= endTime
    }
    
    /// Whether the event occurrence has already ended
    func hasEnded(_ now: Date = Date()) -> Bool {
        return now > endTime
    }
    
    /// Whether the event occurrence is in the future
    func isFuture(_ now: Date = Date()) -> Bool {
        return now < startTime
    }
    
    /// Duration as a formatted string
    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
    
    /// Whether this is a short event (less than 1 hour)
    var isShortEvent: Bool {
        duration < 3600
    }
    
    /// Whether this is a long event (more than 4 hours)
    var isLongEvent: Bool {
        duration > 14400
    }
}

// MARK: - GRDB Relationships for EventOccurrence

public extension EventOccurrence {
    /// Define relationship to parent event
    static let event = belongsTo(EventObject.self, using: ForeignKey(["event_id"]))
    
    /// Associated event request
    var event: QueryInterfaceRequest<EventObject> {
        request(for: EventOccurrence.event)
    }
}