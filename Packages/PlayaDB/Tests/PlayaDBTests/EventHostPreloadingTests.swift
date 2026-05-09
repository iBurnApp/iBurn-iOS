import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// Integration tests for `batchResolveHosts` via the public `fetchEvents` API.
/// Inserts records directly through GRDB so each scenario is small and isolated.
final class EventHostPreloadingTests: XCTestCase {

    private var playaDB: PlayaDBImpl!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func insertCamp(uid: String, name: String, locationString: String? = nil, intersection: String? = nil) async throws {
        var camp = CampObject(
            uid: uid,
            name: name,
            year: 2025,
            locationString: locationString,
            intersection: intersection
        )
        try await playaDB.dbQueue.write { db in
            try camp.insert(db)
        }
    }

    private func insertArt(uid: String, name: String, locationString: String? = nil, locationHour: Int? = nil, locationMinute: Int? = nil, locationDistance: Int? = nil) async throws {
        var art = ArtObject(
            uid: uid,
            name: name,
            year: 2025,
            locationString: locationString,
            locationHour: locationHour,
            locationMinute: locationMinute,
            locationDistance: locationDistance
        )
        try await playaDB.dbQueue.write { db in
            try art.insert(db)
        }
    }

    private func insertEvent(uid: String, hostedByCamp: String? = nil, locatedAtArt: String? = nil) async throws {
        var event = EventObject(
            uid: uid,
            name: "Event \(uid)",
            year: 2025,
            eventTypeLabel: "Workshop",
            eventTypeCode: "workshop",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt
        )
        try await playaDB.dbQueue.write { db in
            try event.insert(db)
        }
    }

    private func insertOccurrence(eventUID: String) async throws {
        let now = Date()
        var occurrence = EventOccurrence(
            id: nil,
            eventId: eventUID,
            startTime: now,
            endTime: now.addingTimeInterval(3600)
        )
        try await playaDB.dbQueue.write { db in
            try occurrence.insert(db)
        }
    }

    // MARK: - Tests

    func testFetchEvents_PopulatesCampHost() async throws {
        // Given: a camp with locationString and an event hosted by that camp
        try await insertCamp(uid: "camp-1", name: "Camp Awesome", locationString: "7:30 & E")
        try await insertEvent(uid: "event-1", hostedByCamp: "camp-1")
        try await insertOccurrence(eventUID: "event-1")

        // When: fetch events
        let events = try await playaDB.fetchEvents()

        // Then: returned occurrence has the camp pre-loaded as host
        XCTAssertEqual(events.count, 1)
        let occ = try XCTUnwrap(events.first)
        let host = try XCTUnwrap(occ.host)
        XCTAssertEqual(host.uid, "camp-1")
        XCTAssertEqual(occ.hostName, "Camp Awesome")
        XCTAssertEqual(occ.hostAddress, "7:30 & E")
    }

    func testFetchEvents_PopulatesArtHost() async throws {
        // Given: an art with timeBasedAddress fallback and an event located at that art
        try await insertArt(uid: "art-1", name: "Big Art", locationHour: 9, locationMinute: 0, locationDistance: 800)
        try await insertEvent(uid: "event-1", locatedAtArt: "art-1")
        try await insertOccurrence(eventUID: "event-1")

        let events = try await playaDB.fetchEvents()

        XCTAssertEqual(events.count, 1)
        let occ = try XCTUnwrap(events.first)
        let host = try XCTUnwrap(occ.host)
        XCTAssertEqual(host.uid, "art-1")
        XCTAssertEqual(occ.hostName, "Big Art")
        XCTAssertEqual(occ.hostAddress, "9:00 & 800'")
    }

    func testFetchEvents_HostNilWhenCampMissing() async throws {
        // Given: an event references a camp that does not exist in the DB
        try await insertEvent(uid: "event-orphan", hostedByCamp: "missing-camp-uid")
        try await insertOccurrence(eventUID: "event-orphan")

        let events = try await playaDB.fetchEvents()

        XCTAssertEqual(events.count, 1)
        let occ = try XCTUnwrap(events.first)
        XCTAssertNil(occ.host)
        XCTAssertNil(occ.hostName)
        XCTAssertNil(occ.hostAddress)
    }

    func testFetchEventsHostedByCampUID_PreloadsHost() async throws {
        try await insertCamp(uid: "camp-host", name: "Host Camp", locationString: "3:00 & A")
        try await insertEvent(uid: "event-1", hostedByCamp: "camp-host")
        try await insertOccurrence(eventUID: "event-1")

        let events = try await playaDB.fetchEvents(hostedByCampUID: "camp-host")

        XCTAssertEqual(events.count, 1)
        let occ = try XCTUnwrap(events.first)
        let host = try XCTUnwrap(occ.host)
        XCTAssertEqual(host.uid, "camp-host")
        XCTAssertEqual(occ.hostName, "Host Camp")
        XCTAssertEqual(occ.hostAddress, "3:00 & A")
    }

    func testFetchEvents_BatchResolvesMultipleHosts() async throws {
        // Given: 2 camps, 1 art, 3 events each pointing to a different host, plus one event with no host.
        try await insertCamp(uid: "camp-a", name: "Camp A", locationString: "Camp A Loc")
        try await insertCamp(uid: "camp-b", name: "Camp B", intersection: "Camp B Intersection")
        try await insertArt(uid: "art-x", name: "Art X", locationString: "Art X Loc")

        try await insertEvent(uid: "ev-a", hostedByCamp: "camp-a")
        try await insertEvent(uid: "ev-b", hostedByCamp: "camp-b")
        try await insertEvent(uid: "ev-x", locatedAtArt: "art-x")
        try await insertEvent(uid: "ev-none")

        try await insertOccurrence(eventUID: "ev-a")
        try await insertOccurrence(eventUID: "ev-b")
        try await insertOccurrence(eventUID: "ev-x")
        try await insertOccurrence(eventUID: "ev-none")

        // When: fetch all events in one call
        let events = try await playaDB.fetchEvents()
        XCTAssertEqual(events.count, 4)

        // Then: each event has its expected host pre-loaded by the batch resolver
        let byUID = Dictionary(uniqueKeysWithValues: events.map { ($0.event.uid, $0) })

        let evA = try XCTUnwrap(byUID["ev-a"])
        let evAHost = try XCTUnwrap(evA.host)
        XCTAssertEqual(evAHost.uid, "camp-a")
        XCTAssertEqual(evA.hostAddress, "Camp A Loc")

        let evB = try XCTUnwrap(byUID["ev-b"])
        let evBHost = try XCTUnwrap(evB.host)
        XCTAssertEqual(evBHost.uid, "camp-b")
        // Camp B has no locationString, so address falls back to intersection.
        XCTAssertEqual(evB.hostAddress, "Camp B Intersection")

        let evX = try XCTUnwrap(byUID["ev-x"])
        let evXHost = try XCTUnwrap(evX.host)
        XCTAssertEqual(evXHost.uid, "art-x")
        XCTAssertEqual(evX.hostAddress, "Art X Loc")

        let evNone = try XCTUnwrap(byUID["ev-none"])
        XCTAssertNil(evNone.host)
    }
}
