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
    case art(ListRow<ArtObject>)
    case camp(ListRow<CampObject>)
    case event(ListRow<EventObjectOccurrence>)
    case mutantVehicle(ListRow<MutantVehicleObject>)

    var id: String { uid }

    var uid: String {
        switch self {
        case .art(let r): r.object.uid
        case .camp(let r): r.object.uid
        case .event(let r): r.object.uid
        case .mutantVehicle(let r): r.object.uid
        }
    }

    var name: String {
        switch self {
        case .art(let r): r.object.name
        case .camp(let r): r.object.name
        case .event(let r): r.object.name
        case .mutantVehicle(let r): r.object.name
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let r): r.object.location
        case .camp(let r): r.object.location
        case .event(let r): r.object.location
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
        case .art(let r): .art(r.object)
        case .camp(let r): .camp(r.object)
        case .event(let r): .eventOccurrence(r.object)
        case .mutantVehicle(let r): .mutantVehicle(r.object)
        }
    }

    var metadata: ObjectMetadata? {
        switch self {
        case .art(let r): r.metadata
        case .camp(let r): r.metadata
        case .event(let r): r.metadata
        case .mutantVehicle(let r): r.metadata
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
        case .mutantVehicle(let r): r.isFavorite
        }
    }

    var thumbnailColors: ThumbnailColors? {
        switch self {
        case .art(let r): r.thumbnailColors
        case .camp(let r): r.thumbnailColors
        case .event(let r): r.thumbnailColors
        case .mutantVehicle(let r): r.thumbnailColors
        }
    }
}

/// A section of favorite items grouped by type
struct FavoriteSection: Identifiable {
    let id: FavoritesTypeFilter
    let title: String
    let items: [FavoriteItem]
}
