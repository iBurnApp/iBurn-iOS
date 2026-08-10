//
//  MapFramingCoordinateTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the rule that gives a map a second point to frame alongside a lone destination:
//  the user when they are on playa, the Man when they are not. Shared by the detail screen's
//  small map (`brc_showDestination`) and the full map pushed from it (`MapListViewController`),
//  so a single pin never zooms in to a featureless patch of desert.
//

import CoreLocation
import XCTest
@testable import iBurn

final class MapFramingCoordinateTests: XCTestCase {

    /// Roughly the Man — the center of `burningManRegion`.
    private var man: CLLocationCoordinate2D { BRCLocations.blackRockCityCenter }

    private func assertSameCoordinate(
        _ lhs: CLLocationCoordinate2D,
        _ rhs: CLLocationCoordinate2D,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.latitude, rhs.latitude, accuracy: 0.000_001, message, file: file, line: line)
        XCTAssertEqual(lhs.longitude, rhs.longitude, accuracy: 0.000_001, message, file: file, line: line)
    }

    // MARK: - On playa

    func testUserInsideTheRegionIsTheFramingCoordinate() {
        // Deep playa, comfortably inside the 5-mile circle.
        let onPlaya = CLLocation(latitude: 40.7900, longitude: -119.2000)

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: onPlaya),
            onPlaya.coordinate,
            "On playa the map frames the destination against the user"
        )
    }

    func testUserStandingOnTheManIsTheFramingCoordinate() {
        let atTheMan = CLLocation(latitude: man.latitude, longitude: man.longitude)

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: atTheMan),
            man,
            "The center of the region counts as inside it"
        )
    }

    func testAFewMilesOutIsStillInsideTheRegion() {
        // ~2 miles north of the Man: outside the city, well inside the 5-mile region.
        let outerPlaya = CLLocation(latitude: 40.8154, longitude: -119.2065)
        XCTAssertTrue(BRCLocations.burningManRegion.contains(outerPlaya.coordinate),
                      "Precondition: this fixture is inside the region")

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: outerPlaya),
            outerPlaya.coordinate,
            "Anywhere inside the region still frames against the user"
        )
    }

    // MARK: - Off playa

    func testUserOutsideTheRegionFallsBackToTheMan() {
        // San Francisco: the "planning from home" case, where framing the user with the
        // destination would shrink the destination to an invisible speck.
        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)
        XCTAssertFalse(BRCLocations.burningManRegion.contains(offPlaya.coordinate),
                       "Precondition: this fixture is outside the region")

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: offPlaya),
            man,
            "Off playa the map frames the destination against the Man instead"
        )
    }

    func testJustOutsideTheRegionAlreadyFallsBackToTheMan() {
        // Reno-ward, ~50 miles out: no longer a useful second point.
        let nearby = CLLocation(latitude: 40.3000, longitude: -119.2065)
        XCTAssertFalse(BRCLocations.burningManRegion.contains(nearby.coordinate),
                       "Precondition: this fixture is outside the region")

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: nearby),
            man,
            "The 5-mile region is the only line that matters, not \"is it the same state\""
        )
    }

    // MARK: - No fix

    func testNoLocationFallsBackToTheMan() {
        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: nil),
            man,
            "With no fix at all there is no user to frame against"
        )
    }

    func testInvalidLocationFallsBackToTheMan() {
        // What Core Location hands back before it has ever had a fix.
        let invalid = CLLocation(latitude: -180, longitude: -180)
        XCTAssertFalse(CLLocationCoordinate2DIsValid(invalid.coordinate),
                       "Precondition: this fixture is not a valid coordinate")

        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: invalid),
            man,
            "An invalid coordinate is treated as no fix, not as a point to fit"
        )
    }
}
