import XCTest
import Foundation
import MapKit
import GRDB
@testable import PlayaDB

/// Regression tests for the spatial-index UPDATE triggers: changing gps columns
/// in place (the shape of a future embargo-drop delivered as an update rather
/// than a reimport) must keep spatial_index / spatial_objects and the
/// occurrence R*Tree in sync — no manual rebuild.
final class SpatialIndexUpdateTests: XCTestCase {

    private var playaDB: PlayaDBImpl!

    private let centerLat = 40.7864
    private let centerLon = -119.2065
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

    private func region(centerLat: Double? = nil, centerLon: Double? = nil, delta: Double = 0.01) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: centerLat ?? self.centerLat,
                longitude: centerLon ?? self.centerLon
            ),
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        )
    }

    private func insertCamp(uid: String, lat: Double?, lon: Double?) async throws {
        var camp = CampObject(uid: uid, name: "Camp \(uid)", year: 2025, gpsLatitude: lat, gpsLongitude: lon)
        try await playaDB.dbQueue.write { db in try camp.insert(db) }
    }

    private func setCampGPS(uid: String, lat: Double?, lon: Double?) async throws {
        try await playaDB.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE camp_objects SET gps_latitude = ?, gps_longitude = ? WHERE uid = ?",
                arguments: [lat, lon, uid]
            )
        }
    }

    private func spatialRowCount(type: String, uid: String) async throws -> Int {
        try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM spatial_index si
                JOIN spatial_objects so ON si.id = so.spatial_id
                WHERE so.object_type = ? AND so.object_uid = ?
                """, arguments: [type, uid]) ?? 0
        }
    }

    private func campUIDsInRegion(_ region: MKCoordinateRegion) async throws -> Set<String> {
        let camps = try await playaDB.fetchCamps(filter: CampFilter(region: region))
        return Set(camps.map(\.uid))
    }

    // MARK: - Camp point index

    func testGainingGPSViaUpdateEntersRegionQueries() async throws {
        try await insertCamp(uid: "c1", lat: nil, lon: nil)
        var found = try await campUIDsInRegion(region())
        XCTAssertFalse(found.contains("c1"))

        try await setCampGPS(uid: "c1", lat: centerLat, lon: centerLon)
        found = try await campUIDsInRegion(region())
        XCTAssertTrue(found.contains("c1"), "gps gained via UPDATE must reach the R*Tree")

        let rows = try await spatialRowCount(type: "camp", uid: "c1")
        XCTAssertEqual(rows, 1)
    }

    func testMovingGPSViaUpdateMovesRegionMembership() async throws {
        try await insertCamp(uid: "c1", lat: centerLat, lon: centerLon)

        // Move the camp ~1 degree north: out of the old region, into the new one.
        let movedLat = centerLat + 1.0
        try await setCampGPS(uid: "c1", lat: movedLat, lon: centerLon)

        let oldRegion = try await campUIDsInRegion(region())
        XCTAssertFalse(oldRegion.contains("c1"))

        let newRegion = try await campUIDsInRegion(region(centerLat: movedLat))
        XCTAssertTrue(newRegion.contains("c1"))

        // Exactly one spatial row — the update must not accumulate duplicates.
        let rows = try await spatialRowCount(type: "camp", uid: "c1")
        XCTAssertEqual(rows, 1)
    }

    func testClearingGPSViaUpdateRemovesSpatialRows() async throws {
        try await insertCamp(uid: "c1", lat: centerLat, lon: centerLon)
        try await setCampGPS(uid: "c1", lat: nil, lon: nil)

        let found = try await campUIDsInRegion(region())
        XCTAssertFalse(found.contains("c1"))

        let rows = try await spatialRowCount(type: "camp", uid: "c1")
        XCTAssertEqual(rows, 0)
        let orphanedMappings = try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM spatial_objects
                WHERE object_type = 'camp' AND object_uid = 'c1'
                """) ?? 0
        }
        XCTAssertEqual(orphanedMappings, 0)
    }

    func testRepeatedUpdatesKeepSingleSpatialRow() async throws {
        try await insertCamp(uid: "c1", lat: nil, lon: nil)
        for offset in [0.0, 0.001, 0.002, 0.003] {
            try await setCampGPS(uid: "c1", lat: centerLat + offset, lon: centerLon)
        }
        let rows = try await spatialRowCount(type: "camp", uid: "c1")
        XCTAssertEqual(rows, 1)
    }

    // MARK: - Occurrence R*Tree follows event GPS updates

    func testEventGPSUpdateRefreshesOccurrenceRTree() async throws {
        var event = EventObject(
            uid: "e1", name: "Event e1", year: 2025,
            eventTypeLabel: "Workshop", eventTypeCode: "work",
            gpsLatitude: nil, gpsLongitude: nil
        )
        var occurrence = EventOccurrence(
            id: nil, eventId: "e1",
            startTime: windowStart.addingTimeInterval(1800),
            endTime: windowStart.addingTimeInterval(5400)
        )
        try await playaDB.dbQueue.write { db in
            try event.insert(db)
            try occurrence.insert(db)
        }

        let filter = EventFilter(
            region: region(),
            startDate: windowStart,
            endDate: windowStart.addingTimeInterval(7200)
        )
        var events = try await playaDB.fetchEvents(filter: filter)
        XCTAssertFalse(events.contains { $0.event.uid == "e1" })

        // Event gains GPS in place — its occurrences must become region-queryable.
        try await playaDB.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE event_objects SET gps_latitude = ?, gps_longitude = ? WHERE uid = 'e1'",
                arguments: [self.centerLat, self.centerLon]
            )
        }
        events = try await playaDB.fetchEvents(filter: filter)
        XCTAssertTrue(events.contains { $0.event.uid == "e1" })

        // And losing GPS must remove them again.
        try await playaDB.dbQueue.write { db in
            try db.execute(sql: "UPDATE event_objects SET gps_latitude = NULL, gps_longitude = NULL WHERE uid = 'e1'")
        }
        events = try await playaDB.fetchEvents(filter: filter)
        XCTAssertFalse(events.contains { $0.event.uid == "e1" })

        let rtreeRows = try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrence_rtree") ?? 0
        }
        XCTAssertEqual(rtreeRows, 0)
    }

    // MARK: - Existing databases pick the triggers up on reopen

    func testUpdateTriggersExistAfterSetup() async throws {
        let names = try await playaDB.dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE '%_update'
                """)
        }
        for expected in ["art_spatial_update", "camp_spatial_update", "event_spatial_update",
                         "event_occurrence_rtree_event_update"] {
            XCTAssertTrue(names.contains(expected), "missing trigger \(expected)")
        }
    }
}
