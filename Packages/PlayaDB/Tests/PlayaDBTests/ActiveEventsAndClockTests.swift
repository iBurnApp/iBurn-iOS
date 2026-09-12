import XCTest
import GRDB
@testable import PlayaDB

/// `fetchActiveEvents` (running now or starting soon) and the package-wide `PlayaDBClock`.
final class ActiveEventsAndClockTests: XCTestCase {
    private var playaDB: PlayaDBImpl?
    private let now = Date(timeIntervalSince1970: 1_756_900_000) // fixed reference instant

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        PlayaDBClock.now = { Date() }
        playaDB = nil
        try await super.tearDown()
    }

    private func insertEvent(uid: String, start: Date, end: Date) async throws {
        let db = try XCTUnwrap(playaDB)
        try await db.dbQueue.write { conn in
            var event = EventObject(uid: uid, name: uid, year: 2026, eventTypeLabel: "Workshop", eventTypeCode: "work")
            try event.insert(conn)
            var occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
            try occurrence.insert(conn)
        }
    }

    private func seed() async throws {
        let h: TimeInterval = 3600
        try await insertEvent(uid: "running", start: now - h, end: now + h)
        try await insertEvent(uid: "starting-soon", start: now + 30 * 60, end: now + 2 * h)
        try await insertEvent(uid: "far-future", start: now + 3 * h, end: now + 4 * h)
        try await insertEvent(uid: "ended", start: now - 3 * h, end: now - h)
    }

    func testActiveEventsIncludeRunningAndStartingSoonOnly() async throws {
        try await seed()
        let db = try XCTUnwrap(playaDB)
        let uids = try await db.fetchActiveEvents(startingWithin: 1, from: now).map(\.event.uid)
        XCTAssertEqual(uids, ["running", "starting-soon"])
    }

    func testUpcomingEventsStillExcludeRunningOnes() async throws {
        try await seed()
        let db = try XCTUnwrap(playaDB)
        let uids = try await db.fetchUpcomingEvents(within: 1, from: now).map(\.event.uid)
        XCTAssertEqual(uids, ["starting-soon"])
    }

    func testNotExpiredFollowsThePackageClock() async throws {
        try await seed()
        let db = try XCTUnwrap(playaDB)
        PlayaDBClock.now = { [now] in now }
        let liveUIDs = try await db.dbQueue.read { conn in
            try EventOccurrence.all().notExpired().fetchAll(conn).map(\.eventId)
        }
        XCTAssertEqual(Set(liveUIDs), ["running", "starting-soon", "far-future"])

        PlayaDBClock.now = { [now] in now + 5 * 3600 }
        let laterUIDs = try await db.dbQueue.read { conn in
            try EventOccurrence.all().notExpired().fetchAll(conn).map(\.eventId)
        }
        XCTAssertEqual(laterUIDs, [])
    }
}
