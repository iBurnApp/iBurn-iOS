//
//  UserMapPinLifecycleTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Drives `UserMapViewAdapter` through the pin lifecycle that produced the duplicated
//  bike/home/star pins: place a pin, let the save's own observation come back, reload
//  again. The map itself is real (`MLNMapView`) but never rendered — all these assertions
//  read is how many annotations are on it.
//

import CoreLocation
import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn
@testable import PlayaDB

/// A data source whose contents the test can swap, standing in for the PlayaDB
/// observation behind `FilteredMapDataSource`.
private final class MutableAnnotationDataSource: NSObject, AnnotationDataSource {
    var annotations: [MLNAnnotation] = []
    func allAnnotations() -> [MLNAnnotation] { annotations }
}

@MainActor
final class UserMapPinLifecycleTests: XCTestCase {

    private let coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)

    private func makeAdapter() throws -> (UserMapViewAdapter, MLNMapView, MutableAnnotationDataSource) {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        let mapView = MLNMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let dataSource = MutableAnnotationDataSource()
        let adapter = UserMapViewAdapter(mapView: mapView, dataSource: dataSource, playaDB: playaDB)
        return (adapter, mapView, dataSource)
    }

    private func userPins(on mapView: MLNMapView) -> [BRCUserMapPoint] {
        (mapView.annotations ?? []).compactMap { $0 as? BRCUserMapPoint }
    }

    /// The copy the observation would deliver for a pin that has just been written.
    private func databaseCopy(of point: BRCUserMapPoint) -> BRCUserMapPoint {
        BRCUserMapPoint(
            userMapPin: UserMapPin(
                id: point.pinId,
                title: point.title,
                latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude,
                pinType: point.type.pinTypeString
            )
        )
    }

    // MARK: - Placement

    func testPlacingAPinPutsExactlyOneOnTheMap() throws {
        let (adapter, mapView, _) = try makeAdapter()

        adapter.editMapPoint(BRCUserMapPoint(title: "Bike", coordinate: coordinate, type: .userBike))

        XCTAssertEqual(userPins(on: mapView).count, 1)
        XCTAssertTrue(adapter.hasUnsavedPlacement, "nothing has been written yet")
    }

    func testDatabaseCopyReplacesThePlacedPinInsteadOfStackingOnIt() throws {
        let (adapter, mapView, dataSource) = try makeAdapter()
        let placed = BRCUserMapPoint(title: "Bike", coordinate: coordinate, type: .userBike)
        adapter.editMapPoint(placed)

        // Save committed: `observeUserMapPins` fires and the data source now publishes the
        // row as a brand-new object with the same `pinId`.
        let fromDatabase = databaseCopy(of: placed)
        dataSource.annotations = [fromDatabase]
        adapter.reloadAnnotations()

        let pins = userPins(on: mapView)
        XCTAssertEqual(pins.count, 1, "two stacked pins is the reported bug")
        XCTAssertTrue(pins.first === fromDatabase, "the database's copy is the one that stays")
        XCTAssertFalse(adapter.hasUnsavedPlacement)
    }

    func testFurtherReloadsKeepExactlyOnePinPerRow() throws {
        let (adapter, mapView, dataSource) = try makeAdapter()
        let placed = BRCUserMapPoint(title: "Bike", coordinate: coordinate, type: .userBike)
        adapter.editMapPoint(placed)
        dataSource.annotations = [databaseCopy(of: placed)]
        adapter.reloadAnnotations()

        // Every unrelated write — a favorite toggle, a Map Filter change — rebuilds the
        // pin objects from scratch and reloads.
        for _ in 0..<4 {
            dataSource.annotations = [databaseCopy(of: placed)]
            adapter.reloadAnnotations()
            XCTAssertEqual(userPins(on: mapView).count, 1)
        }
    }

    func testSeveralStarsCoexist() throws {
        let (adapter, mapView, dataSource) = try makeAdapter()
        let stars = (0..<3).map { index in
            BRCUserMapPoint(
                title: "Star \(index)",
                coordinate: CLLocationCoordinate2D(
                    latitude: coordinate.latitude + Double(index) * 0.001,
                    longitude: coordinate.longitude
                ),
                type: .userStar
            )
        }

        dataSource.annotations = stars.map { databaseCopy(of: $0) }
        adapter.reloadAnnotations()

        XCTAssertEqual(userPins(on: mapView).count, 3)
    }

    // MARK: - Editing an existing pin

    /// A star, because `BRCMapPoint.title` hard-codes "Home"/"Bike" for those two types —
    /// only stars carry the name the user typed.
    func testEditingAPinFromTheMapDoesNotDuplicateIt() throws {
        let (adapter, mapView, dataSource) = try makeAdapter()
        let existing = databaseCopy(of: BRCUserMapPoint(title: "Old name", coordinate: coordinate, type: .userStar))
        dataSource.annotations = [existing]
        adapter.reloadAnnotations()

        // The callout's pencil hands back the pin already on the map.
        adapter.editMapPoint(existing)

        XCTAssertEqual(userPins(on: mapView).count, 1)
        XCTAssertFalse(adapter.hasUnsavedPlacement, "an existing pin belongs to the data source")

        // Renaming writes the row; the observation republishes it.
        existing.title = "New name"
        dataSource.annotations = [databaseCopy(of: existing)]
        adapter.reloadAnnotations()

        let pins = userPins(on: mapView)
        XCTAssertEqual(pins.count, 1)
        XCTAssertEqual(pins.first?.title, "New name")
    }

    // MARK: - Reveal

    func testRevealSelectsThePinOnTheMapNotTheDatabaseCopy() throws {
        let (adapter, mapView, dataSource) = try makeAdapter()
        let onMap = databaseCopy(of: BRCUserMapPoint(title: "Bike", coordinate: coordinate, type: .userBike))
        dataSource.annotations = [onMap]
        adapter.reloadAnnotations()

        // What `UserGuidance.findNearest` returns: a separate object for the same row.
        let answer = BRCUserMapPoint(
            userMapPin: UserMapPin(
                id: onMap.pinId,
                title: "Bike",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                pinType: BRCMapPointType.userBike.pinTypeString
            )
        )
        adapter.revealUserMapPoint(answer)

        XCTAssertEqual(userPins(on: mapView).count, 1, "revealing must never add a second pin")
        XCTAssertTrue(
            mapView.selectedAnnotations.first === onMap,
            "the instance drawn on the map is the one that gets selected"
        )
    }
}
