//
//  WatchEmbargo.swift
//  iBurnWatch
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

/// The watch's view of the BMorg location embargo.
///
/// The seeded database ships full GPS for every camp and art piece — the watch
/// has no over-the-air update path, so stripping coordinates from the seed would
/// leave watch users location-less all season. Instead every surface that could
/// reveal a coordinate (list distances, Nearby, Navigate, favourite ordering)
/// asks here first.
///
/// A tier unlocks only when one of these holds:
///
/// 1. **Passcode**, entered on the paired phone and latched into `UserDefaults`
///    by `PeerSyncManager` (see `iBurnWatchApp`). The watch has no passcode UI
///    of its own. The single bypass.
/// 2. **Being at Burning Man, on or after the tier's date** — the date read from
///    the same `YearSettings.plist` the phone uses (a shared resource of both app
///    targets), evaluated live on every call, *and* a GPS fix inside the Burning
///    Man region.
///
/// The date on its own is explicitly not enough: the watch clock is
/// user-settable, so a date-only gate is defeated by moving Date & Time forward.
/// A visit to Black Rock City is not forgeable that way, so the region half is
/// the part that is persisted (`regionSeenDefaultsKey`) — once seen, always
/// seen, which is what keeps the unlock stable when GPS drops out mid-event.
/// The accepted cost: a watch that never gets a playa fix and never hears from a
/// phone stays locked all season.
///
/// Fails closed: a missing or unreadable `YearSettings.plist` embargoes
/// everything rather than guessing.
enum WatchEmbargo {

    /// `UserDefaults` key latched when the paired phone reports it is unlocked.
    static let phoneUnlockedDefaultsKey = "embargoUnlockedFromPhone"

    /// `UserDefaults` key latched the first time this watch takes a fix inside
    /// the Burning Man region.
    static let regionSeenDefaultsKey = "embargoRegionSeen"

    private static let embargo: LocationEmbargo? = EmbargoSchedule.load(in: .main)
        .map(LocationEmbargo.init(schedule:))

    private static let region: EmbargoRegion? = EmbargoRegion.load(in: .main)

    /// Records that the paired phone has the embargo unlocked. Idempotent, and
    /// never clears — the phone only ever reports `true`.
    static func setUnlockedFromPhone() {
        guard !isUnlockedFromPhone else { return }
        UserDefaults.standard.set(true, forKey: phoneUnlockedDefaultsKey)
        NotificationCenter.default.post(name: .embargoDidUnlock, object: nil)
    }

    static var isUnlockedFromPhone: Bool {
        UserDefaults.standard.bool(forKey: phoneUnlockedDefaultsKey)
    }

    static var hasSeenBurningManRegion: Bool {
        UserDefaults.standard.bool(forKey: regionSeenDefaultsKey)
    }

    /// Every location fix the watch takes passes through here (see
    /// `LocationService`); the first one on the playa latches the region half of
    /// the rule. It unlocks nothing by itself — the tier's date still has to
    /// arrive — so this can run years before the event with no effect.
    static func noteLocationFix(_ location: CLLocation) {
        guard !hasSeenBurningManRegion,
              LocationEmbargo.isInRegion(location: location, region: region)
        else { return }
        UserDefaults.standard.set(true, forKey: regionSeenDefaultsKey)
        NotificationCenter.default.post(name: .embargoDidUnlock, object: nil)
    }

    static func canShowLocations(tier: EmbargoTier, now: Date = Date()) -> Bool {
        guard let embargo else { return tier == .unrestricted }
        return embargo.canShowLocations(
            tier: tier,
            now: now,
            passcodeUnlocked: isUnlockedFromPhone,
            inRegion: hasSeenBurningManRegion
        )
    }

    static var canShowCampLocations: Bool { canShowLocations(tier: .camp) }

    static var canShowArtLocations: Bool { canShowLocations(tier: .art) }

    /// Whether this object's coordinates may be shown at all.
    static func canShowLocation(for object: any DataObject) -> Bool {
        canShowLocations(tier: object.embargoTier)
    }

    /// Distance from `userLocation`, or `nil` when the object is embargoed,
    /// placeless, or there is no fix. The single funnel every distance label on
    /// the watch goes through.
    static func distance(
        for object: any DataObject,
        from userLocation: CLLocation?
    ) -> CLLocationDistance? {
        guard canShowLocation(for: object),
              let userLocation,
              let objectLocation = object.location
        else { return nil }
        return objectLocation.distance(from: userLocation)
    }
}
