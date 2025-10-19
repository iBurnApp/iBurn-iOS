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
        longitude: Double? = nil,
        locatedAtArt: String? = nil
    ) async throws {
        let event = EventObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            eventTypeLabel: "Workshop",
            eventTypeCode: "work",
            locatedAtArt: locatedAtArt,
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

    private func setFavorite(
        _ type: DataObjectType,
        id: String,
        isFavorite: Bool = true
    ) async throws {
        try await dbQueue.write { db in
            var metadata = ObjectMetadata(
                objectType: type.rawValue,
                objectId: id,
                isFavorite: isFavorite
            )
            try metadata.save(db)
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

    func testObserveArtOnlyFavoritesUpdates() async throws {
        let favoritesExpectation = expectation(description: "Favorite art emitted")

        let allArt = try await playaDB.fetchArt()
        guard let art = allArt.first else {
            XCTFail("Expected seeded art data")
            return
        }

        var emissionCount = 0
        let token = playaDB.observeArt(
            filter: ArtFilter(onlyFavorites: true),
            onChange: { objects in
                emissionCount += 1
                if emissionCount >= 2 {
                    XCTAssertEqual(objects.map(\.uid), [art.uid])
                    favoritesExpectation.fulfill()
                } else {
                    XCTAssertTrue(objects.isEmpty, "Initial favorites emission should be empty")
                }
            },
            onError: { error in
                XCTFail("Favorites observation error: \(error)")
            }
        )

        defer { token.cancel() }

        try await setFavorite(.art, id: art.uid)

        await fulfillment(of: [favoritesExpectation], timeout: 2.0)
    }

    func testObserveArtOnlyWithEventsUpdates() async throws {
        let expectation = expectation(description: "Art with events emitted")
        let year = 2031

        let art = try await insertArt(
            uid: "observed-art-with-event",
            name: "Performance Plaza",
            year: year
        )

        let token = playaDB.observeArt(
            filter: ArtFilter(year: year, onlyWithEvents: true),
            onChange: { artObjects in
                if artObjects.contains(where: { $0.uid == art.uid }) {
                    expectation.fulfill()
                } else {
                    XCTAssertTrue(artObjects.isEmpty, "Initial emission should be empty before event insertion")
                }
            },
            onError: { error in
                XCTFail("onlyWithEvents observation error: \(error)")
            }
        )

        defer { token.cancel() }

        let now = Date()
        try await insertEvent(
            uid: "event-for-observed-art",
            name: "Performance Show",
            year: year,
            start: now,
            end: now.addingTimeInterval(1800),
            locatedAtArt: art.uid
        )

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
