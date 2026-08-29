//
//  InvalidCoordinateGuardTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the layers that keep a non-finite coordinate away from MapLibre. A NaN
//  annotation coordinate is projected straight into a `CALayer.position`, which throws
//  `CALayerInvalidGeometry` and takes the app down — the 2026.0 (109) crash in
//  `MapViewAdapter.addAnnotations` reached by tapping "place pin" while the map's bounds
//  were still degenerate, so `MLNMapView.centerCoordinate` answered NaN.
//

import CoreLocation
import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn

@MainActor
final class InvalidCoordinateGuardTests: XCTestCase {

    private let nanCenter = CLLocationCoordinate2D(latitude: .nan, longitude: .nan)
    private let goodCoordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)

    private var man: CLLocationCoordinate2D { BRCLocations.blackRockCityCenter }

    // MARK: - isUsable

    func testNonFiniteCoordinatesAreNotUsable() {
        XCTAssertFalse(BRCLocations.isUsable(nanCenter))
        XCTAssertFalse(BRCLocations.isUsable(CLLocationCoordinate2D(latitude: 40.78, longitude: .nan)))
        XCTAssertFalse(BRCLocations.isUsable(CLLocationCoordinate2D(latitude: .infinity, longitude: -119.2)))
        XCTAssertFalse(BRCLocations.isUsable(kCLLocationCoordinate2DInvalid))
        XCTAssertTrue(BRCLocations.isUsable(goodCoordinate))
    }

    // MARK: - BRCLocations.userMapPointCoordinate

    func testNaNViewportCenterFallsBackToTheMan() {
        let placed = BRCLocations.userMapPointCoordinate(forUserLocation: nil, viewportCenter: nanCenter)

        XCTAssertTrue(BRCLocations.isUsable(placed), "A pin coordinate must never be NaN")
        XCTAssertEqual(placed.latitude, man.latitude, accuracy: 0.000_001)
        XCTAssertEqual(placed.longitude, man.longitude, accuracy: 0.000_001)
    }

    func testNaNViewportCenterStillLosesToAnOnPlayaFix() {
        let onPlaya = CLLocation(latitude: 40.7900, longitude: -119.2000)

        let placed = BRCLocations.userMapPointCoordinate(forUserLocation: onPlaya, viewportCenter: nanCenter)

        XCTAssertEqual(placed.latitude, onPlaya.coordinate.latitude, accuracy: 0.000_001)
        XCTAssertEqual(placed.longitude, onPlaya.coordinate.longitude, accuracy: 0.000_001)
    }

    func testAnOffPlayaFixWithANaNViewportFallsBackToTheMan() {
        let offPlaya = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let placed = BRCLocations.userMapPointCoordinate(forUserLocation: offPlaya, viewportCenter: nanCenter)

        XCTAssertEqual(placed.latitude, man.latitude, accuracy: 0.000_001,
                       "With no usable viewport the city center is the only safe answer")
    }

    func testAUsableViewportIsStillReturnedUnchanged() {
        let viewport = CLLocationCoordinate2D(latitude: 40.7800, longitude: -119.2100)

        let placed = BRCLocations.userMapPointCoordinate(forUserLocation: nil, viewportCenter: viewport)

        XCTAssertEqual(placed.latitude, viewport.latitude, accuracy: 0.000_001)
        XCTAssertEqual(placed.longitude, viewport.longitude, accuracy: 0.000_001)
    }

    // MARK: - BRCMapPoint.coordinate

    func testAMapPointBuiltFromNaNReportsAnInvalidCoordinate() {
        let point = BRCUserMapPoint(title: "Bike", coordinate: nanCenter, type: .userBike)

        XCTAssertFalse(CLLocationCoordinate2DIsValid(point.coordinate),
                       "The model sanitizes NaN rather than passing it to the map")
        XCTAssertNil(point.location())
    }

    func testAMapPointBuiltFromAnUnsetCoordinateIsStillInvalid() {
        let point = BRCUserMapPoint(title: "Bike",
                                    coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                    type: .userBike)

        XCTAssertFalse(CLLocationCoordinate2DIsValid(point.coordinate))
    }

    func testAValidMapPointKeepsItsCoordinate() throws {
        let point = BRCUserMapPoint(title: "Bike", coordinate: goodCoordinate, type: .userBike)

        XCTAssertTrue(CLLocationCoordinate2DIsValid(point.coordinate))
        XCTAssertEqual(point.coordinate.latitude, goodCoordinate.latitude, accuracy: 0.000_001)
        let location = try XCTUnwrap(point.location())
        XCTAssertEqual(location.coordinate.longitude, goodCoordinate.longitude, accuracy: 0.000_001)
    }

    // MARK: - MapViewAdapter

    private func makeAdapter() -> (MapViewAdapter, MLNMapView) {
        let mapView = MLNMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        return (MapViewAdapter(mapView: mapView), mapView)
    }

    func testAnInvalidAnnotationNeverReachesTheMap() {
        let (adapter, mapView) = makeAdapter()

        adapter.addAnnotations([BRCUserMapPoint(title: "Bike", coordinate: nanCenter, type: .userBike)])

        XCTAssertTrue((mapView.annotations ?? []).isEmpty)
        XCTAssertEqual(adapter.registry.count, 0,
                       "The registry must not hold a key for a pin the map isn't drawing")
    }

    func testAValidAnnotationAlongsideAnInvalidOneIsStillAdded() {
        let (adapter, mapView) = makeAdapter()
        let good = BRCUserMapPoint(title: "Home", coordinate: goodCoordinate, type: .userHome)

        adapter.addAnnotations([
            BRCUserMapPoint(title: "Bike", coordinate: nanCenter, type: .userBike),
            good
        ])

        let onMap = (mapView.annotations ?? []).compactMap { $0 as? BRCUserMapPoint }
        XCTAssertEqual(onMap.count, 1)
        XCTAssertTrue(onMap.first === good)
        XCTAssertEqual(adapter.registry.count, 1)
    }

    /// Because the reject happens before registration, a later good copy of the same pin
    /// isn't locked out by a key the registry took for a pin that never made it onto the map.
    func testAGoodCopyOfARejectedPinCanStillBeAdded() {
        let (adapter, mapView) = makeAdapter()
        let broken = BRCUserMapPoint(title: "Bike", coordinate: nanCenter, type: .userBike)
        adapter.addAnnotations([broken])

        let fixed = BRCUserMapPoint(title: "Bike", coordinate: goodCoordinate, type: .userBike)
        fixed.pinId = broken.pinId
        adapter.addAnnotations([fixed])

        XCTAssertEqual((mapView.annotations ?? []).compactMap { $0 as? BRCUserMapPoint }.count, 1)
    }
}
