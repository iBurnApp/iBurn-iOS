import Foundation
import PlayaDB

/// Data-type scope for the global search screen. Scoping narrows which tables are
/// queried at all, so a scoped search is also cheaper than an unscoped one.
enum GlobalSearchScope: String, CaseIterable, Identifiable, Codable {
    case all
    case art
    case camps
    case events
    case vehicles

    var id: String { rawValue }

    /// Segmented-control label. Kept short so five segments fit on a small phone.
    var title: String {
        switch self {
        case .all: "All"
        case .art: "Art"
        case .camps: "Camps"
        case .events: "Events"
        case .vehicles: "Vehicles"
        }
    }

    /// Plural noun for messages ("No events match…").
    var resultNoun: String {
        switch self {
        case .all: "results"
        case .art: "art"
        case .camps: "camps"
        case .events: "events"
        case .vehicles: "mutant vehicles"
        }
    }

    func allows(_ type: DataObjectType) -> Bool {
        switch self {
        case .all: true
        case .art: type == .art
        case .camps: type == .camp
        case .events: type == .event
        case .vehicles: type == .mutantVehicle
        }
    }
}

/// Coarse band of the day an event occurrence starts in. Bands are expressed as
/// hour-of-day so they apply the same way on every festival day, including when no
/// particular day is selected.
///
/// `lateNight` wraps midnight (22:00–05:59), so its membership test is a union of two
/// ranges rather than a single interval — see `contains(hour:)`.
enum SearchTimeOfDay: String, CaseIterable, Identifiable, Codable {
    case any
    case morning
    case afternoon
    case evening
    case lateNight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any time"
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .lateNight: "Late night"
        }
    }

    /// Human-readable clock range, for the sheet's footer.
    var rangeDescription: String? {
        switch self {
        case .any: nil
        case .morning: "6am – 12pm"
        case .afternoon: "12pm – 5pm"
        case .evening: "5pm – 10pm"
        case .lateNight: "10pm – 6am"
        }
    }

    /// Half-open start hour and end hour. `lateNight` reports `start > end` because it
    /// crosses midnight; every other band is a plain `start..<end`.
    var hourBounds: (start: Int, end: Int)? {
        switch self {
        case .any: nil
        case .morning: (6, 12)
        case .afternoon: (12, 17)
        case .evening: (17, 22)
        case .lateNight: (22, 6)
        }
    }

    /// Whether an occurrence starting at `hour` (0...23, local) falls in this band.
    func contains(hour: Int) -> Bool {
        guard let bounds = hourBounds else { return true }
        if bounds.start <= bounds.end {
            return hour >= bounds.start && hour < bounds.end
        }
        // Wraps midnight: 22, 23, 0, 1, ... 5.
        return hour >= bounds.start || hour < bounds.end
    }

    /// Whether an occurrence starting at `date` falls in this band.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard hourBounds != nil else { return true }
        return contains(hour: calendar.component(.hour, from: date))
    }
}

/// The knobs behind the global search filter sheet. All apply on top of whatever scope
/// is selected; the event-scoped ones are inert when the scope excludes events.
struct GlobalSearchFilter: Equatable, Codable {
    /// Restricts every type to favorited objects.
    var onlyFavorites: Bool = false

    /// Events only: keeps occurrences that are running right now.
    var happeningNow: Bool = false

    /// Events only: restricts to occurrences starting on this calendar day.
    /// `nil` means "any day". Threaded into `EventFilter.startDate`/`endDate`, so it
    /// narrows at the SQL level rather than in memory.
    var day: Date?

    /// Events only: coarse band of the day an occurrence starts in. Applied to
    /// occurrences before they are collapsed to one row per event.
    var timeOfDay: SearchTimeOfDay = .any

    var isDefault: Bool { self == GlobalSearchFilter() }

    /// Calendar-day bounds for `day`, as `[start, end)` — the same shape
    /// `EventFilter.forDay(_:)` produces. `nil` when no day is selected.
    var dayBounds: (start: Date, end: Date)? {
        guard let day else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case onlyFavorites, happeningNow, day, timeOfDay
    }

    init(
        onlyFavorites: Bool = false,
        happeningNow: Bool = false,
        day: Date? = nil,
        timeOfDay: SearchTimeOfDay = .any
    ) {
        self.onlyFavorites = onlyFavorites
        self.happeningNow = happeningNow
        self.day = day
        self.timeOfDay = timeOfDay
    }

    /// Decoded field-by-field with defaults so a filter persisted by an older build —
    /// which had no `day` or `timeOfDay` — still restores instead of being thrown away.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.onlyFavorites = try container.decodeIfPresent(Bool.self, forKey: .onlyFavorites) ?? false
        self.happeningNow = try container.decodeIfPresent(Bool.self, forKey: .happeningNow) ?? false
        self.day = try container.decodeIfPresent(Date.self, forKey: .day)
        self.timeOfDay = try container.decodeIfPresent(SearchTimeOfDay.self, forKey: .timeOfDay) ?? .any
    }
}
