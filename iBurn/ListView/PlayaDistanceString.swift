//
//  PlayaDistanceString.swift
//  iBurn
//
//  Created by Claude Code on 8/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

/// The single place a list row's walk/bike estimate is built.
///
/// Every surface that shows "🚶🏽 6m   🚴🏽 2m" — the Art and Camps lists, Events,
/// Favorites, the Visit List, Recently Viewed, Nearby, the map's visible-pins sheet and
/// global search — funnels through here, so the two rules that govern whether an estimate
/// may be shown at all can't be enforced on some screens and forgotten on others:
///
/// 1. **Embargo.** A distance is derived from the same coordinates the embargo hides: a
///    "6 min walk" on a locked camp narrows its placement just as surely as printing
///    "7:30 & Esplanade" would. While the item's tier is locked there is no estimate.
/// 2. **Plausibility.** A record whose coordinates are unset lands on null island, which
///    reads as a 12,000 km walk ("🚶🏽 4,832h 58m"). Nothing on the playa is more than a few
///    kilometres away, so anything past `maxPlausibleDistance` is bad data, not a long
///    walk, and gets no estimate either.
///
/// Both failures return `nil`, and `ObjectRowView` renders no distance line for a `nil`
/// subtitle — the row simply loses that fragment rather than advertising a placeholder.
enum PlayaDistanceString {

    /// Farthest a row may be from the user and still get a walk/bike estimate.
    ///
    /// Black Rock City is roughly 3 km across and the surrounding playa a few km more, so
    /// 30 km is generously beyond anywhere a burner could walk to and still comfortably
    /// short of the ~12,400 km a null-island record measures. Deliberately loose: this is
    /// a bad-data trap, not a geofence, and someone reading the app from Reno should still
    /// see nothing rather than a nonsense number.
    static let maxPlausibleDistance: CLLocationDistance = 30_000

    /// Whether a measured distance is close enough to be a real on-playa estimate.
    static func isPlausible(_ distance: CLLocationDistance) -> Bool {
        distance.isFinite && distance >= 0 && distance <= maxPlausibleDistance
    }

    /// Walk/bike estimate, or `nil` when there's nothing measurable, the item's placement
    /// is still embargoed, or the measurement is too far out to be real.
    ///
    /// - Parameters:
    ///   - userLocation: The user's current fix, `nil` when there isn't one.
    ///   - objectLocation: The item's placement, `nil` when it has none.
    ///   - canShowLocation: The item's embargo tier, already resolved by the caller.
    static func make(
        from userLocation: CLLocation?,
        to objectLocation: CLLocation?,
        canShowLocation: Bool
    ) -> AttributedString? {
        guard canShowLocation,
              let userLocation,
              let objectLocation else {
            return nil
        }
        let distance = userLocation.distance(from: objectLocation)
        guard isPlausible(distance),
              let humanized = TTTLocationFormatter.brc_humanizedString(forDistance: distance) else {
            return nil
        }
        return AttributedString(humanized)
    }

    // MARK: - Per-tier conveniences

    /// Art unlocks on its own (later) tier — see `BRCEmbargo.canShowArtLocations`.
    static func forArt(from userLocation: CLLocation?, to objectLocation: CLLocation?) -> AttributedString? {
        make(from: userLocation, to: objectLocation, canShowLocation: BRCEmbargo.canShowArtLocations())
    }

    /// Camps unlock with the camp tier — see `BRCEmbargo.canShowCampLocations`.
    static func forCamp(from userLocation: CLLocation?, to objectLocation: CLLocation?) -> AttributedString? {
        make(from: userLocation, to: objectLocation, canShowLocation: BRCEmbargo.canShowCampLocations())
    }

    /// An event follows its host: art-hosted events stay on the art tier.
    static func forEvent(
        from userLocation: CLLocation?,
        to occurrence: EventObjectOccurrence
    ) -> AttributedString? {
        make(
            from: userLocation,
            to: occurrence.location,
            canShowLocation: BRCEmbargo.canShowLocation(for: occurrence)
        )
    }

    /// An event known only as a bare `EventObject` (degraded map-annotation path).
    static func forEvent(from userLocation: CLLocation?, to event: EventObject) -> AttributedString? {
        make(
            from: userLocation,
            to: event.location,
            canShowLocation: BRCEmbargo.canShowLocation(for: event)
        )
    }
}
