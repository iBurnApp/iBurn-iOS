import Foundation
import CoreLocation

/// Composite object that combines an EventObject with a specific EventOccurrence
/// This provides backward compatibility with existing code that expects individual event objects with start/end dates
public struct EventObjectOccurrence: DataObject {
    // MARK: - Component Objects
    
    /// The base event data
    public let event: EventObject
    
    /// The specific occurrence/timing data
    public let occurrence: EventOccurrence
    
    // MARK: - Initialization
    
    public init(event: EventObject, occurrence: EventOccurrence) {
        self.event = event
        self.occurrence = occurrence
    }
    
    // MARK: - DataObject Protocol Conformance
    
    /// Synthesized unique ID for this specific occurrence
    public var uid: String {
        "\(event.uid)_\(occurrence.id ?? 0)"
    }
    
    /// Event name from the base event
    public var name: String {
        event.name
    }
    
    /// Year from the base event
    public var year: Int {
        event.year
    }
    
    /// Description from the base event
    public var description: String? {
        event.description
    }
    
    /// Location from the base event (GPS coordinates)
    public var location: CLLocation? {
        event.location
    }
    
    /// Whether this event has location information
    public var hasLocation: Bool {
        event.hasLocation
    }
    
    /// Object type is always event
    public var objectType: DataObjectType {
        .event
    }
    
    // MARK: - Timing Properties (from EventOccurrence)
    
    /// Start date/time for this specific occurrence
    public var startDate: Date {
        occurrence.startTime
    }
    
    /// End date/time for this specific occurrence
    public var endDate: Date {
        occurrence.endTime
    }
    
    // MARK: - Event Properties (from EventObject)
    
    /// Event ID
    public var eventId: Int? {
        event.eventId
    }
    
    /// Event type label
    public var eventTypeLabel: String {
        event.eventTypeLabel
    }
    
    /// Event type code
    public var eventTypeCode: String {
        event.eventTypeCode
    }
    
    /// Print description
    public var printDescription: String {
        event.printDescription
    }
    
    /// URL slug
    public var slug: String? {
        event.slug
    }
    
    /// Hosted by camp ID
    public var hostedByCamp: String? {
        event.hostedByCamp
    }
    
    /// Located at art ID
    public var locatedAtArt: String? {
        event.locatedAtArt
    }
    
    /// Other location string
    public var otherLocation: String {
        event.otherLocation
    }
    
    /// Check location flag
    public var checkLocation: Bool {
        event.checkLocation
    }
    
    /// Website URL
    public var url: URL? {
        event.url
    }
    
    /// All day event flag
    public var allDay: Bool {
        event.allDay
    }
    
    /// Contact information
    public var contact: String? {
        event.contact
    }
    
    /// GPS latitude
    public var gpsLatitude: Double? {
        event.gpsLatitude
    }
    
    /// GPS longitude
    public var gpsLongitude: Double? {
        event.gpsLongitude
    }
}

// MARK: - Computed Properties

public extension EventObjectOccurrence {
    /// Whether this event has contact information
    var hasContact: Bool {
        event.hasContact
    }
    
    /// Whether this event has a slug
    var hasSlug: Bool {
        event.hasSlug
    }
    
    /// Whether this event is hosted by a camp
    var isHostedByCamp: Bool {
        event.isHostedByCamp
    }
    
    /// Whether this event is located at an art installation
    var isLocatedAtArt: Bool {
        event.isLocatedAtArt
    }
    
    /// Whether this event has other location information
    var hasOtherLocation: Bool {
        event.hasOtherLocation
    }
    
    /// Whether this event has GPS coordinates
    var hasGPSLocation: Bool {
        event.hasGPSLocation
    }
    
    /// Whether this event has a print description
    var hasPrintDescription: Bool {
        event.hasPrintDescription
    }
    
    /// Primary location string for display
    var primaryLocationString: String? {
        event.primaryLocationString
    }
    
    /// Duration of this specific occurrence in seconds
    var duration: TimeInterval {
        occurrence.duration
    }
    
    /// Whether this specific occurrence is currently happening
    func isCurrentlyHappening(_ now: Date = Date()) -> Bool {
        occurrence.isCurrentlyHappening(now)
    }
    
    /// Whether this specific occurrence has already ended
    func hasEnded(_ now: Date = Date()) -> Bool {
        occurrence.hasEnded(now)
    }
    
    /// Whether this specific occurrence is in the future
    func isFuture(_ now: Date = Date()) -> Bool {
        occurrence.isFuture(now)
    }
    
    /// Duration as a formatted string
    var durationString: String {
        occurrence.durationString
    }
    
    /// Whether this is a short event (less than 1 hour)
    var isShortEvent: Bool {
        occurrence.isShortEvent
    }
    
    /// Whether this is a long event (more than 4 hours)
    var isLongEvent: Bool {
        occurrence.isLongEvent
    }
}

// MARK: - Compatibility Methods

public extension EventObjectOccurrence {
    /// Time interval until this occurrence starts
    func timeIntervalUntilStart(_ currentDate: Date = Date()) -> TimeInterval {
        startDate.timeIntervalSince(currentDate)
    }
    
    /// Time interval until this occurrence ends
    func timeIntervalUntilEnd(_ currentDate: Date = Date()) -> TimeInterval {
        endDate.timeIntervalSince(currentDate)
    }
    
    /// Duration of this occurrence
    func timeIntervalForDuration() -> TimeInterval {
        duration
    }
    
    /// Whether this occurrence is happening right now
    func isHappeningRightNow(_ currentDate: Date = Date()) -> Bool {
        isCurrentlyHappening(currentDate)
    }
    
    /// Whether this occurrence ends in the next 15 minutes
    func isEndingSoon(_ currentDate: Date = Date()) -> Bool {
        let endingSoonThreshold: TimeInterval = 15 * 60 // 15 minutes
        let timeUntilEnd = timeIntervalUntilEnd(currentDate)
        return timeUntilEnd > 0 && timeUntilEnd <= endingSoonThreshold
    }
    
    /// Whether this occurrence starts in the next 30 minutes
    func isStartingSoon(_ currentDate: Date = Date()) -> Bool {
        let startingSoonThreshold: TimeInterval = 30 * 60 // 30 minutes
        let timeUntilStart = timeIntervalUntilStart(currentDate)
        return timeUntilStart > 0 && timeUntilStart <= startingSoonThreshold
    }
    
    /// Whether this occurrence should show up on the main map screen
    func shouldShowOnMap(_ now: Date = Date()) -> Bool {
        // Show events starting soon or happening now, but not ending soon
        return !hasEnded(now) && (isStartingSoon(now) || isHappeningRightNow(now)) && !isEndingSoon(now)
    }
    
    /// Format start and end time as string (e.g. "10:00AM - 4:00PM")
    var startAndEndString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    /// Format start date as weekday string
    var startWeekdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: startDate)
    }
}