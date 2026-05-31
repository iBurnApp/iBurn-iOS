import XCTest
import CoreLocation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Tests for `observeEventsByDayThenHour` — the long-lived observation that powers
/// the SwiftUI events list's day-tab + hour-strip browse mode. Day tabs slice the
/// emitted `[Date: [EventHourSection]]` in memory; no DB hit on tab switch.
final class EventListBucketObservationTests: XCTestCase {
    private var playaDB: PlayaDBImpl!

    private var dbQueue: DatabaseQueue { playaDB.dbQueue }

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func insertCamp(uid: String, name: String, year: Int) async throws {
        let camp = CampObject(uid: uid, name: name, year: year)
        try await dbQueue.write { db in
            var c = camp
            try c.insert(db)
        }
    }

    private func insertEvent(
        uid: String,
        name: String,
        year: Int,
        start: Date,
        end: Date,
        eventTypeCode: String = "work",
        hostedByCamp: String? = nil,
        locatedAtArt: String? = nil
    ) async throws {
        let event = EventObject(
            uid: uid,
            name: name,
            year: year,
            eventTypeLabel: "Workshop",
            eventTypeCode: eventTypeCode,
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt
        )
        try await dbQueue.write { db in
            var mutableEvent = event
            try mutableEvent.insert(db)
            var occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
            try occurrence.insert(db)
        }
    }

