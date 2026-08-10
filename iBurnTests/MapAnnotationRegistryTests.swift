//
//  MapAnnotationRegistryTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Regression coverage for the duplicated user pins ("bike/home/favorite thing is buggy
//  as fuck. duplicated pins and whatnot").
//
//  A user pin reaches the map as several *different objects* standing for the same
//  `user_map_pins` row: the one the user just placed, the one `observeUserMapPins`
//  rebuilds on every write, and the one `UserGuidance` builds to answer "where's my bike".
//  `MapAnnotationRegistry` is what keeps exactly one of them on the map at a time, so
//  these tests walk the real sequences the adapter performs.
//

import CoreLocation
import Foundation
import MapLibre
import XCTest
@testable import iBurn
@testable import PlayaDB

final class MapAnnotationRegistryTests: XCTestCase {

    // MARK: - Helpers

    private let coordinate = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)

    /// A pin as the map sees it. `pinId` is the `user_map_pins` row id, which is the only
    /// thing shared between the copies — `yapKey` is freshly random for each instance.
    private func pin(id: String, type: BRCMapPointType = .userBike, title: String? = nil) -> BRCUserMapPoint {
        let point = BRCUserMapPoint(title: title, coordinate: coordinate, type: type)
        point.pinId = id
        return point
    }

    // MARK: - Keys

    func testCopiesOfTheSamePinShareAKeyDespiteDifferentYapKeys() {
        let placed = pin(id: "row-1")
        let fromDatabase = pin(id: "row-1")

        XCTAssertNotEqual(placed.yapKey, fromDatabase.yapKey, "precondition: separate objects")
        XCTAssertEqual(
            MapAnnotationRegistry.key(for: placed),
            MapAnnotationRegistry.key(for: fromDatabase)
        )
    }

    func testDistinctPinsDoNotShareAKey() {
        XCTAssertNotEqual(
            MapAnnotationRegistry.key(for: pin(id: "row-1")),
            MapAnnotationRegistry.key(for: pin(id: "row-2"))
        )
    }

    // MARK: - Placement → save → reload

    func testDatabaseCopyOfAPlacedPinIsNotAddedASecondTime() {
        var registry = MapAnnotationRegistry()
        let placed = pin(id: "row-1")
        XCTAssertEqual(registry.add([placed]).count, 1)

        // The save commits and the observation delivers the row as a fresh object.
        let added = registry.add([pin(id: "row-1")])

        XCTAssertTrue(added.isEmpty, "the database's copy must not stack on the placed pin")
        XCTAssertEqual(registry.count, 1)
        XCTAssertTrue(registry.isOnMap(placed))
    }

    func testDeduplicatedCopyCannotDeregisterThePinThatIsOnTheMap() {
        var registry = MapAnnotationRegistry()
        let placed = pin(id: "row-1")
        _ = registry.add([placed])

        // This is the copy `reloadAnnotations` kept in its own list after it was deduped
        // away. The *next* reload hands it back to be removed.
        let deduplicated = pin(id: "row-1")
        _ = registry.add([deduplicated])

        let removed = registry.remove([deduplicated])

        XCTAssertTrue(removed.isEmpty, "it was never on the map, so nothing comes off")
        XCTAssertTrue(registry.isOnMap(placed), "and the pin that IS on the map keeps its key")
    }

    func testHandoverSwapsThePlacedPinForTheDatabaseCopy() {
        var registry = MapAnnotationRegistry()
        let placed = pin(id: "row-1")
        _ = registry.add([placed])

        let fromDatabase = pin(id: "row-1")
        XCTAssertTrue(MapAnnotationRegistry.contains(keyOf: placed, in: [fromDatabase]))

        // What `willReplaceDataSourceAnnotations` does once the row exists.
        XCTAssertEqual(registry.remove([placed]).count, 1)
        XCTAssertEqual(registry.add([fromDatabase]).count, 1)

        XCTAssertEqual(registry.count, 1)
        XCTAssertTrue(registry.isOnMap(fromDatabase))
    }

    func testUnsavedPlacementIsNotHandedOverToAnUnrelatedReload() {
        let placed = pin(id: "row-1")
        let otherPin = pin(id: "row-2")

        XCTAssertFalse(
            MapAnnotationRegistry.contains(keyOf: placed, in: [otherPin]),
            "a reload that doesn't carry this pin must leave it alone mid-edit"
        )
    }

    func testRepeatedReloadsNeverAccumulateCopies() {
        var registry = MapAnnotationRegistry()
        var onMap: [MLNAnnotation] = []
        var published: [MLNAnnotation] = []

        for _ in 0..<5 {
            // Each observation rebuilds the row as a brand-new object.
            let incoming = [pin(id: "row-1"), pin(id: "row-2")]
            let removed = registry.remove(published)
            onMap.removeAll { annotation in removed.contains { $0 === annotation } }
            published = incoming
            let added = registry.add(incoming)
            onMap.append(contentsOf: added)
        }

        XCTAssertEqual(onMap.count, 2)
        XCTAssertEqual(registry.count, 2)
    }

    // MARK: - Delete

    func testRemovingAPinFreesItsKeyAgain() {
        var registry = MapAnnotationRegistry()
        let placed = pin(id: "row-1")
        _ = registry.add([placed])

        XCTAssertEqual(registry.remove([placed]).count, 1)
        XCTAssertEqual(registry.count, 0)

        // Re-added by a peer sync, or by placing the same pin again: it has to land.
        let resurrected = pin(id: "row-1")
        XCTAssertEqual(registry.add([resurrected]).count, 1)
        XCTAssertTrue(registry.isOnMap(resurrected))
    }

    // MARK: - Untracked annotations

    func testAnnotationsWithoutAStableKeyPassStraightThrough() {
        var registry = MapAnnotationRegistry()
        let person = DroppedPersonAnnotation(coordinate: coordinate, title: nil)
        let other = DroppedPersonAnnotation(coordinate: coordinate, title: nil)

        XCTAssertNil(MapAnnotationRegistry.key(for: person))
        XCTAssertEqual(registry.add([person, other]).count, 2, "no key means no de-duplication")
        XCTAssertEqual(registry.count, 0)
        XCTAssertEqual(registry.remove([person]).count, 1)
    }
}
