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
    case art(ListRow<ArtObject>)
    case camp(ListRow<CampObject>)
    case event(ListRow<EventObjectOccurrence>)

    var id: String {
        switch self {
        case .art(let r): "art-\(r.object.uid)"
        case .camp(let r): "camp-\(r.object.uid)"
        case .event(let r): "event-\(r.object.uid)"
        }
    }

    var name: String {
        switch self {
        case .art(let r): r.object.name
        case .camp(let r): r.object.name
        case .event(let r): r.object.name
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let r): r.object.location
        case .camp(let r): r.object.location
        case .event(let r): r.object.location
        }
    }

    var detailSubject: DetailSubject {
        switch self {
        case .art(let r): .art(r.object)
        case .camp(let r): .camp(r.object)
        case .event(let r): .eventOccurrence(r.object)
        }
    }

    var metadata: ObjectMetadata? {
        switch self {
        case .art(let r): r.metadata
        case .camp(let r): r.metadata
        case .event(let r): r.metadata
        }
    }

    var detailPageItem: DetailPageItem {
        DetailPageItem(subject: detailSubject, metadata: metadata, thumbnailColors: thumbnailColors)
    }

    var isFavorite: Bool {
        switch self {
        case .art(let r): r.isFavorite
        case .camp(let r): r.isFavorite
        case .event(let r): r.isFavorite
        }
    }

    var thumbnailColors: ThumbnailColors? {
        switch self {
        case .art(let r): r.thumbnailColors
        case .camp(let r): r.thumbnailColors
        case .event(let r): r.thumbnailColors
        }
    }
}
