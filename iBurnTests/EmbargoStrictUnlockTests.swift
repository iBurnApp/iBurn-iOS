//
//  EmbargoStrictUnlockTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import XCTest
@testable import iBurn
import PlayaDB

/// The location-embargo rule the phone adopted for 2026.0, per tier:
///
/// ```
/// .camp: passcodeUnlocked || now >= campLocationUnlock
/// .art:  passcodeUnlocked || (inRegion && now >= eventStart)
/// ```
///
/// The regression the strict half exists for: the app used to unlock itself the
/// moment `Date.present` passed the festival start — and latch that into the
/// passcode flag — so a minute of a forward-set device clock published every
/// camp and art coordinate for the season. Art placement still needs the region.
/// The camp tier was relaxed to date-only on 2026-08-22 (the week-early camp
/// address release has to be usable while planning from home), so what it can
/// leak is a camp's address text and the one pin the user opened — never bulk
/// placement, which rides `.art`. `EmbargoTierTests` covers which tier each date
/// opens; this covers what each input is and is not sufficient for.
final class EmbargoStrictUnlockTests: XCTestCase {

    private var originalUnlocked = false
    private var originalRegionSeen = false

    /// Comfortably after gates open for the 2026 settings.
    private let afterGatesOpen = "2026-08-31T12:00:00Z"
    /// Inside the camp window, before gates.
    private let insideCampWindow = "2026-08-25T12:00:00Z"
    /// Before either tier opens.
    private let beforeAnyTier = "2026-08-10T12:00:00Z"

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalUnlocked = UserDefaults.enteredEmbargoPasscode
        originalRegionSeen = UserDefaults.enteredBurningManRegion
        UserDefaults.enteredEmbargoPasscode = false
        UserDefaults.enteredBurningManRegion = false
        BRCLocations.hasEnteredBurningManRegion = false
        UserDefaults.standard.set(true, forKey: "BRCMockDateEnabled")
    }

    override func tearDownWithError() throws {
        UserDefaults.enteredEmbargoPasscode = originalUnlocked
        UserDefaults.enteredBurningManRegion = originalRegionSeen
        BRCLocations.hasEnteredBurningManRegion = false
        UserDefaults.standard.removeObject(forKey: "BRCMockDateEnabled")
        UserDefaults.standard.removeObject(forKey: "BRCMockDateValue")
        try super.tearDownWithError()
    }

    private func timeTravel(to iso8601: String) throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: iso8601))
        UserDefaults.standard.set(date, forKey: "BRCMockDateValue")
    }

    // MARK: - What a date alone unlocks

    /// Off playa, with no passcode: nothing at all until the camp date, then
    /// camp addresses only — art placement never rides the clock alone.
    func testDateAloneUnlocksTheCampTierOnly() throws {
        try timeTravel(to: beforeAnyTier)
        XCTAssertFalse(BRCEmbargo.canShowCampLocations(), beforeAnyTier)
        XCTAssertFalse(BRCEmbargo.canShowArtLocations(), beforeAnyTier)
        XCTAssertFalse(BRCEmbargo.allowEmbargoedData(), beforeAnyTier)

        for instant in [insideCampWindow, afterGatesOpen] {
            try timeTravel(to: instant)
            XCTAssertTrue(BRCEmbargo.canShowCampLocations(), instant)
            XCTAssertFalse(BRCEmbargo.canShowArtLocations(), instant)
            XCTAssertFalse(BRCEmbargo.allowEmbargoedData(), instant)
        }
    }

    /// Bulk camp placement (the browse map's pins, the boundary/label layers)
    /// is not on the relaxed tier: it waits for region + gates like art does.
    func testDateAloneDoesNotUnlockBulkCampPlacement() throws {
        try timeTravel(to: insideCampWindow)
        XCTAssertTrue(MapEmbargo.allowsSingleCampLocation())
        XCTAssertFalse(MapEmbargo.allowsBulkCampPlacement())
        XCTAssertFalse(MapEmbargo.allowsArtLocation())

        try timeTravel(to: afterGatesOpen)
        XCTAssertFalse(MapEmbargo.allowsBulkCampPlacement())
        XCTAssertFalse(MapEmbargo.allowsArtLocation())
    }

    /// The old behaviour didn't just answer "yes" past gates open, it wrote the
    /// passcode flag — permanently unlocking a device whose clock was wrong for a
    /// moment. Asking must stay side-effect free.
    func testAskingPastGatesOpenDoesNotLatchThePasscodeFlag() throws {
        try timeTravel(to: afterGatesOpen)
        _ = BRCEmbargo.allowEmbargoedData()
        _ = BRCEmbargo.canShowCampLocations()
        _ = BRCEmbargo.canShowArtLocations()
        XCTAssertFalse(UserDefaults.enteredEmbargoPasscode)
        XCTAssertFalse(UserDefaults.enteredBurningManRegion)
    }

    // MARK: - Region plus date

    func testRegionAloneUnlocksNothingBeforeTheDates() throws {
        try timeTravel(to: beforeAnyTier)
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertTrue(EmbargoService.hasSeenBurningManRegion)
        XCTAssertFalse(BRCEmbargo.canShowCampLocations())
        XCTAssertFalse(BRCEmbargo.canShowArtLocations())
    }

    /// The camp tier ignores the region half entirely: same verdict either way.
    func testCampTierIgnoresTheRegion() throws {
        try timeTravel(to: insideCampWindow)
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
    }

    func testRegionPlusCampDateUnlocksCampsOnly() throws {
        try timeTravel(to: insideCampWindow)
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertFalse(BRCEmbargo.canShowArtLocations())
        XCTAssertFalse(BRCEmbargo.allowEmbargoedData())
    }

    func testRegionPlusGatesOpenUnlocksEverything() throws {
        try timeTravel(to: afterGatesOpen)
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertTrue(BRCEmbargo.canShowArtLocations())
        XCTAssertTrue(BRCEmbargo.allowEmbargoedData())
    }

    // MARK: - Passcode

    func testPasscodeAloneUnlocksEverythingWithoutEverVisitingTheRegion() throws {
        try timeTravel(to: beforeAnyTier)
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertFalse(EmbargoService.hasSeenBurningManRegion)
        XCTAssertTrue(BRCEmbargo.allowEmbargoedData())
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertTrue(BRCEmbargo.canShowArtLocations())
    }

    // MARK: - Camp boundary polygons (the one surface the passcode does not open)

    /// BMorg asked on 2026-08-28 that the staff unlock passcode no longer reveal the
    /// camp footprint polygons (`camp-boundaries`). Passcode-only, off playa: hidden
    /// before *and* after the gates date, while everything else the passcode unlocks
    /// keeps working.
    func testPasscodeAloneNeverShowsCampBoundaryPolygons() throws {
        UserDefaults.enteredEmbargoPasscode = true
        for instant in [beforeAnyTier, insideCampWindow, afterGatesOpen] {
            try timeTravel(to: instant)
            XCTAssertFalse(EmbargoService.hasSeenBurningManRegion, instant)
            XCTAssertFalse(MapEmbargo.allowsCampBoundaryPolygons(), instant)
            // Unchanged by the policy change:
            XCTAssertTrue(MapEmbargo.allowsArtLocation(), instant)
            XCTAssertTrue(MapEmbargo.allowsBulkCampPlacement(), instant)
            XCTAssertTrue(MapEmbargo.allowsSingleCampLocation(), instant)
            XCTAssertTrue(BRCEmbargo.allowEmbargoedData(), instant)
        }
    }

    /// The polygons' own rule: region **and** gates, passcode irrelevant either way.
    func testCampBoundaryPolygonsNeedRegionAndGates() throws {
        try timeTravel(to: insideCampWindow)
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertFalse(MapEmbargo.allowsCampBoundaryPolygons())

        try timeTravel(to: afterGatesOpen)
        XCTAssertTrue(MapEmbargo.allowsCampBoundaryPolygons())
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertTrue(MapEmbargo.allowsCampBoundaryPolygons())
    }

    /// The pure seam, with no ambient state: no combination of inputs lets a passcode
    /// stand in for either half.
    func testCampBoundaryPolygonTruthTable() throws {
        let early = try XCTUnwrap(ISO8601DateFormatter().date(from: beforeAnyTier))
        let campOpen = try XCTUnwrap(ISO8601DateFormatter().date(from: insideCampWindow))
        let gatesOpen = try XCTUnwrap(ISO8601DateFormatter().date(from: afterGatesOpen))

        for now in [early, campOpen, gatesOpen] {
            for inRegion in [true, false] {
                XCTAssertEqual(
                    EmbargoService.canShowCampBoundaryPolygons(now: now, inRegion: inRegion),
                    inRegion && now >= gatesOpen,
                    "\(now) inRegion \(inRegion)")
            }
        }
    }

    // MARK: - The region latch

    /// The in-memory flag is lost on relaunch, so the verdict has to survive in
    /// `UserDefaults` or a phone on playa re-locks itself every cold start.
    func testRegionLatchSurvivesAUserDefaultsRoundTrip() throws {
        try timeTravel(to: afterGatesOpen)
        EmbargoService.noteEnteredBurningManRegion()

        // Simulate a relaunch: the process-local flag is gone, the defaults aren't.
        BRCLocations.hasEnteredBurningManRegion = false
        XCTAssertTrue(UserDefaults.standard.enteredBurningManRegion())
        XCTAssertTrue(EmbargoService.hasSeenBurningManRegion)
        XCTAssertTrue(BRCEmbargo.allowEmbargoedData())
    }

    /// The in-memory flag other features already watch still counts on its own,
    /// so the very first fix unlocks without waiting for a defaults write.
    func testInMemoryRegionFlagCountsToo() throws {
        try timeTravel(to: afterGatesOpen)
        BRCLocations.hasEnteredBurningManRegion = true
        XCTAssertTrue(EmbargoService.hasSeenBurningManRegion)
        XCTAssertTrue(BRCEmbargo.canShowArtLocations())
    }

    func testNotingRegionIsIdempotent() throws {
        EmbargoService.noteEnteredBurningManRegion()
        EmbargoService.noteEnteredBurningManRegion()
        XCTAssertTrue(EmbargoService.hasSeenBurningManRegion)
    }

    /// A fix off the playa must not latch anything.
    func testFixOutsideTheRegionDoesNotLatch() {
        EmbargoService.noteLocationFix(CLLocation(latitude: 37.7749, longitude: -122.4194))
        XCTAssertFalse(EmbargoService.hasSeenBurningManRegion)
        XCTAssertFalse(UserDefaults.enteredBurningManRegion)
    }

    func testFixInsideTheRegionLatches() {
        EmbargoService.noteLocationFix(CLLocation(latitude: 40.7864, longitude: -119.2065))
        XCTAssertTrue(EmbargoService.hasSeenBurningManRegion)
        XCTAssertTrue(UserDefaults.enteredBurningManRegion)
    }

    // MARK: - The pure seam

    /// Every combination, with no ambient state, so the rule itself is pinned
    /// independently of how the app happens to source its inputs.
    func testTruthTableOfThePureRule() throws {
        let campOpen = try XCTUnwrap(ISO8601DateFormatter().date(from: insideCampWindow))
        let gatesOpen = try XCTUnwrap(ISO8601DateFormatter().date(from: afterGatesOpen))
        let early = try XCTUnwrap(ISO8601DateFormatter().date(from: beforeAnyTier))

        for tier in [EmbargoTier.camp, .art] {
            for now in [early, campOpen, gatesOpen] {
                // Passcode: always, whatever the clock or the region says.
                XCTAssertTrue(EmbargoService.canShowLocations(
                    tier: tier, now: now, passcodeUnlocked: true, inRegion: true))
                XCTAssertEqual(
                    EmbargoService.canShowLocations(
                        tier: tier, now: now, passcodeUnlocked: false, inRegion: false),
                    tier == .camp && now >= campOpen,
                    "no passcode, off playa: only camps, only from the camp date")
            }
        }

        // Off playa, no passcode: camps from their date, art never.
        XCTAssertTrue(EmbargoService.canShowLocations(
            tier: .camp, now: campOpen, passcodeUnlocked: false, inRegion: false))
        XCTAssertTrue(EmbargoService.canShowLocations(
            tier: .camp, now: gatesOpen, passcodeUnlocked: false, inRegion: false))
        XCTAssertFalse(EmbargoService.canShowLocations(
            tier: .camp, now: early, passcodeUnlocked: false, inRegion: false))
        XCTAssertFalse(EmbargoService.canShowLocations(
            tier: .art, now: gatesOpen, passcodeUnlocked: false, inRegion: false))

        XCTAssertTrue(EmbargoService.canShowLocations(
            tier: .camp, now: campOpen, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(EmbargoService.canShowLocations(
            tier: .art, now: campOpen, passcodeUnlocked: false, inRegion: true))
        XCTAssertTrue(EmbargoService.canShowLocations(
            tier: .art, now: gatesOpen, passcodeUnlocked: false, inRegion: true))
        XCTAssertFalse(EmbargoService.canShowLocations(
            tier: .camp, now: early, passcodeUnlocked: false, inRegion: true))

        // Unrestricted data (mutant vehicles, user pins) is never gated.
        XCTAssertTrue(EmbargoService.canShowLocations(
            tier: .unrestricted, now: early, passcodeUnlocked: false, inRegion: false))
    }
}
