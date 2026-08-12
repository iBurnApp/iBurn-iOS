//
//  PlayaDistanceStringTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import XCTest
@testable import iBurn

/// The one seam every list row's walk/bike estimate passes through.
///
/// Two rules are under test, and both were being broken on shipping screens:
/// a locked camp rendered "🚶🏽 28m 🚴🏽 10m" beside its own "Location Restricted" row, and
/// an art record with unset coordinates (null island) rendered "🚶🏽 4,832h 58m".
final class PlayaDistanceStringTests: XCTestCase {

    /// Roughly the middle of Black Rock City — where the simulator was pinned when the
    /// screenshots that surfaced these bugs were taken.
    private let user = CLLocation(latitude: 40.7864, longitude: -119.2065)

    /// About 600 m away: a normal across-the-city walk.
    private let nearby = CLLocation(latitude: 40.7918, longitude: -119.2065)

    /// The coordinates an unplaced record carries: (0, 0), some 12,400 km off.
    private let nullIsland = CLLocation(latitude: 0, longitude: 0)

    // MARK: - Embargo gate

    func testUnlockedNearbyObjectRendersAnEstimate() throws {
        let string = try XCTUnwrap(
            PlayaDistanceString.make(from: user, to: nearby, canShowLocation: true)
        )
        let text = String(string.characters)
        XCTAssertTrue(text.contains("🚶🏽"), "expected a walking estimate in \(text)")
        XCTAssertTrue(text.contains("🚴🏽"), "expected a biking estimate in \(text)")
    }

    /// A distance narrows placement exactly as an address does, so while the item's tier is
    /// locked the row gets no fragment at all — not a masked one.
    func testLockedObjectRendersNothing() {
        XCTAssertNil(PlayaDistanceString.make(from: user, to: nearby, canShowLocation: false))
    }

    func testNoUserFixRendersNothing() {
        XCTAssertNil(PlayaDistanceString.make(from: nil, to: nearby, canShowLocation: true))
    }

    func testNoObjectPlacementRendersNothing() {
        XCTAssertNil(PlayaDistanceString.make(from: user, to: nil, canShowLocation: true))
    }

    // MARK: - Plausibility clamp

    /// The `ARI` / `A Path thru ( to Now)` case: coordinates never set, so the record sits
    /// at (0, 0) and the honest arithmetic produces a four-thousand-hour walk.
    func testNullIslandRendersNothing() {
        XCTAssertNil(PlayaDistanceString.make(from: user, to: nullIsland, canShowLocation: true))
    }

    func testDistanceJustInsideTheClampStillRenders() throws {
        let inside = CLLocation(latitude: 40.7864, longitude: -119.2065)
            .offsetNorth(by: PlayaDistanceString.maxPlausibleDistance - 1_000)
        let string = try XCTUnwrap(
            PlayaDistanceString.make(from: user, to: inside, canShowLocation: true)
        )
        XCTAssertFalse(String(string.characters).isEmpty)
    }

    func testDistanceJustOutsideTheClampRendersNothing() {
        let outside = CLLocation(latitude: 40.7864, longitude: -119.2065)
            .offsetNorth(by: PlayaDistanceString.maxPlausibleDistance + 1_000)
        XCTAssertNil(PlayaDistanceString.make(from: user, to: outside, canShowLocation: true))
    }

    /// Reno is a real place a user might open the app from; it is still not walkable.
    func testOffPlayaUserGetsNothing() {
        let reno = CLLocation(latitude: 39.5296, longitude: -119.8138)
        XCTAssertNil(PlayaDistanceString.make(from: reno, to: nearby, canShowLocation: true))
    }

    // MARK: - Predicate

    func testIsPlausibleBoundaries() {
        XCTAssertTrue(PlayaDistanceString.isPlausible(0))
        XCTAssertTrue(PlayaDistanceString.isPlausible(PlayaDistanceString.maxPlausibleDistance))
        XCTAssertFalse(PlayaDistanceString.isPlausible(PlayaDistanceString.maxPlausibleDistance + 1))
        XCTAssertFalse(PlayaDistanceString.isPlausible(.infinity))
        XCTAssertFalse(PlayaDistanceString.isPlausible(.nan))
        XCTAssertFalse(PlayaDistanceString.isPlausible(-1))
    }
}

private extension CLLocation {
    /// Same longitude, `meters` further north — close enough for a boundary check.
    func offsetNorth(by meters: CLLocationDistance) -> CLLocation {
        let metersPerDegreeLatitude: CLLocationDistance = 111_320
        return CLLocation(
            latitude: coordinate.latitude + meters / metersPerDegreeLatitude,
            longitude: coordinate.longitude
        )
    }
}
