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

    /// Defaults matching a stock install: boundaries and names on, "always" off, camp pins
    /// gated on zoom. Individual tests override only what they are about.
    private func makeCampLayers(showCampBoundaries: Bool = true,
                                showCampBoundariesAlways: Bool = false,
                                showBigCampNames: Bool = true,
                                embargoAllowsCamps: Bool = true,
                                zoomLevel: Double) -> CampLayerVisibility {
        CampLayerVisibility.resolve(
            showCampBoundaries: showCampBoundaries,
            showCampBoundariesAlways: showCampBoundariesAlways,
            showBigCampNames: showBigCampNames,
            embargoAllowsCamps: embargoAllowsCamps,
            zoomLevel: zoomLevel
        )
    }

    func testCampLayersHiddenWhileEmbargoedRegardlessOfSettings() {
        for zoomLevel in [14.0, 15.0, 17.0, 20.0] {
            let visibility = makeCampLayers(showCampBoundariesAlways: true,
                                            embargoAllowsCamps: false,
                                            zoomLevel: zoomLevel)
            XCTAssertFalse(visibility.boundariesVisible)
            XCTAssertNil(visibility.boundariesMinimumZoom)
            XCTAssertFalse(visibility.labelsVisible)
            // Nothing is drawing camp names, so a leaked pin must not silently fill in.
            XCTAssertFalse(visibility.campNamesDrawnByStyleLayer)
        }
    }

    func testCampLayersFollowSettingsOnceUnlocked() {
        let zoomed = makeCampLayers(zoomLevel: 16)
        XCTAssertTrue(zoomed.boundariesVisible)
        XCTAssertEqual(zoomed.boundariesMinimumZoom, 15)
        XCTAssertTrue(zoomed.labelsVisible)

        let always = makeCampLayers(showCampBoundariesAlways: true,
                                    showBigCampNames: false,
                                    zoomLevel: 16)
        XCTAssertTrue(always.boundariesVisible)
        XCTAssertEqual(always.boundariesMinimumZoom, 0)
        XCTAssertFalse(always.labelsVisible)

        let disabled = makeCampLayers(showCampBoundaries: false,
                                      showBigCampNames: false,
                                      zoomLevel: 16)
        XCTAssertFalse(disabled.boundariesVisible)
        XCTAssertNil(disabled.boundariesMinimumZoom)
        XCTAssertFalse(disabled.labelsVisible)
    }

    // MARK: - Camp names are drawn exactly once

    /// Below the style layer's minzoom nothing draws camp names, so any camp pin that is on
    /// screen (favourites, or "Camps (Always)") has to label itself.
    func testCampPinsLabelThemselvesBelowTheStyleLayersMinimumZoom() {
        XCTAssertFalse(makeCampLayers(zoomLevel: 14.9).campNamesDrawnByStyleLayer)
        XCTAssertTrue(makeCampLayers(zoomLevel: 15).campNamesDrawnByStyleLayer)
    }

    /// The layer is never capped: camp pins now yield to it rather than taking over above
    /// their own zoom threshold, so it keeps drawing all the way in.
    func testStyleLabelsRunToFullZoomOnceTheyStart() {
        for zoomLevel in [15.0, 17.0, 18.0, 22.0] {
            XCTAssertTrue(makeCampLayers(zoomLevel: zoomLevel).campNamesDrawnByStyleLayer,
                          "zoom \(zoomLevel)")
        }
    }

    /// Turning "Show Camp Names" off hands the job back to the pins at every zoom rather
    /// than leaving camps nameless.
    func testCampPinsLabelThemselvesWhenTheStyleLayerIsOff() {
        for zoomLevel in [15.0, 16.0, 18.0] {
            XCTAssertFalse(makeCampLayers(showBigCampNames: false, zoomLevel: zoomLevel)
                .campNamesDrawnByStyleLayer)
        }
    }

    /// Whatever the settings, `campNamesDrawnByStyleLayer` is true exactly when the layer is
    /// visible and the zoom is inside its (uncapped) range — the one fact the pins act on.
    func testStyleLabelVerdictAlwaysMatchesTheLayersOwnZoomRange() {
        for showBigCampNames in [true, false] {
            for embargoAllowsCamps in [true, false] {
                for zoomLevel in [12.0, 14.9, 15.0, 16.9, 17.0, 22.0] {
                    let v = makeCampLayers(showBigCampNames: showBigCampNames,
                                           embargoAllowsCamps: embargoAllowsCamps,
                                           zoomLevel: zoomLevel)
                    let layerIsPainting = v.labelsVisible
                        && zoomLevel >= Double(CampLayerVisibility.labelsMinimumZoom)
                    XCTAssertEqual(v.campNamesDrawnByStyleLayer, layerIsPainting,
                                   "zoom \(zoomLevel), names \(showBigCampNames), "
                                   + "embargo \(embargoAllowsCamps)")
                }
            }
        }
    }

    // MARK: - Which pin draws its own name

    private let labeledCamp = "camp-with-a-footprint"
    private let unlabeledCamp = "camp-without-a-footprint"
    private lazy var styleLabels: Set<String> = [labeledCamp]

    private func pinLabelIsHidden(campUID: String?,
                                  zoomLevel: Double = 18,
                                  styleDrawsCampNames: Bool = true,
                                  styleLabeledCampUIDs: Set<String>?) -> Bool {
        PinLabelVisibility.labelIsHidden(
            zoomLevel: zoomLevel,
            hiddenAtOrBelowZoom: 13,
            campUID: campUID,
            styleDrawsCampNames: styleDrawsCampNames,
            styleLabeledCampUIDs: styleLabeledCampUIDs
        )
    }

    /// The whole point: a camp the geojson names is a bare pin glyph at every zoom the style
    /// layer is painting at, however far in the user goes.
    func testPinOfAStyleLabeledCampNeverDrawsItsOwnName() {
        for zoomLevel in [15.0, 17.0, 18.0, 22.0] {
            XCTAssertTrue(pinLabelIsHidden(campUID: labeledCamp,
                                           zoomLevel: zoomLevel,
                                           styleLabeledCampUIDs: styleLabels),
                          "zoom \(zoomLevel)")
        }
    }

    /// The 8 camps with no footprint in the 2026 placement have no style label, so their pins
    /// keep the old zoom-gated behaviour or they'd be anonymous purple dots.
    func testPinOfACampTheStyleLayerDoesNotNameLabelsItself() {
        XCTAssertFalse(pinLabelIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: styleLabels))
        XCTAssertTrue(pinLabelIsHidden(campUID: unlabeledCamp,
                                       zoomLevel: 13,
                                       styleLabeledCampUIDs: styleLabels))
    }

    /// A year whose placement hasn't dropped ships an empty (or absent) `camp_labels.geojson`;
    /// every camp then labels itself, exactly as before this split existed.
    func testEveryCampLabelsItselfWhenTheGeojsonNamesNobody() {
        XCTAssertFalse(pinLabelIsHidden(campUID: labeledCamp, styleLabeledCampUIDs: []))
        XCTAssertFalse(pinLabelIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: []))
    }

    /// Whatever the geojson says, a layer that isn't painting can't be relied on: "Show Camp
    /// Names" off, or below the layer's minzoom, hands every camp back to its pin.
    func testEveryCampLabelsItselfWhenTheStyleLayerIsNotPainting() {
        XCTAssertFalse(pinLabelIsHidden(campUID: labeledCamp,
                                        styleDrawsCampNames: false,
                                        styleLabeledCampUIDs: styleLabels))
    }

    /// Art, events and map points are untouched by any of this — only the zoom cut applies.
    func testNonCampPinsKeepTheirLabels() {
        XCTAssertFalse(pinLabelIsHidden(campUID: nil, styleLabeledCampUIDs: styleLabels))
        XCTAssertTrue(pinLabelIsHidden(campUID: nil, zoomLevel: 13, styleLabeledCampUIDs: styleLabels))
        // …and a nil index (still loading) must not silently mute them either.
        XCTAssertFalse(pinLabelIsHidden(campUID: nil, styleLabeledCampUIDs: nil))
    }

    /// While the index is still loading, camps assume the layer has them: true for all but a
    /// handful, and the wrong guess in the other direction is a visible flash of doubled text.
    func testCampPinsYieldWhileTheIndexIsStillLoading() {
        XCTAssertTrue(pinLabelIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: nil))
        XCTAssertFalse(pinLabelIsHidden(campUID: unlabeledCamp,
                                        styleDrawsCampNames: false,
                                        styleLabeledCampUIDs: nil))
    }

    // MARK: - Which camps get a pin at all

    // Once the style label became a tap target in its own right, the purple glyph over it
    // was pure occlusion, so the browse map drops it. `CampPinVisibility` is the pure seam;
    // `UserMapViewAdapter.shouldDisplay` is its only caller, and the static data sources
    // behind "show on map" never go through it.

    private func pinIsHidden(campUID: String?,
                             isFavorite: Bool = false,
                             styleDrawsCampNames: Bool = true,
                             styleLabeledCampUIDs: Set<String>?) -> Bool {
        CampPinVisibility.pinIsHidden(
            campUID: campUID,
            isFavorite: isFavorite,
            styleDrawsCampNames: styleDrawsCampNames,
            styleLabeledCampUIDs: styleLabeledCampUIDs
        )
    }

    /// The point of the change: the layer's text replaces the pin outright.
    func testCampWithAStyleLabelGetsNoPin() {
        XCTAssertTrue(pinIsHidden(campUID: labeledCamp, styleLabeledCampUIDs: styleLabels))
    }

    /// The camps the geojson has no feature for are the ones with nothing else to name them.
    func testCampWithoutAStyleLabelKeepsItsPin() {
        XCTAssertFalse(pinIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: styleLabels))
    }

    /// A layer that isn't painting — off, embargoed, or below z15 — leaves the pin as the
    /// only way to see or open the camp, so it stays whatever the geojson says.
    func testEveryCampKeepsItsPinWhenTheStyleLayerIsNotPainting() {
        XCTAssertFalse(pinIsHidden(campUID: labeledCamp,
                                   styleDrawsCampNames: false,
                                   styleLabeledCampUIDs: styleLabels))
        XCTAssertFalse(pinIsHidden(campUID: unlabeledCamp,
                                   styleDrawsCampNames: false,
                                   styleLabeledCampUIDs: styleLabels))
    }

    /// A pre-placement year names nobody, and must not therefore hide everybody.
    func testEveryCampKeepsItsPinWhenTheGeojsonNamesNobody() {
        XCTAssertFalse(pinIsHidden(campUID: labeledCamp, styleLabeledCampUIDs: []))
        XCTAssertFalse(pinIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: []))
    }

    /// Opposite reading to `PinLabelVisibility`: a still-loading index must not empty the
    /// map. Pins that appear and then withdraw are a blink; camps that never arrive are a
    /// broken map. `UserMapViewAdapter` reloads when the parse lands.
    func testEveryCampKeepsItsPinWhileTheIndexIsStillLoading() {
        XCTAssertFalse(pinIsHidden(campUID: labeledCamp, styleLabeledCampUIDs: nil))
        XCTAssertFalse(pinIsHidden(campUID: unlabeledCamp, styleLabeledCampUIDs: nil))
    }

    /// Art, events, mutant vehicles and user map points have no style layer drawing them.
    func testNonCampPinsAreNeverSuppressed() {
        XCTAssertFalse(pinIsHidden(campUID: nil, styleLabeledCampUIDs: styleLabels))
        XCTAssertFalse(pinIsHidden(campUID: nil, styleLabeledCampUIDs: nil))
    }

    /// Every style label looks alike, so a starred camp keeps the one mark on the map that
    /// says it is starred — the more so because `showFavoritesOnMap` can be on while
    /// `showCampsOnMap` is off, which would otherwise leave favourites with no pin at all.
    func testFavoriteCampKeepsItsPinEvenWhenStyleLabeled() {
        XCTAssertFalse(pinIsHidden(campUID: labeledCamp,
                                   isFavorite: true,
                                   styleLabeledCampUIDs: styleLabels))
    }

    /// Suppression and self-labelling are the two halves of one rule: once the index has
    /// loaded, a camp pin is either gone (the layer names it) or drawing its own name (the
    /// layer doesn't) — never the bare glyph the old behaviour left sitting on the text.
    ///
    /// Only a loaded index is covered, because the two read `nil` deliberately differently
    /// and the overlap is the transient this leaves on purpose: for the length of one
    /// background read a labelled camp does show a bare glyph, rather than a missing camp.
    func testALoadedIndexLeavesEveryPinEitherSuppressedOrLabelled() {
        for campUID in [labeledCamp, unlabeledCamp] {
            for styleDrawsCampNames in [true, false] {
                for index in [styleLabels, []] {
                    let hidden = pinIsHidden(campUID: campUID,
                                             styleDrawsCampNames: styleDrawsCampNames,
                                             styleLabeledCampUIDs: index)
                    guard !hidden else { continue }
                    XCTAssertFalse(pinLabelIsHidden(campUID: campUID,
                                                    styleDrawsCampNames: styleDrawsCampNames,
                                                    styleLabeledCampUIDs: index),
                                   "\(campUID), drawing \(styleDrawsCampNames), index \(index)")
                }
            }
        }
    }

    // MARK: - Reading the label index out of the bundle

    func testLabelIndexCollectsEveryFeaturesUID() throws {
        let geojson = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"uid":"a1","name":"One"},
           "geometry":{"type":"Point","coordinates":[-119.2,40.7]}},
          {"type":"Feature","properties":{"uid":"a2","name":"Two"},
           "geometry":{"type":"Point","coordinates":[-119.3,40.8]}},
          {"type":"Feature","properties":{"name":"Anonymous"},
           "geometry":{"type":"Point","coordinates":[-119.4,40.9]}}
        ]}
        """
        let data = try XCTUnwrap(geojson.data(using: .utf8))
        XCTAssertEqual(CampStyleLabelIndex.parse(data), ["a1", "a2"])
    }

    /// A pre-placement year, and anything unreadable, degrade to "no camp is style-labeled" —
    /// which puts every name back under its pin rather than losing it.
    func testLabelIndexIsEmptyForMissingOrEmptyData() throws {
        let empty = try XCTUnwrap(#"{"type":"FeatureCollection","features":[]}"#.data(using: .utf8))
        XCTAssertEqual(CampStyleLabelIndex.parse(empty), [])
        XCTAssertEqual(CampStyleLabelIndex.parse(contentsOf: nil), [])
        let missing = URL(fileURLWithPath: "/nonexistent/camp_labels.geojson")
        XCTAssertEqual(CampStyleLabelIndex.parse(contentsOf: missing), [])
        let garbage = try XCTUnwrap("not json".data(using: .utf8))
        XCTAssertEqual(CampStyleLabelIndex.parse(garbage), [])
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