    private func setFavorite(_ type: DataObjectType, id: String, isFavorite: Bool = true) async throws {
        try await dbQueue.write { db in
            var metadata = ObjectMetadata(
                objectType: type.rawValue,
                objectId: id,
                isFavorite: isFavorite
            )
            try metadata.save(db)
        }
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    // MARK: - Tests

    /// Multi-day fixtures bucket cleanly into per-day, per-hour sections, ordered.
    func testBucketGroupsByDayThenHour() async throws {
        let year = 2099
        let cal = Calendar.current
        guard let dayA = cal.date(from: DateComponents(year: year, month: 8, day: 25, hour: 14)),
              let dayB = cal.date(from: DateComponents(year: year, month: 8, day: 26, hour: 9)) else {
            return XCTFail("Could not construct fixture dates")
        }

        try await insertEvent(uid: "bucket-a1", name: "A 14:30", year: year,
                              start: dayA.addingTimeInterval(30 * 60),
                              end: dayA.addingTimeInterval(90 * 60))
        try await insertEvent(uid: "bucket-a2", name: "A 14:00", year: year,
                              start: dayA,
                              end: dayA.addingTimeInterval(60 * 60))
        try await insertEvent(uid: "bucket-a3", name: "A 16:00", year: year,
                              start: dayA.addingTimeInterval(2 * 3600),
                              end: dayA.addingTimeInterval(3 * 3600))
        try await insertEvent(uid: "bucket-b1", name: "B 09:15", year: year,
                              start: dayB.addingTimeInterval(15 * 60),
                              end: dayB.addingTimeInterval(75 * 60))

        let bucket = try await observeOnce(filter: EventFilter(year: year))

        let dayAKey = startOfDay(dayA)
        let dayBKey = startOfDay(dayB)

        let aSections = try XCTUnwrap(bucket[dayAKey])
        XCTAssertEqual(aSections.map(\.hour), [14, 16], "Sections should be ordered by hour")
        XCTAssertEqual(aSections.first?.rows.map(\.object.event.uid), ["bucket-a2", "bucket-a1"],
                       "Rows within a section should preserve start_time order")

        let bSections = try XCTUnwrap(bucket[dayBKey])
        XCTAssertEqual(bSections.map(\.hour), [9])
        XCTAssertEqual(bSections.first?.rows.map(\.object.event.uid), ["bucket-b1"])
    }

    /// The JOIN-based fetch pre-resolves host camp; `hostName` is populated from a single query.
    func testJoinedFetchResolvesHostCamp() async throws {
        let year = 2099
        try await insertCamp(uid: "host-camp-1", name: "Camp Sparkle", year: year)
        let cal = Calendar.current
        let start = try XCTUnwrap(cal.date(from: DateComponents(year: year, month: 8, day: 28, hour: 11)))
        try await insertEvent(uid: "evt-hosted-1", name: "Sparkle Hour", year: year,
                              start: start, end: start.addingTimeInterval(3600),
                              hostedByCamp: "host-camp-1")

        let bucket = try await observeOnce(filter: EventFilter(year: year))
        let sections = try XCTUnwrap(bucket[startOfDay(start)])
        let row = try XCTUnwrap(sections.first?.rows.first)
        XCTAssertEqual(row.object.event.uid, "evt-hosted-1")
        XCTAssertEqual(row.object.hostName, "Camp Sparkle")
    }

    /// Favoriting an event re-emits because `object_metadata` is in the tracked region set.
    func testFavoriteToggleReEmits() async throws {
        let year = 2099
        let cal = Calendar.current
        let start = try XCTUnwrap(cal.date(from: DateComponents(year: year, month: 8, day: 29, hour: 13)))
        try await insertEvent(uid: "evt-fav-1", name: "Fav Me", year: year,
                              start: start, end: start.addingTimeInterval(3600))

        let firstEmission = expectation(description: "first emission with event present")
        let favoriteEmission = expectation(description: "re-emission after favorite toggle")

        var emissions = 0
        let token = playaDB.observeEventsByDayThenHour(
            filter: EventFilter(year: year),
            onChange: { bucket in
                emissions += 1
                let row = bucket[self.startOfDay(start)]?.first?.rows.first
                if emissions == 1, row?.object.event.uid == "evt-fav-1" {
                    firstEmission.fulfill()
                } else if emissions >= 2, row?.isFavorite == true {
                    favoriteEmission.fulfill()
                }
            },
            onError: { XCTFail("observation error: \($0)") }
        )
        defer { token.cancel() }

        await fulfillment(of: [firstEmission], timeout: 2.0)
        try await setFavorite(.event, id: "evt-fav-1")
        await fulfillment(of: [favoriteEmission], timeout: 2.0)
    }

    /// `onlyFavorites = true` is pushed into SQL via EXISTS; non-favorited rows are excluded.
    func testOnlyFavoritesFilterAppliesAtSqlLevel() async throws {
        let year = 2099
        let cal = Calendar.current
        let start = try XCTUnwrap(cal.date(from: DateComponents(year: year, month: 8, day: 30, hour: 10)))

        try await insertEvent(uid: "evt-favored", name: "Favored", year: year,
                              start: start, end: start.addingTimeInterval(3600))
        try await insertEvent(uid: "evt-unfavored", name: "Unfavored", year: year,
                              start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200))
        try await setFavorite(.event, id: "evt-favored")

        let bucket = try await observeOnce(filter: EventFilter(year: year, onlyFavorites: true))
        let uids = bucket.values.flatMap { $0.flatMap { $0.rows.map(\.object.event.uid) } }
        XCTAssertEqual(Set(uids), ["evt-favored"], "Only favored event should be included")
    }

    // MARK: - Utilities

    /// Wait for the first emission of the observation and return it.
    private func observeOnce(filter: EventFilter) async throws -> [Date: [EventHourSection]] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Date: [EventHourSection]], Error>) in
            var resumed = false
            let lock = NSLock()
            var capturedToken: PlayaDBObservationToken?
            let token = playaDB.observeEventsByDayThenHour(
                filter: filter,
                onChange: { bucket in
                    lock.lock()
                    if !resumed {
                        resumed = true
                        lock.unlock()
                        capturedToken?.cancel()
                        continuation.resume(returning: bucket)
                    } else {
                        lock.unlock()
                    }
                },
                onError: { error in
                    lock.lock()
                    if !resumed {
                        resumed = true
                        lock.unlock()
                        capturedToken?.cancel()
                        continuation.resume(throwing: error)
                    } else {
                        lock.unlock()
                    }
                }
            )
            capturedToken = token
        }
    }
}
