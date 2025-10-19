import XCTest
import CoreLocation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Tests for observing filtered query results.
final class FilterObservationTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    private var dbQueue: DatabaseQueue {
        playaDB.dbQueue
    }

    // MARK: - XCTest Lifecycle

    override func setUp() async throws {
        try await super.setUp()

        tempDBPath = ":memory:"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        tempDBPath = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func insertArt(
        uid: String,
        name: String,
        year: Int,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> ArtObject {
        let art = ArtObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )

        try await dbQueue.write { db in
            var mutableArt = art
            try mutableArt.insert(db)
        }

        return art
    }

    private func insertEvent(
        uid: String,
        name: String,
        year: Int,
        start: Date,
        end: Date,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws {
        let event = EventObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            eventTypeLabel: "Workshop",
            eventTypeCode: "work",
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )

        try await dbQueue.write { db in
            var mutableEvent = event
            try mutableEvent.insert(db)

            var insertedOccurrence = EventOccurrence(
                eventId: uid,
                startTime: start,
                endTime: end
            )
            try insertedOccurrence.insert(db)
        }
    }

    // MARK: - Tests

    func testObserveArtReceivesUpdatesForMatchingFilter() async throws {
        let expectation = expectation(description: "Art observation updated")

        let filter = ArtFilter(
            year: 2026,
            searchText: "observation"
        )

        let token = playaDB.observeArt(
            filter: filter,
            onChange: { art in
                if art.contains(where: { $0.uid == "art-observe" }) {
                    expectation.fulfill()
                }
            },
            onError: { error in
                XCTFail("Art observation error: \(error)")
            }
        )

        defer { token.cancel() }

        try await insertArt(
            uid: "art-observe",
            name: "Observation Station",
            year: 2026,
            description: "Interactive observation post"
        )

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    func testObserveEventsReceivesUpdatesForMatchingFilter() async throws {
        let expectation = expectation(description: "Event observation updated")

        let filter = EventFilter(
            searchText: "observation",
            includeExpired: true,
            happeningNow: true
        )

        let token = playaDB.observeEvents(
            filter: filter,
            onChange: { events in
                if events.contains(where: { $0.event.uid == "event-observe" }) {
                    expectation.fulfill()
                }
            },
            onError: { error in
                XCTFail("Event observation error: \(error)")
            }
        )

        defer { token.cancel() }

        let now = Date()
        try await insertEvent(
            uid: "event-observe",
            name: "Observation Dance",
            year: 2025,
            start: now.addingTimeInterval(-300),
            end: now.addingTimeInterval(300),
            description: "Live observation dance"
        )

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
