//
//  StreetLabelLayoutTests.swift
//  PlayaGeo
//
//  Created by Claude Code on 7/12/26.
//

import XCTest
@testable import PlayaGeo

final class StreetLabelLayoutTests: XCTestCase {
    private let wideBounds = CGRect(x: -1000, y: -1000, width: 2000, height: 2000)

    func testHorizontalLinePlacesAtIntervalSpacing() throws {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 240, y: 0)]
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: wideBounds)
        // Targets at 50, 150 fit on a 240pt path; 250 does not.
        XCTAssertEqual(placements.count, 2)
        let first = try XCTUnwrap(placements.first)
        let second = try XCTUnwrap(placements.last)
        XCTAssertEqual(first.point.x, 50, accuracy: 1e-9)
        XCTAssertEqual(second.point.x, 150, accuracy: 1e-9)
        XCTAssertEqual(first.point.y, 0, accuracy: 1e-9)
        XCTAssertEqual(first.angle, 0, accuracy: 1e-9)
        XCTAssertEqual(second.angle, 0, accuracy: 1e-9)
    }

    func testVerticalLineAngleNormalizedUpright() throws {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 200)]
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: wideBounds)
        let placement = try XCTUnwrap(placements.first)
        XCTAssertGreaterThan(placement.angle, -Double.pi / 2)
        XCTAssertLessThanOrEqual(placement.angle, Double.pi / 2)
        XCTAssertEqual(abs(placement.angle), Double.pi / 2, accuracy: 1e-9)
    }

    func testLeftwardHorizontalLineNormalizesToZero() throws {
        let line = [CGPoint(x: 200, y: 0), CGPoint(x: 0, y: 0)]
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: wideBounds)
        let placement = try XCTUnwrap(placements.first)
        XCTAssertEqual(placement.angle, 0, accuracy: 1e-9)
    }

    func testPlacementsOutsideBoundsAreDropped() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 400, y: 0)]
        // Only x in [100, 200] survives; targets are 50, 150, 250, 350.
        let bounds = CGRect(x: 100, y: -10, width: 100, height: 20)
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: bounds)
        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements.first?.point.x ?? -1, 150, accuracy: 1e-9)
    }

    func testFewerThanTwoPointsReturnsEmpty() {
        XCTAssertTrue(StreetLabelLayout.placements(along: [], interval: 100, bounds: wideBounds).isEmpty)
        XCTAssertTrue(
            StreetLabelLayout.placements(along: [CGPoint(x: 1, y: 1)], interval: 100, bounds: wideBounds).isEmpty
        )
    }

    func testPathShorterThanHalfIntervalReturnsEmpty() {
        let line = [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0)]
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: wideBounds)
        XCTAssertTrue(placements.isEmpty)
    }

    func testZeroLengthSegmentsAreSkippedWithoutNaN() throws {
        let line = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0, y: 0), // zero-length segment
            CGPoint(x: 200, y: 0),
            CGPoint(x: 200, y: 0), // another duplicate
        ]
        let placements = StreetLabelLayout.placements(along: line, interval: 100, bounds: wideBounds)
        XCTAssertEqual(placements.count, 2)
        for placement in placements {
            XCTAssertFalse(placement.point.x.isNaN)
            XCTAssertFalse(placement.point.y.isNaN)
            XCTAssertFalse(placement.angle.isNaN)
        }
        let first = try XCTUnwrap(placements.first)
        XCTAssertEqual(first.point.x, 50, accuracy: 1e-9)
    }
}
