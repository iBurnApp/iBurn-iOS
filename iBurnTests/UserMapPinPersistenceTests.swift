//
//  UserMapPinPersistenceTests.swift
//  iBurnTests
//
//  The map's own save/delete paths, driven against a real on-disk PlayaDB, so a pin
//  the user places, moves or deletes is asserted to have actually reached
//  `user_map_pins` — which is what has to survive a relaunch. `UserMapPinLifecycleTests`
//  covers what the *map* shows; this covers what the database ends up holding.
//

import CoreLocation
import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn
@testable import PlayaDB

private final class PersistenceAnnotationDataSource: NSObject, AnnotationDataSource {
    var annotations: [MLNAnnotation] = []
    func allAnnotations() -> [MLNAnnotation] { annotations }
}

@MainActor
final class UserMapPinPersistenceTests: XCTestCase {

    private let coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)

    private func makeAdapter() throws -> (UserMapViewAdapter, MLNMapView, PersistenceAnnotationDataSource, PlayaDBImpl) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pin-persist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let db = try PlayaDBImpl(dbPath: dir.appendingPathComponent("PlayaDB.sqlite").path)
        let mapView = MLNMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let ds = PersistenceAnnotationDataSource()
        let adapter = UserMapViewAdapter(mapView: mapView, dataSource: ds, playaDB: db)
        return (adapter, mapView, ds, db)
    }

    private func pins(in db: PlayaDBImpl, expected: Int, timeout: TimeInterval = 3) async throws -> [UserMapPin] {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = try await db.fetchUserMapPins()
        while latest.count != expected, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            latest = try await db.fetchUserMapPins()
        }
        return latest
    }

    func testPlacingAPinWritesARow() async throws {
        let (adapter, mapView, _, db) = try makeAdapter()
        let point = BRCUserMapPoint(title: "Star", coordinate: coordinate, type: .userStar)
        adapter.editMapPoint(point)
        adapter.mapView(mapView, didDeselect: point)

        let rows = try await pins(in: db, expected: 1)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, point.pinId)
    }

    func testMovingAPinFromTheDatabaseUpdatesItsRow() async throws {
        let (adapter, mapView, ds, db) = try makeAdapter()
        // Row already in the database, as at launch.
        let existingPin = UserMapPin(
            title: "Star",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pinType: BRCMapPointType.userStar.pinTypeString
        )
        try await db.saveUserMapPin(existingPin)

        let onMap = BRCUserMapPoint(userMapPin: existingPin)
        ds.annotations = [onMap]
        adapter.reloadAnnotations()

        adapter.editMapPoint(onMap)
        let moved = CLLocationCoordinate2D(latitude: coordinate.latitude + 0.01, longitude: coordinate.longitude + 0.01)
        onMap.coordinate = moved
        adapter.mapView(mapView, didDeselect: onMap)

        var rows = try await pins(in: db, expected: 1)
        let deadline = Date().addingTimeInterval(3)
        while (rows.first?.latitude ?? 0) != moved.latitude, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            rows = try await db.fetchUserMapPins()
        }
        XCTAssertEqual(rows.count, 1, "the move must not create a second row")
        XCTAssertEqual(rows.first?.latitude ?? 0, moved.latitude, accuracy: 1e-9)
        XCTAssertEqual(rows.first?.longitude ?? 0, moved.longitude, accuracy: 1e-9)
    }

    /// The reported bug: the map writes back the `modifiedDate` it read at load time, so
    /// without the database advancing it the move loses the last-writer-wins merge against
    /// the watch snapshot `PeerSyncManager` replays on every launch, and the pin reappears
    /// where it started.
    func testMovingAPinAdvancesItsLastWriterWinsStamp() async throws {
        let (adapter, mapView, ds, db) = try makeAdapter()
        let existingPin = UserMapPin(
            title: "Star",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pinType: BRCMapPointType.userStar.pinTypeString
        )
        try await db.saveUserMapPin(existingPin)
        let storedAtLoad = try await db.fetchUserMapPins().first
        let stampAtLoad = try XCTUnwrap(storedAtLoad).modifiedDate

        let onMap = BRCUserMapPoint(userMapPin: existingPin)
        ds.annotations = [onMap]
        adapter.reloadAnnotations()
        adapter.editMapPoint(onMap)
        onMap.coordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude + 0.01,
            longitude: coordinate.longitude
        )
        adapter.mapView(mapView, didDeselect: onMap)

        var rows = try await pins(in: db, expected: 1)
        let deadline = Date().addingTimeInterval(3)
        while (rows.first?.modifiedDate ?? .distantPast) <= stampAtLoad, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            rows = try await db.fetchUserMapPins()
        }
        XCTAssertGreaterThan(try XCTUnwrap(rows.first).modifiedDate, stampAtLoad)
    }

    func testDeletingAPinTombstonesItsRow() async throws {
        let (adapter, _, ds, db) = try makeAdapter()
        let existingPin = UserMapPin(
            title: "Star",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pinType: BRCMapPointType.userStar.pinTypeString
        )
        try await db.saveUserMapPin(existingPin)
        let onMap = BRCUserMapPoint(userMapPin: existingPin)
        ds.annotations = [onMap]
        adapter.reloadAnnotations()

        adapter.deleteMapPoint(onMap)

        let rows = try await pins(in: db, expected: 0)
        XCTAssertTrue(rows.isEmpty, "the deleted pin must not survive")
    }
}
