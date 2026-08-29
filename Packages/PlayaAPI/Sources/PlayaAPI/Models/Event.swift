import Foundation

/// Represents an event from the Burning Man API
public struct Event: Codable, Hashable, Sendable {
    public let uid: EventID
    public let title: String
    public let eventId: Int?
    public let description: String?
    public let eventType: EventTypeInfo
    public let year: Int
    public let printDescription: String
    public let slug: String?
    public let hostedByCamp: CampID?
    public let locatedAtArt: ArtID?
    public let otherLocation: String
    public let checkLocation: Bool
    public let url: URL?
    public let allDay: Bool
    public let contact: String?
    public let occurrenceSet: [EventOccurrence]
    
    public init(
        uid: EventID,
        title: String,
        eventId: Int? = nil,
        description: String? = nil,
        eventType: EventTypeInfo,
        year: Int,
        printDescription: String = "",
        slug: String? = nil,
        hostedByCamp: CampID? = nil,
        locatedAtArt: ArtID? = nil,
        otherLocation: String = "",
        checkLocation: Bool = false,
        url: URL? = nil,
        allDay: Bool = false,
        contact: String? = nil,
        occurrenceSet: [EventOccurrence] = []
    ) {
        self.uid = uid
        self.title = title
        self.eventId = eventId
        self.description = description
        self.eventType = eventType
        self.year = year
        self.printDescription = printDescription
        self.slug = slug
        self.hostedByCamp = hostedByCamp
        self.locatedAtArt = locatedAtArt
        self.otherLocation = otherLocation
        self.checkLocation = checkLocation
        self.url = url
        self.allDay = allDay
        self.contact = contact
        self.occurrenceSet = occurrenceSet
    }

    // Custom decoding: `url` is user-entered free text and is salvaged leniently rather
    // than decoded strictly (see `LenientURL`). Encoding stays synthesized/unchanged.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decode(EventID.self, forKey: .uid)
        title = try container.decode(String.self, forKey: .title)
        eventId = try container.decodeIfPresent(Int.self, forKey: .eventId)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        eventType = try container.decode(EventTypeInfo.self, forKey: .eventType)
        year = try container.decode(Int.self, forKey: .year)
        printDescription = try container.decode(String.self, forKey: .printDescription)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        hostedByCamp = try container.decodeIfPresent(CampID.self, forKey: .hostedByCamp)
        locatedAtArt = try container.decodeIfPresent(ArtID.self, forKey: .locatedAtArt)
        otherLocation = try container.decode(String.self, forKey: .otherLocation)
        checkLocation = try container.decode(Bool.self, forKey: .checkLocation)
        url = try container.decodeLenientURLIfPresent(forKey: .url)
        allDay = try container.decode(Bool.self, forKey: .allDay)
        contact = try container.decodeIfPresent(String.self, forKey: .contact)
        occurrenceSet = try container.decode([EventOccurrence].self, forKey: .occurrenceSet)
    }
}

// MARK: - Computed Properties

public extension Event {
    /// Whether this event has any scheduled occurrences
    var hasOccurrences: Bool {
        !occurrenceSet.isEmpty
    }
    
    /// Whether this event has location information
    var hasLocation: Bool {
        hostedByCamp != nil || locatedAtArt != nil || !otherLocation.isEmpty
    }
    
    /// Whether this event has contact information
    var hasContact: Bool {
        contact != nil || url != nil
    }
    
    /// Whether this event has a description
    var hasDescription: Bool {
        description != nil && !description!.isEmpty
    }
    
    /// The next occurrence of this event (if any)
    func nextOccurrence(_ now: Date = Date()) -> EventOccurrence? {
        return occurrenceSet
            .filter { $0.startTime > now }
            .min { $0.startTime < $1.startTime }
    }
    
    /// The current occurrence of this event (if any)
    func currentOccurrence(_ now: Date = Date()) -> EventOccurrence? {
        occurrenceSet.first { $0.isCurrentlyHappening(now) }
    }
    
    /// Whether this event is currently happening
    func isCurrentlyHappening(_ now: Date = Date()) -> Bool {
        currentOccurrence(now) != nil
    }
}
