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

/// Ordering for the events inside the nearby window, shared by the Nearby screen and the
/// map card so the two lists can't disagree.
enum NearbyEventOrdering {

    /// Sort key: `(phase, offset, uid)`.
    ///
    /// Ascending start time — the old ordering — buries the interesting rows: a 12-hour
    /// amenity listing that began at midnight sorts above a set that started five minutes
    /// ago, and above one starting in ten. So instead:
    ///
    /// 1. **Not yet started** (phase 0), soonest first. "Starts in 5m" outranks
    ///    "starts in 25m", and both outrank anything already running — the user can still
    ///    make these.
    /// 2. **Already started** (phase 1), most recently started first. Something that began
    ///    minutes ago is still joinable; something that began six hours ago is background.
    ///
    /// `uid` breaks ties so repeated rebuilds (every location fix, every timer tick) keep a
    /// stable order instead of shuffling rows under the user's thumb.
    static func sortKey(
        for occurrence: EventObjectOccurrence,
        now: Date
    ) -> (Int, TimeInterval, String) {
        let untilStart = occurrence.startDate.timeIntervalSince(now)
        return untilStart > 0
            ? (0, untilStart, occurrence.uid)
            : (1, -untilStart, occurrence.uid)
    }

    /// Pure ordering over rows already gated to the nearby window.
    static func sorted(
        _ rows: [ListRow<EventObjectOccurrence>],
        now: Date
    ) -> [ListRow<EventObjectOccurrence>] {
        rows.sorted { sortKey(for: $0.object, now: now) < sortKey(for: $1.object, now: now) }
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

    /// The map nearby card's accessory line: when and where, in one secondary line between
    /// the name and the description.
    ///
    /// Events lead with their live timing; everything that has a showable address adds it.
    /// The address comes from `address`, so the two-tier embargo check is the same one the
    /// rest of the app makes — a locked camp or art piece contributes nothing and the whole
    /// line disappears, handing its space back to the description.
    ///
    /// Composed here rather than in the view so the locked/unlocked shape is testable.
    func accessoryLine(now: Date) -> String? {
        var parts: [String] = []
        if case .event(let r) = self {
            parts.append(r.object.timeDescription(now: now))
        }
        if let address {
            parts.append(address)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
