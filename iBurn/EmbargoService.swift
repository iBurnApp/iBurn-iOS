//
//  EmbargoService.swift
//  iBurn
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

/// The phone's adoption of the shared `LocationEmbargo` rule.
///
/// `BRCEmbargo` (the Objective-C façade the whole app still calls) forwards every
/// question here, so there is exactly one place that decides whether embargoed
/// placement may be drawn, and it is the same pure rule the watch uses:
///
/// ```
/// passcodeUnlocked || (inRegion && now >= unlockDate(tier))
/// ```
///
/// The date on its own is deliberately **not** enough. `Settings ▸ General ▸ Date
/// & Time` is user-settable, so the old "unlock at gates open" check was defeated
/// by dragging the clock forward — and, worse, it *latched* that unlock into the
/// passcode flag, so a single minute of a forward clock unlocked the app for the
/// season. Standing inside the Burning Man region is not forgeable that way, so
/// that is the half that gets persisted (`UserDefaults.enteredBurningManRegion`),
/// and the date is re-evaluated live on every call.
///
/// The accepted cost, decided for the 2026.0 release: someone at home stays
/// locked past the unlock dates unless they enter the BMorg passcode.
@objc(BRCEmbargoService)
public final class EmbargoService: NSObject {

    /// Built from `YearSettings` rather than re-parsing the plist, so the phone's
    /// dates come from the same accessor the rest of the app reads.
    private static let embargo = LocationEmbargo(
        schedule: EmbargoSchedule(
            campLocationUnlock: YearSettings.campLocationUnlock,
            artLocationUnlock: YearSettings.eventStart
        )
    )

    /// The Burning Man region, for callers that have a fix but no `CLCircularRegion`
    /// monitoring set up.
    private static let region = EmbargoRegion(
        centerLatitude: BRCLocations.blackRockCityCenter.latitude,
        centerLongitude: BRCLocations.blackRockCityCenter.longitude
    )

    // MARK: - Inputs

    /// The BMorg passcode was entered on this device. The one bypass.
    @objc public static var passcodeUnlocked: Bool {
        UserDefaults.enteredEmbargoPasscode
    }

    /// This device is, or has been, inside the Burning Man region.
    ///
    /// Reads both the in-memory flag other features already watch
    /// (`BRCLocations.hasEnteredBurningManRegion`) and the persisted latch, so a
    /// relaunch on playa doesn't re-lock the app while waiting for the next fix.
    @objc public static var hasSeenBurningManRegion: Bool {
        BRCLocations.hasEnteredBurningManRegion || UserDefaults.enteredBurningManRegion
    }

    /// Records that the device is at Burning Man. Idempotent; never cleared for the
    /// season (the defaults key is year-stamped, so next year re-arms).
    ///
    /// Latching a *visit* is safe in a way that latching a date check is not: no
    /// clock change can manufacture a past trip to Black Rock City.
    @objc public static func noteEnteredBurningManRegion() {
        BRCLocations.hasEnteredBurningManRegion = true
        guard !UserDefaults.enteredBurningManRegion else { return }
        UserDefaults.enteredBurningManRegion = true
    }

    /// `noteEnteredBurningManRegion()` for callers holding a raw fix.
    @objc public static func noteLocationFix(_ location: CLLocation) {
        guard LocationEmbargo.isInRegion(location: location, region: region) else { return }
        noteEnteredBurningManRegion()
    }

    // MARK: - Verdicts

    /// The pure rule, with every input passed in — the seam the tests drive.
    static func canShowLocations(
        tier: EmbargoTier,
        now: Date,
        passcodeUnlocked: Bool,
        inRegion: Bool
    ) -> Bool {
        embargo.canShowLocations(
            tier: tier,
            now: now,
            passcodeUnlocked: passcodeUnlocked,
            inRegion: inRegion
        )
    }

    /// The rule against live app state.
    static func canShowLocations(tier: EmbargoTier) -> Bool {
        canShowLocations(
            tier: tier,
            now: Date.present,
            passcodeUnlocked: passcodeUnlocked,
            inRegion: hasSeenBurningManRegion
        )
    }

    /// Backs `BRCEmbargo.allowEmbargoedData` — the art tier, i.e. "everything is
    /// visible", which is what the flag has always meant to its callers.
    @objc public static func allowEmbargoedData() -> Bool {
        canShowLocations(tier: .art)
    }

    @objc public static func canShowCampLocations() -> Bool {
        canShowLocations(tier: .camp)
    }

    @objc public static func canShowArtLocations() -> Bool {
        canShowLocations(tier: .art)
    }
}

/// Which tier a *map* surface answers to.
///
/// The camp tier (`YearSettings.campLocationUnlock`, the Sunday before gates) releases a
/// camp's **address text** and the pin for a camp the user asked to see — one camp, on
/// purpose. It does not release the city's placement: a screen that draws hundreds of camp
/// pins, or the polygons/labels the placement geojson carries, is exact placement data in
/// bulk and waits for gates (`YearSettings.eventStart`), the same instant art unlocks.
///
/// The passcode bypass is inherent — it satisfies every tier — so nothing here needs to
/// special-case it.
///
/// Both verdicts are re-read on every call (never cached across the tier dates) and the
/// live surfaces additionally restart on `.BRCEmbargoDidClear`.
enum MapEmbargo {

    /// Many camps' positions at once: the browse map's camp pins, the `camp-labels-big` and
    /// `camp-boundaries` style layers, and the bulk event pins that sit on their host camp.
    /// Gates-open tier.
    static func allowsBulkCampPlacement() -> Bool {
        EmbargoService.canShowLocations(tier: .art)
    }

    /// One camp the user navigated to: its detail pin, its pushed map, its address text.
    /// Camp tier — this is the thing the week-early release is for.
    static func allowsSingleCampLocation() -> Bool {
        EmbargoService.canShowLocations(tier: .camp)
    }

    /// Art placement, in bulk or singly. Gates-open tier either way.
    static func allowsArtLocation() -> Bool {
        EmbargoService.canShowLocations(tier: .art)
    }

    /// A bulk event pin. An event at an art piece leaks the art's position and an event at a
    /// camp leaks the camp's, so in bulk both wait for gates; the two tiers happen to
    /// coincide there, and this stays spelled out so the reason survives.
    static func allowsBulkEventPin(locatedAtArt: Bool) -> Bool {
        locatedAtArt ? allowsArtLocation() : allowsBulkCampPlacement()
    }
}
