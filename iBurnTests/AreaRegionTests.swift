//
//  AreaRegionTests.swift
//  iBurnTests
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import MapKit
@testable import iBurn
@testable import PlayaDB

final class AreaRegionTests: XCTestCase {

    func testCoordinateRegionFromBounds() {
        let region = coordinateRegion(swLat: 40.0, swLon: -120.0, neLat: 41.0, neLon: -119.0)
        XCTAssertEqual(region.center.latitude, 40.5, accuracy: 1e-9)
        XCTAssertEqual(region.center.longitude, -119.5, accuracy: 1e-9)
        XCTAssertEqual(region.span.latitudeDelta, 1.0, accuracy: 1e-9)
        XCTAssertEqual(region.span.longitudeDelta, 1.0, accuracy: 1e-9)
    }

    func testFilterRegionRoundTrip() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.04)
        )
        let round = FilterRegion(region).coordinateRegion
        XCTAssertEqual(round.center.latitude, region.center.latitude, accuracy: 1e-6)
        XCTAssertEqual(round.center.longitude, region.center.longitude, accuracy: 1e-6)
        XCTAssertEqual(round.span.latitudeDelta, region.span.latitudeDelta, accuracy: 1e-6)
        XCTAssertEqual(round.span.longitudeDelta, region.span.longitudeDelta, accuracy: 1e-6)
    }
}
