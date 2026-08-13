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
/// Two things can unlock a tier:
///
/// 1. The date, read from the same `YearSettings.plist` the phone uses (the file
///    is a shared resource of both app targets), evaluated fresh on every call —
///    no persisted "already unlocked" flag to go stale.
/// 2. A passcode entered on the paired phone, latched into `UserDefaults` by
///    `PeerSyncManager` (see `iBurnWatchApp`). The watch has no passcode UI of
///    its own.
///
/// Fails closed: a missing or unreadable `YearSettings.plist` embargoes
/// everything rather than guessing.
enum WatchEmbargo {

    /// `UserDefaults` key latched when the paired phone reports it is unlocked.
    static let phoneUnlockedDefaultsKey = "embargoUnlockedFromPhone"

    private static let embargo: LocationEmbargo? = EmbargoSchedule.load(in: .main)
        .map(LocationEmbargo.init(schedule:))

    /// Records that the paired phone has the embargo unlocked. Idempotent, and
    /// never clears — the phone only ever reports `true`.
    static func setUnlockedFromPhone() {
        guard !UserDefaults.standard.bool(forKey: phoneUnlockedDefaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: phoneUnlockedDefaultsKey)
    }

    static var isUnlockedFromPhone: Bool {
        UserDefaults.standard.bool(forKey: phoneUnlockedDefaultsKey)
    }

    static func canShowLocations(tier: EmbargoTier, now: Date = Date()) -> Bool {
        guard let embargo else { return tier == .unrestricted }
        return embargo.canShowLocations(tier: tier, now: now, passcodeUnlocked: isUnlockedFromPhone)
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
