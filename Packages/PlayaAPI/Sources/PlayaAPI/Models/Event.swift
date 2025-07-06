import Foundation

/// Represents an event from the Burning Man API
public struct Event: Codable, Hashable, Sendable {
    public let uid: EventID
    public let title: String
    public let eventId: Int?
    public let description: String?
    public let eventType: EventTypeInfo?
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
        eventType: EventTypeInfo? = nil,
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
            .filter { $0.startTime != nil && $0.startTime! > now }
            .min { ($0.startTime ?? Date.distantFuture) < ($1.startTime ?? Date.distantFuture) }
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
