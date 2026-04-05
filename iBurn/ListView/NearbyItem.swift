import CoreLocation
import PlayaDB

/// Section identifiers for the nearby list
enum NearbySectionID: String {
    case events
    case art
    case camps
}

/// A section of nearby items grouped by type
struct NearbySection: Identifiable {
    let id: NearbySectionID
    let title: String
    let items: [NearbyItem]
}

/// Type-safe wrapper for a nearby object of any type
enum NearbyItem: Identifiable {
    case art(ArtObject)
    case camp(CampObject)
    case event(EventObjectOccurrence)

    var id: String {
        switch self {
        case .art(let o): "art-\(o.uid)"
        case .camp(let o): "camp-\(o.uid)"
        case .event(let o): "event-\(o.uid)"
        }
    }

    var name: String {
        switch self {
        case .art(let o): o.name
        case .camp(let o): o.name
        case .event(let o): o.name
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let o): o.location
        case .camp(let o): o.location
        case .event(let o): o.location
        }
    }

    var detailSubject: DetailSubject {
        switch self {
        case .art(let o): .art(o)
        case .camp(let o): .camp(o)
        case .event(let o): .eventOccurrence(o)
        }
    }
}
