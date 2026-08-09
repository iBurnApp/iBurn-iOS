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

    // MARK: - Nearby proximity line

    // A walk/bike estimate is computed from the same embargoed coordinates as the address,
    // so `NearbyItem.canShowLocation` gates both. `NearbyViewModel.distanceString` returns
    // nil when it is false, which is what makes the row fall back to the masked "? min".

    func testNearbyProximityHiddenForArtAndCampsBeforeAnyTierOpens() throws {
        try timeTravel(to: "2026-08-10T12:00:00Z")
        XCTAssertFalse(artItem(locationString: "Open Playa").canShowLocation)
        XCTAssertFalse(campItem(locationString: "7:30 & Esplanade").canShowLocation)
    }

    func testNearbyProximityFollowsCampTierInsideTheCampWindow() throws {
        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertFalse(artItem(locationString: "Open Playa").canShowLocation)
        XCTAssertTrue(campItem(locationString: "7:30 & Esplanade").canShowLocation)
    }

    func testNearbyProximityVisibleForEverythingOnceGatesOpen() throws {
        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertTrue(artItem(locationString: "Open Playa").canShowLocation)
        XCTAssertTrue(campItem(locationString: "7:30 & Esplanade").canShowLocation)
    }

    func testNearbyProximityForEventsFollowsTheHostTier() throws {
        let camp = CampObject(uid: "camp-1", name: "Camp Test", year: 2026, locationString: "7:30 & Esplanade")
        let art = ArtObject(uid: "art-1", name: "The Hitchin' Post", year: 2026, locationString: "Open Playa")

        try timeTravel(to: "2026-08-25T12:00:00Z")
        XCTAssertTrue(eventItem(host: camp).canShowLocation)
        XCTAssertFalse(eventItem(host: art).canShowLocation)

        try timeTravel(to: "2026-08-31T12:00:00Z")
        XCTAssertTrue(eventItem(host: art).canShowLocation)
    }

    // MARK: - Map region annotations

    // `UserMapViewAdapter` drops pins for whatever `fetchObjects(in:)` returns for the
    // current viewport — a second annotation source that bypassed the embargo entirely, so
    // locked camps rendered pins whose callout is the full playa address.
    // `MapRegionAnnotationFilter` is the pure seam that now gates it; the tiers are passed
    // in rather than read from `BRCEmbargo`, so these cases need no mock date.

    private let brcLatitude = 40.7931
    private let brcLongitude = -119.2179

    private func regionArt(uid: String = "art-1", name: String = "Region Art") -> ArtObject {
        ArtObject(
            uid: uid,
            name: name,
            year: 2026,
            locationString: "Open Playa",
            gpsLatitude: brcLatitude,
            gpsLongitude: brcLongitude
        )
    }

    private func regionCamp(uid: String = "camp-1", name: String = "Region Camp") -> CampObject {
        CampObject(
            uid: uid,
            name: name,
            year: 2026,
            locationString: "7:30 & Esplanade",
            gpsLatitude: brcLatitude,
            gpsLongitude: brcLongitude
        )
    }

    private func regionEvent(uid: String = "event-1",
                             name: String = "Region Event",
                             hostedByCamp: String? = nil,
                             locatedAtArt: String? = nil) -> EventObject {
        EventObject(
            uid: uid,
            name: name,
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt,
            gpsLatitude: brcLatitude,
            gpsLongitude: brcLongitude
        )
    }

    private func regionAnnotationTitles(
        _ objects: [any PlayaDataObject],
        zoomLevel: Double = 18,
        activeEventUIDs: Set<String> = [],
        showArtOnlyZoomedIn: Bool = true,
        showCampsOnlyZoomedIn: Bool = true,
        artAllowed: Bool,
        campAllowed: Bool
    ) -> [String] {
        MapRegionAnnotationFilter.annotations(
            from: objects,
            zoomLevel: zoomLevel,
            activeEventUIDs: activeEventUIDs,
            showArtOnlyZoomedIn: showArtOnlyZoomedIn,
            showCampsOnlyZoomedIn: showCampsOnlyZoomedIn,
            artAllowed: artAllowed,
            campAllowed: campAllowed
        ).compactMap(\.title)
    }

    func testRegionAnnotationsDropArtAndCampsWhileFullyEmbargoed() {
        let titles = regionAnnotationTitles(
            [regionArt(), regionCamp()],
            artAllowed: false,
            campAllowed: false
        )
        XCTAssertEqual(titles, [])
    }

    func testRegionAnnotationsShowCampsButNotArtInsideTheCampWindow() {
        let titles = regionAnnotationTitles(
            [regionArt(), regionCamp()],
            artAllowed: false,
            campAllowed: true
        )
        XCTAssertEqual(titles, ["Region Camp"])
    }

    func testRegionAnnotationsShowEverythingOnceUnlocked() {
        let titles = regionAnnotationTitles(
            [regionArt(), regionCamp()],
            artAllowed: true,
            campAllowed: true
        )
        XCTAssertEqual(titles, ["Region Art", "Region Camp"])
    }

    func testRegionEventAtArtStaysOnTheArtTier() {
        let campEvent = regionEvent(uid: "event-camp", name: "Camp Event", hostedByCamp: "camp-1")
        let artEvent = regionEvent(uid: "event-art", name: "Art Event", locatedAtArt: "art-1")
        let active: Set<String> = ["event-camp", "event-art"]

        XCTAssertEqual(
            regionAnnotationTitles([campEvent, artEvent],
                                   activeEventUIDs: active,
                                   artAllowed: false,
                                   campAllowed: true),
            ["Camp Event"]
        )
        XCTAssertEqual(
            regionAnnotationTitles([campEvent, artEvent],
                                   activeEventUIDs: active,
                                   artAllowed: true,
                                   campAllowed: true),
            ["Art Event", "Camp Event"]
        )
        XCTAssertEqual(
            regionAnnotationTitles([campEvent, artEvent],
                                   activeEventUIDs: active,
                                   artAllowed: false,
                                   campAllowed: false),
            []
        )
    }

    /// The embargo gate is additive: the pre-existing zoom, settings and happening-now
    /// rules still have to hold once everything is unlocked.
    func testRegionAnnotationsKeepZoomAndSettingsRulesWhenUnlocked() {
        // Camps need z17; art is eligible from z16.
        XCTAssertEqual(
            regionAnnotationTitles([regionArt(), regionCamp()],
                                   zoomLevel: 16.5,
                                   artAllowed: true,
                                   campAllowed: true),
            ["Region Art"]
        )
        // Settings off means the always-on data source owns those pins, not this path.
        XCTAssertEqual(
            regionAnnotationTitles([regionArt(), regionCamp()],
                                   showArtOnlyZoomedIn: false,
                                   showCampsOnlyZoomedIn: false,
                                   artAllowed: true,
                                   campAllowed: true),
            []
        )
        // An event that isn't happening now stays off the map even when unlocked.
        XCTAssertEqual(
            regionAnnotationTitles([regionEvent(hostedByCamp: "camp-1")],
                                   activeEventUIDs: [],
                                   artAllowed: true,
                                   campAllowed: true),
            []
        )
    }

    /// Objects with no coordinates can't be annotated at all, embargo or not.
    func testRegionAnnotationsSkipObjectsWithoutCoordinates() {
        let placeless = CampObject(uid: "camp-2", name: "Placeless Camp", year: 2026)
        XCTAssertEqual(
            regionAnnotationTitles([placeless], artAllowed: true, campAllowed: true),
            []
        )
    }
}
