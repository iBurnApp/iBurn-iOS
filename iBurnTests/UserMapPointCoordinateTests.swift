//
//  UserMapPointCoordinateTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers where a bike / home / star pin lands when the user drops one: on them when they're
//  on playa, in the middle of the map they're looking at when they aren't. Same 5-mile
//  `burningManRegion` line as `mapFramingCoordinate(forUserLocation:)`, different fallback —
//  a pin has to be somewhere the user can see and drag, which the viewport center always is.
//

import CoreLocation
import XCTest
@testable import iBurn

final class UserMapPointCoordinateTests: XCTestCase {

    private var man: CLLocationCoordinate2D { BRCLocations.blackRockCityCenter }

    /// Where the map sits after the user pans to the city to plan from home — the fallback
    /// under test.
    private let viewport = CLLocationCoordinate2D(latitude: 40.7800, longitude: -119.2100)

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

    func testOnPlayaThePinLandsOnTheUser() {
        let onPlaya = CLLocation(latitude: 40.7900, longitude: -119.2000)

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: onPlaya, viewportCenter: viewport),
            onPlaya.coordinate,
            "\"My bike is where I'm standing\" is the whole point of the button"
        )
    }

    func testAPannedAwayMapDoesNotStealThePinFromAUserOnPlaya() {
        let onPlaya = CLLocation(latitude: 40.7900, longitude: -119.2000)
        // The user has scrolled off to look at something else before tapping.
        let elsewhere = CLLocationCoordinate2D(latitude: 40.8100, longitude: -119.1800)

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: onPlaya, viewportCenter: elsewhere),
            onPlaya.coordinate,
            "A real fix always wins over the viewport"
        )
    }

    func testStandingOnTheManCountsAsOnPlaya() {
        let atTheMan = CLLocation(latitude: man.latitude, longitude: man.longitude)

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: atTheMan, viewportCenter: viewport),
            man,
            "The center of the region counts as inside it"
        )
    }

    // MARK: - Off playa

    func testOffPlayaThePinLandsInTheMiddleOfTheMap() {
        // San Francisco: the bug this fixes put the pin here, hundreds of miles off screen.
        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)
        XCTAssertFalse(BRCLocations.burningManRegion.contains(offPlaya.coordinate),
                       "Precondition: this fixture is outside the region")

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: offPlaya, viewportCenter: viewport),
            viewport,
            "Off playa the pin goes where the user is looking, not where their phone is"
        )
    }

    func testTheFallbackFollowsTheViewportRatherThanTheMan() {
        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let panned = CLLocationCoordinate2D(latitude: 40.7712, longitude: -119.2250)

        let placed = BRCLocations.userMapPointCoordinate(forUserLocation: offPlaya, viewportCenter: panned)
        assertSameCoordinate(placed, panned, "Whatever is centered on screen is the fallback")
        XCTAssertNotEqual(placed.latitude, man.latitude, accuracy: 0.000_001,
                          "Specifically not the old blackRockCityCenter fallback")
    }

    /// Even a viewport nowhere near the playa is still what the user can see and drag, so it
    /// is used unconditionally.
    func testAnOffPlayaViewportIsStillUsed() {
        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)
        let offPlayaViewport = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: offPlaya, viewportCenter: offPlayaViewport),
            offPlayaViewport,
            "There is no better answer than the map in front of them"
        )
    }

    // MARK: - No fix

    func testNoLocationFallsBackToTheViewport() {
        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: nil, viewportCenter: viewport),
            viewport,
            "With no fix at all there is no user to drop the pin on"
        )
    }

    func testInvalidLocationFallsBackToTheViewport() {
        let invalid = CLLocation(latitude: -180, longitude: -180)
        XCTAssertFalse(CLLocationCoordinate2DIsValid(invalid.coordinate),
                       "Precondition: this fixture is not a valid coordinate")

        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: invalid, viewportCenter: viewport),
            viewport,
            "An invalid coordinate is treated as no fix"
        )
    }

    // MARK: - Relationship to the framing rule

    /// Both rules draw the same line; only the off-playa answer differs, because framing a
    /// destination and placing a pin want different things from a user who isn't there.
    func testBothRulesAgreeOnPlayaAndDivergeOffIt() {
        let onPlaya = CLLocation(latitude: 40.7900, longitude: -119.2000)
        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: onPlaya, viewportCenter: viewport),
            BRCLocations.mapFramingCoordinate(forUserLocation: onPlaya),
            "On playa both rules are just the user"
        )

        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)
        assertSameCoordinate(
            BRCLocations.mapFramingCoordinate(forUserLocation: offPlaya),
            man,
            "Framing falls back to the Man"
        )
        assertSameCoordinate(
            BRCLocations.userMapPointCoordinate(forUserLocation: offPlaya, viewportCenter: viewport),
            viewport,
            "Pin placement falls back to the viewport"
        )
    }
}
