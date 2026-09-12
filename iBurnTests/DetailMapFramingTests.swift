//
//  DetailMapFramingTests.swift
//  iBurnTests
//
//  Copyright (c) 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import CoreLocation
import MapLibre
@testable import iBurn

/// Rules behind the detail screen's embedded mini map camera. The regression these guard is
/// a preview stuck at the default whole-city zoom because the "map is ready" signal never
/// arrived — see `DetailMapViewRepresentable.Coordinator`.
final class DetailMapFramingTests: XCTestCase {

    private func readyState() -> DetailMapFramingState {
        var state = DetailMapFramingState()
        state.hasNonZeroBounds = true
        state.isMapReady = true
        state.hasAnnotation = true
        return state
    }

    // MARK: - Initial framing

    func testFramesOnceEverythingIsReady() {
        XCTAssertTrue(DetailMapFramingState.shouldFrame(readyState()))
    }

    func testDoesNotFrameBeforeLayout() {
        var state = readyState()
        state.hasNonZeroBounds = false
        XCTAssertFalse(DetailMapFramingState.shouldFrame(state))
    }

    func testDoesNotFrameBeforeMapIsReady() {
        var state = readyState()
        state.isMapReady = false
        XCTAssertFalse(DetailMapFramingState.shouldFrame(state))
    }

    func testDoesNotFrameTwice() {
        var state = readyState()
        state.hasFramed = true
        XCTAssertFalse(DetailMapFramingState.shouldFrame(state))
    }

    /// No pin still gets a camera move — the fallback centers on the city rather than
    /// leaving the preview wherever it happened to be.
    func testFramesWithoutAnnotation() {
        var state = readyState()
        state.hasAnnotation = false
        XCTAssertTrue(DetailMapFramingState.shouldFrame(state))
    }

    // MARK: - Re-framing when a fix arrives

    func testReframesOnFirstOnPlayaFix() {
        var state = readyState()
        state.hasFramed = true
        XCTAssertTrue(DetailMapFramingState.shouldReframeForUserLocation(state, userLocationFramesAroundUser: true))
    }

    func testDoesNotReframeWhenFixIsOffPlaya() {
        var state = readyState()
        state.hasFramed = true
        XCTAssertFalse(DetailMapFramingState.shouldReframeForUserLocation(state, userLocationFramesAroundUser: false))
    }

    func testDoesNotReframeAgainOnLaterFixes() {
        var state = readyState()
        state.hasFramed = true
        state.framedWithUserLocation = true
        XCTAssertFalse(DetailMapFramingState.shouldReframeForUserLocation(state, userLocationFramesAroundUser: true))
    }

    func testDoesNotReframeBeforeInitialFraming() {
        let state = readyState()
        XCTAssertFalse(DetailMapFramingState.shouldReframeForUserLocation(state, userLocationFramesAroundUser: true))
    }

    func testDoesNotReframeWithoutAPinToFrameAgainst() {
        var state = readyState()
        state.hasAnnotation = false
        state.hasFramed = true
        XCTAssertFalse(DetailMapFramingState.shouldReframeForUserLocation(state, userLocationFramesAroundUser: true))
    }

    // MARK: - framesAroundUser

    func testNoFixDoesNotFrameAroundUser() {
        XCTAssertFalse(DetailMapFramingState.framesAroundUser(nil))
    }

    func testOnPlayaFixFramesAroundUser() {
        let man = BRCLocations.blackRockCityCenter
        let nearby = CLLocation(latitude: man.latitude + 0.005, longitude: man.longitude + 0.005)
        XCTAssertTrue(DetailMapFramingState.framesAroundUser(nearby))
    }

    func testFarAwayFixDoesNotFrameAroundUser() {
        // San Francisco — well outside the 5 mile `burningManRegion`.
        let sanFrancisco = CLLocation(latitude: 37.7749, longitude: -122.4194)
        XCTAssertFalse(DetailMapFramingState.framesAroundUser(sanFrancisco))
    }

    // MARK: - Annotation equivalence

    func testNilAnnotationsAreEquivalent() {
        XCTAssertTrue(DetailMapFramingState.isEquivalent(nil, nil))
    }

    func testNilAndNonNilAreNotEquivalent() {
        let annotation = MLNPointAnnotation()
        annotation.coordinate = BRCLocations.blackRockCityCenter
        XCTAssertFalse(DetailMapFramingState.isEquivalent(annotation, nil))
        XCTAssertFalse(DetailMapFramingState.isEquivalent(nil, annotation))
    }

    /// The `dataObject` initializer mints a fresh annotation on every SwiftUI update, so two
    /// distinct objects describing the same pin must not count as a change.
    func testDistinctAnnotationsForSamePinAreEquivalent() {
        let first = MLNPointAnnotation()
        first.coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        first.title = "Camp Nowhere"
        let second = MLNPointAnnotation()
        second.coordinate = first.coordinate
        second.title = "Camp Nowhere"
        XCTAssertTrue(DetailMapFramingState.isEquivalent(first, second))
    }

    func testDifferentCoordinatesAreNotEquivalent() {
        let first = MLNPointAnnotation()
        first.coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        first.title = "Camp Nowhere"
        let second = MLNPointAnnotation()
        second.coordinate = CLLocationCoordinate2D(latitude: 40.7900, longitude: -119.2065)
        second.title = "Camp Nowhere"
        XCTAssertFalse(DetailMapFramingState.isEquivalent(first, second))
    }

    func testDifferentTitlesAreNotEquivalent() {
        let first = MLNPointAnnotation()
        first.coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        first.title = "Camp Nowhere"
        let second = MLNPointAnnotation()
        second.coordinate = first.coordinate
        second.title = "Camp Somewhere"
        XCTAssertFalse(DetailMapFramingState.isEquivalent(first, second))
    }
}
