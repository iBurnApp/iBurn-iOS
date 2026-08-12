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

    /// Occurrence start time for event rows, `nil` for everything else. Used to keep the
    /// Events section in chronological order, which is what its index stops assume.
    var startDate: Date? {
        switch self {
        case .event(let o): o.startDate
        default: nil
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

    /// Whether this result's placement may be shown at all, per its embargo tier.
    ///
    /// Gates the walk/bike estimate alongside the address — see `PlayaDistanceString`.
    /// Mutant vehicles roam, so they carry no placement to gate or show.
    var canShowLocation: Bool {
        switch self {
        case .art: BRCEmbargo.canShowArtLocations()
        case .camp: BRCEmbargo.canShowCampLocations()
        case .event(let o): BRCEmbargo.canShowLocation(for: o)
        case .mutantVehicle: false
        }
    }

    /// The underlying record, for APIs that take `any DataObject` (favorites, metadata).
    /// Spelled `PlayaDataObject`: the app module has its own unrelated `DataObject` class.
    var dataObject: any PlayaDataObject {
        switch self {
        case .art(let o): o
        case .camp(let o): o
        case .event(let o): o
        case .mutantVehicle(let o): o
        }
    }

    /// Key under which this item's favorite state is stored.
    ///
    /// Event favorites are per *occurrence*, so this is the occurrence's
    /// `EventFavoriteKey` composite, not the parent event uid. Search collapses an event
    /// to a single row (the soonest matching showing), so the row's heart is that
    /// showing's state and tapping it favorites exactly that showing — the same thing the
    /// event list does, and the same thing the "favorite all N showings?" offer follows up
    /// on. A different showing of the same event favorited elsewhere does not fill this
    /// heart, which is correct: the row is standing in for one showing, not for the event.
    ///
    /// Mirrors `PlayaDB.favoriteIdentifiers(among:)`, whose returned keys this is matched
    /// against.
    var favoriteIdentity: String {
        switch self {
        case .event(let o): o.favoriteIdentity
        default: uid
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
