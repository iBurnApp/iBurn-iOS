//
//  MockDataShipGuardTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn

/// Guards against shipping mock placement fixtures.
///
/// `Submodules/iBurn-Data/scripts/mock_locations.js` fabricates camp/art
/// locations from the previous year's data for pre-drop testing. It marks the
/// bundle with a MOCK_LOCATIONS sentinel file (and the map geojson fixtures
/// carry a previous-year `name` property). These tests fail the build while
/// any marker is present, so mock data cannot reach TestFlight/App Store;
/// `playa-seed` and the deploy workflow have the same checks.
final class MockDataShipGuardTests: XCTestCase {

    func testBundledAPIDataHasNoMockSentinel() {
        let sentinelPath = (Bundle.brc_dataBundle.bundlePath as NSString)
            .appendingPathComponent("MOCK_LOCATIONS")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: sentinelPath),
            "APIData.bundle contains mock placement data. Revert with: " +
            "node scripts/mock_locations.js revert (in Submodules/iBurn-Data)"
        )
    }

    func testBundledCampGeojsonIsNotPreviousYearFixture() throws {
        for resource in ["camp_outlines", "camp_labels"] {
            guard let url = Bundle.brc_mapBundle.url(forResource: resource, withExtension: "geojson") else {
                continue // absent is fine — the style just renders nothing
            }
            let contents = try String(contentsOf: url, encoding: .utf8)
            // The map-fixture path copies last year's QGIS exports, whose
            // FeatureCollections are named e.g. "camp_outlines_2025".
            XCTAssertFalse(
                contents.contains("\(resource)_2025"),
                "\(resource).geojson is last year's fixture — revert mock_locations.js before shipping"
            )
        }
    }
}
