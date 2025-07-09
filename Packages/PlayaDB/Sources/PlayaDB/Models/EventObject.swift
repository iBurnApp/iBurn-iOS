import Foundation
import CoreLocation
import SharingGRDB

/// Event object with complete API field mapping
@Table("event_objects")
public struct EventObject: DataObject {
    // MARK: - Primary Data (from PlayaAPI.Event)
    
    /// Unique identifier (auto-mapped to uid column)
    public var uid: String
    
    /// Event title (auto-mapped to name column) - using title as name for DataObject protocol
    public var name: String
    
    /// Year of the event (auto-mapped to year column)
    public var year: Int
    
    /// Event ID (auto-mapped to event_id column)
    public var eventId: Int?
    
    /// Description of the event (auto-mapped to description column)
    public var description: String?
    
    /// Event type label (auto-mapped to event_type_label column)
    public var eventTypeLabel: String
    
    /// Event type code (auto-mapped to event_type_code column)
    public var eventTypeCode: String
    
    /// Print description (auto-mapped to print_description column)
    public var printDescription: String
    
    /// URL slug (auto-mapped to slug column)
    public var slug: String?
    
    /// Hosted by camp ID (auto-mapped to hosted_by_camp column)
    public var hostedByCamp: String?
    
    /// Located at art ID (auto-mapped to located_at_art column)
    public var locatedAtArt: String?
    
    /// Other location string (auto-mapped to other_location column)
    public var otherLocation: String
    
    /// Check location flag (auto-mapped to check_location column)
    public var checkLocation: Bool
    
    /// Website URL (auto-mapped to url column)
    public var url: URL?
    
    /// All day event flag (auto-mapped to all_day column)
    public var allDay: Bool
    
    /// Contact information (auto-mapped to contact column)
    public var contact: String?
    
    // MARK: - GPS Coordinates (copied from host camp/art during import)
    
    /// GPS latitude (auto-mapped to gps_latitude column)
    public var gpsLatitude: Double?
    
    /// GPS longitude (auto-mapped to gps_longitude column)
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
    /// Whether this event has any scheduled occurrences
    var hasOccurrences: Bool {
        !occurrences.isEmpty
    }
    
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
    
    /// The next occurrence of this event (if any)
    func nextOccurrence(_ now: Date = Date()) -> EventOccurrence? {
        return occurrences
            .filter { $0.startTime > now }
            .min { $0.startTime < $1.startTime }
    }
    
    /// The current occurrence of this event (if any)
    func currentOccurrence(_ now: Date = Date()) -> EventOccurrence? {
        occurrences.first { $0.isCurrentlyHappening(now) }
    }
    
    /// Whether this event is currently happening
    func isCurrentlyHappening(_ now: Date = Date()) -> Bool {
        currentOccurrence(now) != nil
    }
}

// MARK: - Relationships

public extension EventObject {
    /// Associated occurrences (would be populated via relationship)
    var occurrences: [EventOccurrence] {
        // This would be populated by the database layer
        // For now, return empty array
        []
    }
}

/// Event occurrence model
@Table("event_occurrences")
public struct EventOccurrence {
    /// Auto-incremented ID (auto-mapped to id column)
    public var id: Int64?
    
    /// Reference to parent event object (auto-mapped to event_id column)
    public var eventId: String
    
    /// Start time of the occurrence (auto-mapped to start_time column)
    public var startTime: Date
    
    /// End time of the occurrence (auto-mapped to end_time column)
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