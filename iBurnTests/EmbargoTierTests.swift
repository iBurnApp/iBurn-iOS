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

    // MARK: - Nearby location line

    // `NearbyItem.address` is the one string the map's nearby card and the Nearby screen
    // put under an object's name, so it carries the tier check for both. Exercised here
    // rather than in a nearby-specific test case because the tiers are global state and
    // this case already owns the mock-date + passcode harness that moves them.

    private func artItem(locationString: String?) -> NearbyItem {
        .art(ListRow(
            object: ArtObject(uid: "art-1", name: "The Hitchin' Post", year: 2026, locationString: locationString),
            metadata: nil,
            thumbnailColors: nil
        ))
    }

    private func campItem(locationString: String?) -> NearbyItem {
        .camp(ListRow(
            object: CampObject(uid: "camp-1", name: "Camp Test", year: 2026, locationString: locationString),
            metadata: nil,
            thumbnailColors: nil
        ))
    }

    private func eventItem(host: (any PlaceDataObject)?, otherLocation: String = "") -> NearbyItem {
        let event = EventObject(
            uid: "event-1",
            name: "Test Event",
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: host is CampObject ? "camp-1" : nil,
            locatedAtArt: host is ArtObject ? "art-1" : nil,
            otherLocation: otherLocation
        )
        let occurrence = EventOccurrence(
            eventId: event.uid,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: Date(timeIntervalSince1970: 1_700_003_600)
        )
        return .event(ListRow(
            object: EventObjectOccurrence(event: event, occurrence: occurrence, host: host),
            metadata: nil,
            thumbnailColors: nil
        ))
    }

    func testNearbyAddressHidesArtAndCampsBeforeAnyTierOpens() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        XCTAssertNil(artItem(locationString: "Open Playa").address)
        XCTAssertNil(campItem(locationString: "7:30 & Esplanade").address)
    }

    func testNearbyAddressShowsCampsButNotArtInsideTheCampWindow() throws {
        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertNil(artItem(locationString: "Open Playa").address)
        XCTAssertEqual(campItem(locationString: "7:30 & Esplanade").address, "7:30 & Esplanade")
    }

    func testNearbyAddressShowsEverythingOnceGatesOpen() throws {
        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertEqual(artItem(locationString: "Open Playa").address, "Open Playa")
        XCTAssertEqual(campItem(locationString: "7:30 & Esplanade").address, "7:30 & Esplanade")
    }

    func testNearbyAddressShowsEverythingOncePasscodeEntered() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertEqual(artItem(locationString: "Open Playa").address, "Open Playa")
    }

    func testNearbyAddressTreatsBlankLocationStringsAsAbsent() throws {
        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertNil(artItem(locationString: "   ").address)
        XCTAssertNil(campItem(locationString: nil).address)
    }

    func testNearbyEventAddressFollowsItsHostTier() throws {
        let camp = CampObject(uid: "camp-1", name: "Camp Test", year: 2026, locationString: "7:30 & Esplanade")
        let art = ArtObject(uid: "art-1", name: "The Hitchin' Post", year: 2026, locationString: "Open Playa")

        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertEqual(eventItem(host: camp).address, "7:30 & Esplanade")
        XCTAssertNil(eventItem(host: art).address)

        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertEqual(eventItem(host: art).address, "Open Playa")
    }

    /// An unhosted event's free-text location is the user's own words, not placement data,
    /// so it survives the embargo and stands in when the host address is withheld.
    func testNearbyEventFallsBackToFreeTextLocationWhileEmbargoed() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        XCTAssertEqual(eventItem(host: nil, otherLocation: "Center Camp").address, "Center Camp")

        let art = ArtObject(uid: "art-1", name: "The Hitchin' Post", year: 2026, locationString: "Open Playa")
        XCTAssertEqual(eventItem(host: art, otherLocation: "Center Camp").address, "Center Camp")
    }
}
