import CoreLocation
import PlayaDB

/// Type-safe wrapper for a search result of any type
enum SearchResultItem: Identifiable {
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

    var objectDescription: String? {
        switch self {
        case .art(let o): o.description
        case .camp(let o): o.description
        case .event(let o): o.description
        case .mutantVehicle(let o): o.description
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

    var detailSubject: DetailSubject {
        switch self {
        case .art(let o): .art(o)
        case .camp(let o): .camp(o)
        case .event(let o): .eventOccurrence(o)
        case .mutantVehicle(let o): .mutantVehicle(o)
        }
    }
}

/// A section of search results grouped by type
struct SearchResultSection: Identifiable {
    let id: DataObjectType
    let title: String
    let items: [SearchResultItem]
}
