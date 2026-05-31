//
//  NearbyCardViewModelTests.swift
//  iBurnTests
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Unit tests for the on-map nearby card ordering: events first (happening now /
//  starting soon, by start time), then art + camps by distance, gated to the
//  radius, de-duped by id, capped to maxItems.
//

import XCTest
import CoreLocation
import PlayaDB
@testable import iBurn

@MainActor
final class NearbyCardViewModelTests: XCTestCase {

    // User reference point and a shared longitude so distance varies only by latitude.
    private let baseLat = 40.0
    private let baseLon = -119.0
    private lazy var userLocation = CLLocation(latitude: baseLat, longitude: baseLon)

    // ~111,320 m per degree of latitude near the equator/BRC, so these are roughly:
    private let lat33m = 40.0003   // ~33 m north
    private let lat67m = 40.0006   // ~67 m north
    private let lat89m = 40.0008   // ~89 m north
    private let lat133m = 40.0012  // ~133 m north (outside a 100 m radius)

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Builders

    private func artRow(_ uid: String, lat: Double) -> ListRow<ArtObject> {
        ListRow(
            object: ArtObject(uid: uid, name: uid, year: 2025, gpsLatitude: lat, gpsLongitude: baseLon),
            metadata: nil,
            thumbnailColors: nil
        )
    }

    private func campRow(_ uid: String, lat: Double) -> ListRow<CampObject> {
        ListRow(
            object: CampObject(uid: uid, name: uid, year: 2025, gpsLatitude: lat, gpsLongitude: baseLon),
            metadata: nil,
            thumbnailColors: nil
        )
    }

    private func eventRow(_ uid: String, lat: Double, start: Date, end: Date) -> ListRow<EventObjectOccurrence> {
        let event = EventObject(
            uid: uid,
            name: uid,
            year: 2025,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            gpsLatitude: lat,
            gpsLongitude: baseLon
        )
        let occurrence = EventOccurrence(eventUid: uid, startTime: start, endTime: end, year: 2025)
        let combined = EventObjectOccurrence(event: event, occurrence: occurrence, host: nil)
        return ListRow(object: combined, metadata: nil, thumbnailColors: nil)
    }

    private func order(
        art: [ListRow<ArtObject>] = [],
        camps: [ListRow<CampObject>] = [],
        events: [ListRow<EventObjectOccurrence>] = [],
        radius: CLLocationDistance = 100,
        maxItems: Int = 12
    ) -> [NearbyItem] {
        NearbyCardViewModel.orderedItems(
            art: art,
            camps: camps,
            events: events,
            from: userLocation,
            now: now,
            radius: radius,
            maxItems: maxItems
        )
    }

    // MARK: - Tests

    func testEventsComeFirstThenArtAndCampsByDistance() throws {
        // Event is the farthest of the in-radius items but must still come first.
        let happeningEvent = eventRow("E", lat: lat89m,
                                      start: now.addingTimeInterval(-600),
                                      end: now.addingTimeInterval(3000))
        let items = order(
            art: [artRow("A", lat: lat33m)],
            camps: [campRow("C", lat: lat67m)],
            events: [happeningEvent]
        )

        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items[0].id.hasPrefix("event-"), "Events must be prioritized first")
        XCTAssertEqual(items[1].id, "art-A", "Then nearest non-event (33 m)")
        XCTAssertEqual(items[2].id, "camp-C", "Then next nearest (67 m)")
    }

    func testItemsBeyondRadiusAreExcluded() throws {
        let items = order(
            art: [artRow("near", lat: lat33m), artRow("far", lat: lat133m)]
        )

        XCTAssertEqual(items.map(\.id), ["art-near"])
        XCTAssertFalse(items.contains { $0.id == "art-far" })
    }

    func testArtAndCampsSortedByDistance() throws {
        let items = order(
            art: [artRow("artFar", lat: lat67m)],
            camps: [campRow("campNear", lat: lat33m)]
        )

        XCTAssertEqual(items.map(\.id), ["camp-campNear", "art-artFar"])
    }

    func testEndedEventIsExcluded() throws {
        let endedEvent = eventRow("ended", lat: lat33m,
                                  start: now.addingTimeInterval(-7200),
                                  end: now.addingTimeInterval(-3600))
        let items = order(events: [endedEvent])

        XCTAssertTrue(items.isEmpty, "Events that have ended should not appear")
    }

    func testDuplicateIdsAreDeduped() throws {
        let items = order(art: [artRow("dup", lat: lat33m), artRow("dup", lat: lat67m)])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "art-dup")
    }

    func testResultIsCappedToMaxItems() throws {
        let art = (0..<10).map { artRow("art\($0)", lat: lat33m) }
        let items = order(art: art, maxItems: 4)

        XCTAssertEqual(items.count, 4)
    }

    func testNoLocationObjectsAreDropped() throws {
        // An art object with no GPS (location == nil) must be dropped.
        let noGPS = ListRow(
            object: ArtObject(uid: "noGPS", name: "noGPS", year: 2025),
            metadata: nil,
            thumbnailColors: nil
        )
        let items = order(art: [noGPS, artRow("withGPS", lat: lat33m)])

        XCTAssertEqual(items.map(\.id), ["art-withGPS"])
    }
}
