import XCTest
import Foundation
import MapKit
import GRDB
@testable import PlayaDB

/// Tests for the spatio-temporal R*Tree-backed region filtering of event occurrences,
/// and the point-R*Tree-backed `inRegion` for art/camp. Inserts records directly through
/// GRDB (matching EventHostPreloadingTests) and rebuilds the occurrence index explicitly.
final class EventOccurrenceRTreeTests: XCTestCase {

    private var playaDB: PlayaDBImpl!

    // A point near Black Rock City and a region around it.
    private let centerLat = 40.7864
    private let centerLon = -119.2065
    // A fixed 2025 instant (~Aug 28) so window math is deterministic and DST-free.
    private let windowStart = Date(timeIntervalSince1970: 1_756_400_000)

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func region(delta: Double = 0.01) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    private func windowFilter(region: MKCoordinateRegion?, eventTypeCodes: Set<String>? = nil) -> EventFilter {
        EventFilter(
            region: region,
            startDate: windowStart,
            endDate: windowStart.addingTimeInterval(7200),
            eventTypeCodes: eventTypeCodes
        )
    }

    private func insertEvent(uid: String, lat: Double?, lon: Double?, typeCode: String = "workshop", hostedByCamp: String? = nil) async throws {
        var event = EventObject(
            uid: uid, name: "Event \(uid)", year: 2025,
            eventTypeLabel: "Workshop", eventTypeCode: typeCode,
            hostedByCamp: hostedByCamp,
            gpsLatitude: lat, gpsLongitude: lon
        )
        try await playaDB.dbQueue.write { db in try event.insert(db) }
    }

    private func insertCamp(uid: String, lat: Double, lon: Double) async throws {
        var camp = CampObject(uid: uid, name: "Camp \(uid)", year: 2025, gpsLatitude: lat, gpsLongitude: lon)
        try await playaDB.dbQueue.write { db in try camp.insert(db) }
    }

    private func insertArt(uid: String, lat: Double, lon: Double) async throws {
        var art = ArtObject(uid: uid, name: "Art \(uid)", year: 2025, gpsLatitude: lat, gpsLongitude: lon)
        try await playaDB.dbQueue.write { db in try art.insert(db) }
    }

    /// Insert an occurrence starting `startOffset` seconds after `windowStart`.
    private func insertOccurrence(eventUID: String, startOffset: TimeInterval, durationSeconds: TimeInterval = 3600) async throws {
        let start = windowStart.addingTimeInterval(startOffset)
        var occ = EventOccurrence(id: nil, eventId: eventUID, startTime: start, endTime: start.addingTimeInterval(durationSeconds))
        try await playaDB.dbQueue.write { db in try occ.insert(db) }
    }

    private func rebuildRTree() async throws {
        let db = playaDB!
        try await db.dbQueue.write { database in try db.rebuildOccurrenceRTree(database) }
    }

    // MARK: - Tests

    func testEventInRegionAndWindowReturned() async throws {
        try await insertEvent(uid: "e1", lat: centerLat, lon: centerLon)
        try await insertOccurrence(eventUID: "e1", startOffset: 1800) // 30 min into the window
        try await rebuildRTree()

        let events = try await playaDB.fetchEvents(filter: windowFilter(region: region()))
        XCTAssertTrue(events.contains { $0.event.uid == "e1" })
    }

    func testEventOutOfRegionExcluded() async throws {
        try await insertEvent(uid: "far", lat: 0.0, lon: 0.0)
        try await insertOccurrence(eventUID: "far", startOffset: 1800)
        try await rebuildRTree()

        let events = try await playaDB.fetchEvents(filter: windowFilter(region: region()))
        XCTAssertFalse(events.contains { $0.event.uid == "far" })
    }

    func testEventOutsideWindowExcluded() async throws {
        try await insertEvent(uid: "e1", lat: centerLat, lon: centerLon)
        try await insertOccurrence(eventUID: "e1", startOffset: 100_000) // long after the window
        try await rebuildRTree()

        let events = try await playaDB.fetchEvents(filter: windowFilter(region: region()))
        XCTAssertFalse(events.contains { $0.event.uid == "e1" })
    }

    func testEventTypeCodesRespected() async throws {
        try await insertEvent(uid: "yoga", lat: centerLat, lon: centerLon, typeCode: "medt")
        try await insertEvent(uid: "party", lat: centerLat, lon: centerLon, typeCode: "prty")
        try await insertOccurrence(eventUID: "yoga", startOffset: 1800)
        try await insertOccurrence(eventUID: "party", startOffset: 1800)
        try await rebuildRTree()

        let events = try await playaDB.fetchEvents(filter: windowFilter(region: region(), eventTypeCodes: ["medt"]))
        XCTAssertTrue(events.contains { $0.event.uid == "yoga" })
        XCTAssertFalse(events.contains { $0.event.uid == "party" })
    }

    /// The original bug: an event hosted by an in-region camp (GPS copied from the camp at
    /// import) must come back from a region-scoped query.
    func testEventHostedByInRegionCampReturned() async throws {
        try await insertCamp(uid: "c1", lat: centerLat, lon: centerLon)
        try await insertEvent(uid: "e1", lat: centerLat, lon: centerLon, hostedByCamp: "c1")
        try await insertOccurrence(eventUID: "e1", startOffset: 1800)
        try await rebuildRTree()

        let events = try await playaDB.fetchEvents(filter: windowFilter(region: region()))
        let occ = try XCTUnwrap(events.first { $0.event.uid == "e1" })
        XCTAssertEqual(occ.event.hostedByCamp, "c1")
    }

    func testNilGpsEventExcludedFromRegionButPresentWithoutRegion() async throws {
        try await insertEvent(uid: "noloc", lat: nil, lon: nil)
        try await insertOccurrence(eventUID: "noloc", startOffset: 1800)
        try await rebuildRTree()

        let regioned = try await playaDB.fetchEvents(filter: windowFilter(region: region()))
        XCTAssertFalse(regioned.contains { $0.event.uid == "noloc" })

        let noRegion = try await playaDB.fetchEvents(filter: windowFilter(region: nil))
        XCTAssertTrue(noRegion.contains { $0.event.uid == "noloc" })
    }

    func testRebuildPopulatesAndIsIdempotent() async throws {
        try await insertEvent(uid: "e1", lat: centerLat, lon: centerLon)
        try await insertOccurrence(eventUID: "e1", startOffset: 1800)
        try await rebuildRTree()
        try await rebuildRTree() // INSERT OR REPLACE → idempotent

        let count = try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrence_rtree") ?? 0
        }
        XCTAssertEqual(count, 1)
    }

    // MARK: - Art/Camp inRegion via point R*Tree (trigger-maintained; no rebuild needed)

    func testArtInRegionViaRTree() async throws {
        try await insertArt(uid: "near", lat: centerLat, lon: centerLon)
        try await insertArt(uid: "far", lat: 0.0, lon: 0.0)

        let art = try await playaDB.fetchArt(filter: ArtFilter(region: region()))
        XCTAssertTrue(art.contains { $0.uid == "near" })
        XCTAssertFalse(art.contains { $0.uid == "far" })
    }

    func testCampInRegionViaRTree() async throws {
        try await insertCamp(uid: "near", lat: centerLat, lon: centerLon)
        try await insertCamp(uid: "far", lat: 0.0, lon: 0.0)

        let camps = try await playaDB.fetchCamps(filter: CampFilter(region: region()))
        XCTAssertTrue(camps.contains { $0.uid == "near" })
        XCTAssertFalse(camps.contains { $0.uid == "far" })
    }
}
