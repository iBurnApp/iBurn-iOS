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

/// The knobs behind the global search filter sheet. Both apply on top of whatever
/// scope is selected; `happeningNow` is inert when the scope excludes events.
struct GlobalSearchFilter: Equatable, Codable {
    /// Restricts every type to favorited objects.
    var onlyFavorites: Bool = false

    /// Events only: keeps occurrences that are running right now.
    var happeningNow: Bool = false

    var isDefault: Bool { self == GlobalSearchFilter() }
}
