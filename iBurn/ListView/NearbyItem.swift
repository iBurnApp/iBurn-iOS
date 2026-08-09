import CoreLocation
import PlayaDB

extension String {
    /// Self unless it is empty or only whitespace.
    var trimmedNonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}

extension EventObjectOccurrence {
    /// How far ahead a not-yet-started occurrence still counts as nearby.
    static let nearbyStartingSoonWindow: TimeInterval = 30 * 60

    /// How much of an occurrence's tail to trim.
    ///
    /// `isCurrentlyHappening` counts an occurrence as happening right up to and including
    /// its end time, and the relative-time formatter can't render less than a minute — so
    /// the final seconds rendered as "(0m left)", advertising something that is over. This
    /// also absorbs the refresh cadence of both surfaces: neither re-evaluates `now` often
    /// enough to drop an occurrence the instant it ends.
    static let nearbyEndingGrace: TimeInterval = 60

    /// The one window both Nearby surfaces show: already running with real time left, or
    /// starting within the next half hour.
    ///
    /// Shared deliberately. The map card and the Nearby screen had grown separate
    /// predicates — `isCurrentlyHappening || isStartingSoon` against
    /// `startDate <= now + 30m && endDate > now` — which agreed most of the time and
    /// disagreed at the edges, so the two screens listed different events.
    func isInNearbyWindow(now: Date) -> Bool {
        startDate <= now.addingTimeInterval(Self.nearbyStartingSoonWindow)
            && endDate > now.addingTimeInterval(Self.nearbyEndingGrace)
    }
}

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

    /// Playa address for display, or nil while the embargo hides it. Art and camps are
    /// gated by their own embargo tiers; an event follows its host, and falls back to its
    /// free-text location, which is what unhosted events carry instead of an address.
    var address: String? {
        switch self {
        case .art(let r):
            guard BRCEmbargo.canShowArtLocations() else { return nil }
            return r.object.address?.trimmedNonEmpty
        case .camp(let r):
            guard BRCEmbargo.canShowCampLocations() else { return nil }
            return r.object.address?.trimmedNonEmpty
        case .event(let r):
            let other = r.object.otherLocation.trimmedNonEmpty
            guard BRCEmbargo.canShowLocation(for: r.object) else { return other }
            return r.object.hostAddress?.trimmedNonEmpty ?? other
        }
    }

    /// Whether this item's placement may be shown at all, per its embargo tier.
    ///
    /// Gates more than the address line: walk/bike estimates are derived from the same
    /// embargoed coordinates, so a "6 min walk" on a locked camp narrows its placement just
    /// as surely as printing "7:30 & Esplanade" would. See `NearbyViewModel.distanceString`.
    var canShowLocation: Bool {
        switch self {
        case .art: BRCEmbargo.canShowArtLocations()
        case .camp: BRCEmbargo.canShowCampLocations()
        case .event(let r): BRCEmbargo.canShowLocation(for: r.object)
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
