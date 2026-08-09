//
//  NearbyCardViewModelTests.swift
//  iBurnTests
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Unit tests for the on-map nearby card ordering: events first (happening now /
//  starting soon, by start time), then art + camps by distance, gated to the
//  radius and to the user's enabled types, de-duped by id, capped to maxItems.
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
        let occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
        let combined = EventObjectOccurrence(event: event, occurrence: occurrence, host: nil)
        return ListRow(object: combined, metadata: nil, thumbnailColors: nil)
    }

    private func order(
        art: [ListRow<ArtObject>] = [],
        camps: [ListRow<CampObject>] = [],
        events: [ListRow<EventObjectOccurrence>] = [],
        types: NearbyCardTypes = .all,
        radius: CLLocationDistance = 100,
        maxItems: Int = 12
    ) -> [NearbyItem] {
        NearbyCardViewModel.orderedItems(
            art: art,
            camps: camps,
            events: events,
            types: types,
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

    /// The card used to gate on `isCurrentlyHappening`, which counts an occurrence as
    /// happening right up to its end time. The last minute has no minutes left to render,
    /// so it displayed as "(0m left)" on something already over.
    func testEventInItsFinalSecondsIsExcluded() throws {
        let almostOver = eventRow("almostOver", lat: lat33m,
                                  start: now.addingTimeInterval(-3600),
                                  end: now.addingTimeInterval(30))
        let items = order(events: [almostOver])

        XCTAssertTrue(items.isEmpty, "An event with under a minute left should not be offered")
    }

    func testEventEndingExactlyNowIsExcluded() throws {
        let endingNow = eventRow("endingNow", lat: lat33m,
                                 start: now.addingTimeInterval(-3600),
                                 end: now)
        let items = order(events: [endingNow])

        XCTAssertTrue(items.isEmpty)
    }

    func testEventWithRealTimeLeftIsIncluded() throws {
        let running = eventRow("running", lat: lat33m,
                               start: now.addingTimeInterval(-3600),
                               end: now.addingTimeInterval(600))
        let items = order(events: [running])

        XCTAssertEqual(items.map(\.id), ["event-running_0"])
    }

    /// The card and the Nearby screen share one window so they can't list different
    /// events. This pins the shared predicate rather than either call site.
    func testNearbyWindowBoundaries() throws {
        let startsInTenMinutes = eventRow("soon", lat: lat33m,
                                          start: now.addingTimeInterval(600),
                                          end: now.addingTimeInterval(3600)).object
        let startsInTwoHours = eventRow("later", lat: lat33m,
                                        start: now.addingTimeInterval(7200),
                                        end: now.addingTimeInterval(10800)).object
        let ended = eventRow("over", lat: lat33m,
                             start: now.addingTimeInterval(-7200),
                             end: now.addingTimeInterval(-60)).object

        XCTAssertTrue(startsInTenMinutes.isInNearbyWindow(now: now))
        XCTAssertFalse(startsInTwoHours.isInNearbyWindow(now: now), "Beyond the 30 minute lookahead")
        XCTAssertFalse(ended.isInNearbyWindow(now: now))
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

    // MARK: - Type filtering

    private func mixedFixtures() -> (
        art: [ListRow<ArtObject>],
        camps: [ListRow<CampObject>],
        events: [ListRow<EventObjectOccurrence>]
    ) {
        let event = eventRow("E", lat: lat89m,
                             start: now.addingTimeInterval(-600),
                             end: now.addingTimeInterval(3000))
        return ([artRow("A", lat: lat33m)], [campRow("C", lat: lat67m)], [event])
    }

    func testOnlyArtEnabledExcludesCampsAndEvents() throws {
        let fixtures = mixedFixtures()
        let items = order(art: fixtures.art, camps: fixtures.camps, events: fixtures.events, types: .art)

        XCTAssertEqual(items.map(\.id), ["art-A"])
    }

    func testDisablingEventsKeepsArtAndCamps() throws {
        let fixtures = mixedFixtures()
        let items = order(art: fixtures.art, camps: fixtures.camps, events: fixtures.events,
                          types: [.art, .camps])

        XCTAssertEqual(items.map(\.id), ["art-A", "camp-C"], "Ordering by distance is unchanged")
    }

    func testOnlyEventsEnabledExcludesArtAndCamps() throws {
        let fixtures = mixedFixtures()
        let items = order(art: fixtures.art, camps: fixtures.camps, events: fixtures.events, types: .events)

        XCTAssertEqual(items.count, 1)
        let first = try XCTUnwrap(items.first)
        XCTAssertTrue(first.id.hasPrefix("event-"))
    }

    func testNoTypesEnabledYieldsNothing() throws {
        let fixtures = mixedFixtures()
        let items = order(art: fixtures.art, camps: fixtures.camps, events: fixtures.events, types: [])

        XCTAssertTrue(items.isEmpty)
    }

    func testTypesFromBoolsMatchesTheOptionSet() throws {
        XCTAssertEqual(NearbyCardTypes(showArt: true, showCamps: true, showEvents: true), .all)
        XCTAssertEqual(NearbyCardTypes(showArt: true, showCamps: false, showEvents: false), .art)
        XCTAssertEqual(NearbyCardTypes(showArt: false, showCamps: false, showEvents: false), [])
    }

    // MARK: - Accessory line

    // The card row is name → accessory (when/where) → description. The accessory is what
    // stopped the address from evicting the description once the embargo lifts, so these
    // cases pin both the composition and the locked shape. The address half rides
    // `NearbyItem.address`, whose own tier checks live in `EmbargoTierTests`; here the
    // embargo is moved wholesale with the passcode so the two shapes can be compared.

    private var originalUnlocked = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalUnlocked = UserDefaults.enteredEmbargoPasscode
        UserDefaults.enteredEmbargoPasscode = false
        // Pinned before the camp tier opens, so "locked" stays locked as the calendar moves.
        UserDefaults.standard.set(true, forKey: "BRCMockDateEnabled")
        let locked = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-10T12:00:00Z"))
        UserDefaults.standard.set(locked, forKey: "BRCMockDateValue")
    }

    override func tearDownWithError() throws {
        UserDefaults.enteredEmbargoPasscode = originalUnlocked
        UserDefaults.standard.removeObject(forKey: "BRCMockDateEnabled")
        UserDefaults.standard.removeObject(forKey: "BRCMockDateValue")
        try super.tearDownWithError()
    }

    private func campItem(address: String?) -> NearbyItem {
        .camp(ListRow(
            object: CampObject(uid: "camp-1", name: "Camp Test", year: 2026, locationString: address),
            metadata: nil,
            thumbnailColors: nil
        ))
    }

    private func hostedEventItem(hostAddress: String?) -> NearbyItem {
        let camp = CampObject(uid: "camp-1", name: "Camp Test", year: 2026, locationString: hostAddress)
        let event = EventObject(
            uid: "event-1",
            name: "Test Event",
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: camp.uid
        )
        let occurrence = EventOccurrence(
            eventId: event.uid,
            startTime: now.addingTimeInterval(-600),
            endTime: now.addingTimeInterval(3000)
        )
        return .event(ListRow(
            object: EventObjectOccurrence(event: event, occurrence: occurrence, host: camp),
            metadata: nil,
            thumbnailColors: nil
        ))
    }

    func testLockedCampHasNoAccessoryLineSoTheDescriptionGetsTheSpace() throws {
        XCTAssertNil(campItem(address: "7:30 & Esplanade").accessoryLine(now: now))
    }

    func testUnlockedCampAccessoryLineIsItsAddress() throws {
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertEqual(campItem(address: "7:30 & Esplanade").accessoryLine(now: now),
                       "7:30 & Esplanade")
    }

    func testCampWithNoAddressHasNoAccessoryLineEvenUnlocked() throws {
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertNil(campItem(address: nil).accessoryLine(now: now))
    }

    /// An event's timing is not placement data, so it is the whole line while locked and
    /// gains the address — one line, one separator — once the host's tier opens.
    func testEventAccessoryLineIsTimeAloneUntilItsHostUnlocks() throws {
        let item = hostedEventItem(hostAddress: "7:30 & Esplanade")
        let timeOnly = try XCTUnwrap(item.accessoryLine(now: now))
        XCTAssertFalse(timeOnly.contains("7:30 & Esplanade"))
        XCTAssertFalse(timeOnly.contains("·"))

        UserDefaults.enteredEmbargoPasscode = true
        let withAddress = try XCTUnwrap(item.accessoryLine(now: now))
        XCTAssertEqual(withAddress, "\(timeOnly) · 7:30 & Esplanade")
    }

    /// A hostless event with no free-text location has timing and nothing else — the line
    /// must not degrade to a dangling separator.
    func testEventWithoutAnAddressIsJustItsTime() throws {
        UserDefaults.enteredEmbargoPasscode = true
        let item = hostedEventItem(hostAddress: nil)
        let line = try XCTUnwrap(item.accessoryLine(now: now))
        XCTAssertFalse(line.hasSuffix("·"))
        XCTAssertFalse(line.contains("·"))
    }
}
