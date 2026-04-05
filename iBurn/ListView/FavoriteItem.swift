import CoreLocation
import PlayaDB

/// Type filter for the favorites segmented control
enum FavoritesTypeFilter: String, CaseIterable, Codable {
    case all = "All"
    case art = "Art"
    case camp = "Camps"
    case event = "Events"
    case mutantVehicle = "Vehicles"
}

/// Type-safe wrapper for a favorited object of any type
enum FavoriteItem: Identifiable {
    case art(ArtObject)
    case camp(CampObject)
    case event(EventObjectOccurrence)
    case mutantVehicle(MutantVehicleObject)

    var id: String { uid }

    var uid: String {
        switch self {
        case .art(let o): o.uid
        case .camp(let o): o.uid
        case .event(let o): o.uid
        case .mutantVehicle(let o): o.uid
        }
    }

    var name: String {
        switch self {
        case .art(let o): o.name
        case .camp(let o): o.name
        case .event(let o): o.name
        case .mutantVehicle(let o): o.name
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let o): o.location
        case .camp(let o): o.location
        case .event(let o): o.location
        case .mutantVehicle: nil
        }
    }

    var typeFilter: FavoritesTypeFilter {
        switch self {
        case .art: .art
        case .camp: .camp
        case .event: .event
        case .mutantVehicle: .mutantVehicle
        }
    }

    var detailSubject: DetailSubject {
        switch self {
        case .art(let o): .art(o)
        case .camp(let o): .camp(o)
        case .event(let o): .eventOccurrence(o)
        case .mutantVehicle(let o): .mutantVehicle(o)
        }
    }
}

/// A section of favorite items grouped by type
struct FavoriteSection: Identifiable {
    let id: FavoritesTypeFilter
    let title: String
    let items: [FavoriteItem]
}
