//
//  EmbargoTierTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn
import PlayaDB

/// Covers the two-tier location embargo required by the BMorg API ToS:
/// theme camp locations may be shown from 12:01 am on the Sunday of the week
/// before the event (`YearSettings.campLocationUnlock`), while art locations
/// (and events located at art) stay hidden until gates open (`eventStart`).
final class EmbargoTierTests: XCTestCase {

    private var originalUnlocked = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalUnlocked = UserDefaults.enteredEmbargoPasscode
        UserDefaults.enteredEmbargoPasscode = false
        UserDefaults.standard.set(true, forKey: "BRCMockDateEnabled")
    }

    override func tearDownWithError() throws {
        UserDefaults.enteredEmbargoPasscode = originalUnlocked
        UserDefaults.standard.removeObject(forKey: "BRCMockDateEnabled")
        UserDefaults.standard.removeObject(forKey: "BRCMockDateValue")
        try super.tearDownWithError()
    }

    private func timeTravel(to iso8601: String) throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: iso8601))
        UserDefaults.standard.set(date, forKey: "BRCMockDateValue")
    }

    // MARK: - Tier dates

    func testEverythingLockedBeforeCampWindow() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        XCTAssertFalse(BRCEmbargo.allowEmbargoedData())
        XCTAssertFalse(BRCEmbargo.canShowCampLocations())
        XCTAssertFalse(BRCEmbargo.canShowArtLocations())
    }

    func testCampTierUnlocksAtCampLocationUnlock() throws {
        // Exactly 12:01 am PDT on the Sunday one week before gates.
        try timeTravel(to: "2026-08-23T07:01:00Z")
        XCTAssertFalse(BRCEmbargo.allowEmbargoedData())
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertFalse(BRCEmbargo.canShowArtLocations())
    }

    func testCampWindowShowsCampsButNotArt() throws {
        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertFalse(BRCEmbargo.allowEmbargoedData())
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertFalse(BRCEmbargo.canShowArtLocations())
    }

    func testEverythingUnlockedAfterGatesOpen() throws {
        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertTrue(BRCEmbargo.allowEmbargoedData())
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertTrue(BRCEmbargo.canShowArtLocations())
    }

    func testPasscodeUnlocksEverythingEarly() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertTrue(BRCEmbargo.allowEmbargoedData())
        XCTAssertTrue(BRCEmbargo.canShowCampLocations())
        XCTAssertTrue(BRCEmbargo.canShowArtLocations())
    }

    // MARK: - Event tiering

    private func makeEvent(hostedByCamp: String? = nil, locatedAtArt: String? = nil) -> EventObject {
        EventObject(
            uid: "test-event",
            name: "Test Event",
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt
        )
    }

    func testCampHostedEventFollowsCampTier() throws {
        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertTrue(BRCEmbargo.canShowLocation(for: makeEvent(hostedByCamp: "camp-1")))
    }

    func testArtLocatedEventFollowsArtTier() throws {
        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertFalse(BRCEmbargo.canShowLocation(for: makeEvent(locatedAtArt: "art-1")))
        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertTrue(BRCEmbargo.canShowLocation(for: makeEvent(locatedAtArt: "art-1")))
    }

    // MARK: - Camp boundary map layers

    func testCampLayersHiddenWhileEmbargoedRegardlessOfSettings() {
        let visibility = CampLayerVisibility.resolve(
            showCampBoundaries: true,
            showCampBoundariesAlways: true,
            showBigCampNames: true,
            embargoAllowsCamps: false
        )
        XCTAssertFalse(visibility.boundariesVisible)
        XCTAssertNil(visibility.boundariesMinimumZoom)
        XCTAssertFalse(visibility.labelsVisible)
    }

    func testCampLayersFollowSettingsOnceUnlocked() {
        let zoomed = CampLayerVisibility.resolve(
            showCampBoundaries: true,
            showCampBoundariesAlways: false,
            showBigCampNames: true,
            embargoAllowsCamps: true
        )
        XCTAssertTrue(zoomed.boundariesVisible)
        XCTAssertEqual(zoomed.boundariesMinimumZoom, 15)
        XCTAssertTrue(zoomed.labelsVisible)

        let always = CampLayerVisibility.resolve(
            showCampBoundaries: true,
            showCampBoundariesAlways: true,
            showBigCampNames: false,
            embargoAllowsCamps: true
        )
        XCTAssertTrue(always.boundariesVisible)
        XCTAssertEqual(always.boundariesMinimumZoom, 0)
        XCTAssertFalse(always.labelsVisible)

        let disabled = CampLayerVisibility.resolve(
            showCampBoundaries: false,
            showCampBoundariesAlways: false,
            showBigCampNames: false,
            embargoAllowsCamps: true
        )
        XCTAssertFalse(disabled.boundariesVisible)
        XCTAssertNil(disabled.boundariesMinimumZoom)
        XCTAssertFalse(disabled.labelsVisible)
    }
}
