import CoreLocation
import PlayaDB

/// Type filter for the recently viewed segmented control
enum RecentlyViewedTypeFilter: String, CaseIterable, Codable {
    case all = "All"
    case art = "Art"
    case camp = "Camps"
    case event = "Events"
    case mutantVehicle = "Vehicles"
}

/// Sort order for recently viewed list
enum RecentlyViewedSortOrder: String, CaseIterable {
    case recentFirst = "Recent"
    case firstViewed = "First Viewed"
    case nearest = "Nearest"
}

/// Timestamps for a recently viewed item
struct ViewDates {
    let firstViewed: Date?
    let lastViewed: Date
}

/// Type-safe wrapper for a recently viewed object of any type
enum RecentlyViewedItem: Identifiable {
    case art(ArtObject, ViewDates)
    case camp(CampObject, ViewDates)
    case event(EventObject, ViewDates)
    case mutantVehicle(MutantVehicleObject, ViewDates)

    var id: String { uid }

    var uid: String {
        switch self {
        case .art(let o, _): o.uid
        case .camp(let o, _): o.uid
        case .event(let o, _): o.uid
        case .mutantVehicle(let o, _): o.uid
        }
    }

    var name: String {
        switch self {
        case .art(let o, _): o.name
        case .camp(let o, _): o.name
        case .event(let o, _): o.name
        case .mutantVehicle(let o, _): o.name
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let o, _):
            return o.location
        case .camp(let o, _):
            return o.location
        case .event(let o, _):
            guard let lat = o.gpsLatitude, let lon = o.gpsLongitude else { return nil }
            return CLLocation(latitude: lat, longitude: lon)
        case .mutantVehicle:
            return nil
        }
    }

    var dates: ViewDates {
        switch self {
        case .art(_, let d): d
        case .camp(_, let d): d
        case .event(_, let d): d
        case .mutantVehicle(_, let d): d
        }
    }

    var lastViewed: Date { dates.lastViewed }
    var firstViewed: Date? { dates.firstViewed }

    var typeFilter: RecentlyViewedTypeFilter {
        switch self {
        case .art: .art
        case .camp: .camp
        case .event: .event
        case .mutantVehicle: .mutantVehicle
        }
    }

    var detailSubject: DetailSubject {
        switch self {
        case .art(let o, _): .art(o)
        case .camp(let o, _): .camp(o)
        case .event(let o, _): .event(o)
        case .mutantVehicle(let o, _): .mutantVehicle(o)
        }
    }

    var dataObject: Any {
        switch self {
        case .art(let o, _): o
        case .camp(let o, _): o
        case .event(let o, _): o
        case .mutantVehicle(let o, _): o
        }
    }
}

/// A section of recently viewed items grouped by type
struct RecentlyViewedSection: Identifiable {
    let id: RecentlyViewedTypeFilter
    let title: String
    let items: [RecentlyViewedItem]
}
