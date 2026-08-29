import XCTest
import CoreLocation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Tests for observing filtered query results.
final class FilterObservationTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    private var dbQueue: any DatabaseWriter {
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
                if art.contains(where: { $0.object.uid == "art-observe" }) {
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
                if events.contains(where: { $0.object.event.uid == "event-observe" }) {
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
                    XCTAssertEqual(objects.map(\.object.uid), [art.uid])
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

    /// Favorite toggles must re-fire observeEvents: the fetch reads object_metadata
    /// for ListRow inflation, so the tracked regions must include it (regression test
    /// for regions that only covered the event tables, leaving hearts stale).
    func testObserveEventsRefiresOnFavoriteToggle() async throws {
        let expectation = expectation(description: "Event favorite metadata emitted")

        let events = try await playaDB.fetchEvents()
        let eventUID = try XCTUnwrap(events.first).event.uid

        let filter = EventFilter(includeExpired: true)
        let token = playaDB.observeEvents(
            filter: filter,
            onChange: { rows in
                if rows.contains(where: { $0.object.event.uid == eventUID && $0.metadata?.isFavorite == true }) {
                    expectation.fulfill()
                }
            },
            onError: { error in
                XCTFail("Event observation error: \(error)")
            }
        )

        defer { token.cancel() }

        try await setFavorite(.event, id: eventUID)

        await fulfillment(of: [expectation], timeout: 2.0)
    }

    /// Favorites-only event observation (the map's favorites layer) must drop rows
    /// when the favorite is removed.
    func testObserveEventsOnlyFavoritesRemovesUnfavoritedRow() async throws {
        let events = try await playaDB.fetchEvents()
        let eventUID = try XCTUnwrap(events.first).event.uid
        try await setFavorite(.event, id: eventUID)

        let appeared = expectation(description: "Favorited event emitted")
        let removed = expectation(description: "Unfavorited event removed")
        var sawEvent = false

        var filter = EventFilter(includeExpired: true)
        filter.onlyFavorites = true
        let token = playaDB.observeEvents(
            filter: filter,
            onChange: { rows in
                let contains = rows.contains { $0.object.event.uid == eventUID }
                if contains, !sawEvent {
                    sawEvent = true
                    appeared.fulfill()
                } else if !contains, sawEvent {
                    removed.fulfill()
                }
            },
            onError: { error in
                XCTFail("Event observation error: \(error)")
            }
        )

        defer { token.cancel() }

        await fulfillment(of: [appeared], timeout: 2.0)
        try await setFavorite(.event, id: eventUID, isFavorite: false)
        await fulfillment(of: [removed], timeout: 2.0)
    }

    /// setLastViewed writes only last_viewed/updated_at, which the narrowed metadata
    /// region excludes — marking objects viewed must not re-run list observations
    /// (previously every detail-screen view re-ran the full event JOIN).
    func testObserveEventsDoesNotRefireOnLastViewedWrite() async throws {
        let events = try await playaDB.fetchEvents()
        let occurrence = try XCTUnwrap(events.first)

        // Pre-create the metadata row: the first setLastViewed INSERTs (which always
        // triggers observation, by design); subsequent ones are pure column updates.
        try await playaDB.setLastViewed(Date(), for: occurrence)

        let noRefire = expectation(description: "No emission for last_viewed-only write")
        noRefire.isInverted = true
        var emissionCount = 0

        let token = playaDB.observeEvents(
            filter: EventFilter(includeExpired: true),
            onChange: { _ in
                emissionCount += 1
                if emissionCount > 1 {
                    noRefire.fulfill()
                }
            },
            onError: { error in
                XCTFail("Event observation error: \(error)")
            }
        )
        defer { token.cancel() }

        // Wait for the initial emission before writing.
        try await Task.sleep(nanoseconds: 300_000_000)
        try await playaDB.setLastViewed(Date(), for: occurrence)

        await fulfillment(of: [noRefire], timeout: 1.0)
        XCTAssertEqual(emissionCount, 1, "Only the initial emission should have fired")
    }

    func testObserveArtDoesNotRefireOnLastViewedWrite() async throws {
        let allArt = try await playaDB.fetchArt()
        let art = try XCTUnwrap(allArt.first)
        try await playaDB.setLastViewed(Date(), for: art)

        let noRefire = expectation(description: "No emission for last_viewed-only write")
        noRefire.isInverted = true
        var emissionCount = 0

        let token = playaDB.observeArt(
            filter: ArtFilter(),
            onChange: { _ in
                emissionCount += 1
                if emissionCount > 1 {
                    noRefire.fulfill()
                }
            },
            onError: { error in
                XCTFail("Art observation error: \(error)")
            }
        )
        defer { token.cancel() }

        try await Task.sleep(nanoseconds: 300_000_000)
        try await playaDB.setLastViewed(Date(), for: art)

        await fulfillment(of: [noRefire], timeout: 1.0)
        XCTAssertEqual(emissionCount, 1, "Only the initial emission should have fired")
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
                if artObjects.contains(where: { $0.object.uid == art.uid }) {
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
