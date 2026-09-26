import XCTest
import GRDB
@testable import PlayaDB
import PlayaAPI

/// Festival days and hours are Black Rock City days and hours, whatever zone the device is
/// set to. Every test here runs with the process default zone forced to Tokyo (UTC+9, no
/// DST), where a BRC evening is already the next morning: before these fixes the day
/// buckets, `EventFilter.forDay` and `fetchEvents(on:)` all used `Calendar.current`, so a
/// 9 PM Thursday event was filed under Friday, in a 1 PM section.
final class BlackRockCityTimeTests: XCTestCase {

    private var savedTimeZone: TimeZone!

    override func setUpWithError() throws {
        try super.setUpWithError()
        savedTimeZone = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
    }

    override func tearDown() {
        NSTimeZone.default = savedTimeZone
        super.tearDown()
    }

    // MARK: - Fixtures

    /// A BRC wall-clock instant during the 2026 event.
    private func brc(day: Int, hour: Int, minute: Int = 0) throws -> Date {
        try XCTUnwrap(Calendar.burningMan.date(from: DateComponents(
            year: 2026, month: 9, day: day, hour: hour, minute: minute
        )))
    }

    private func brcMidnight(day: Int) throws -> Date {
        try brc(day: day, hour: 0)
    }

    private func makeRow(uid: String, start: Date) -> ListRow<EventObjectOccurrence> {
        let event = EventObject(uid: uid, name: "Test \(uid)", year: 2026,
                                eventTypeLabel: "Workshop", eventTypeCode: "work")
        let occurrence = EventOccurrence(eventId: uid, startTime: start,
                                         endTime: start.addingTimeInterval(3600))
        return ListRow(object: EventObjectOccurrence(event: event, occurrence: occurrence),
                       metadata: nil, thumbnailColors: nil)
    }

    // MARK: - Shared definition

    func testBurningManTimeZoneIsLosAngeles() {
        XCTAssertEqual(TimeZone.burningMan.identifier, "America/Los_Angeles")
        XCTAssertEqual(Calendar.burningMan.timeZone, TimeZone.burningMan)
        XCTAssertEqual(DateFormatter.playaTimeZone, TimeZone.burningMan)
    }

    /// Sanity check the premise: in Tokyo, a 9 PM Thursday BRC event is Friday afternoon.
    func testPremise_deviceCalendarDisagreesWithBRC() throws {
        let thursdayNine = try brc(day: 3, hour: 21)
        XCTAssertEqual(Calendar.current.timeZone.identifier, "Asia/Tokyo")
        XCTAssertEqual(Calendar.current.component(.day, from: thursdayNine), 4)
        XCTAssertEqual(Calendar.burningMan.component(.day, from: thursdayNine), 3)
    }

    // MARK: - Day then hour buckets

    func testBucketByDayThenHour_usesBRCDaysAndHours() throws {
        let thursdayMorning = makeRow(uid: "thu-10am", start: try brc(day: 3, hour: 10))
        let thursdayNight = makeRow(uid: "thu-9pm", start: try brc(day: 3, hour: 21, minute: 30))
        let fridayEarly = makeRow(uid: "fri-1am", start: try brc(day: 4, hour: 1))

        let bucket = PlayaDBImpl.bucketByDayThenHour([thursdayMorning, thursdayNight, fridayEarly])

        XCTAssertEqual(Set(bucket.keys), [try brcMidnight(day: 3), try brcMidnight(day: 4)],
                       "Day keys are BRC midnights")

        let thursday = try XCTUnwrap(bucket[try brcMidnight(day: 3)])
        XCTAssertEqual(thursday.map(\.hour), [10, 21], "Hours are BRC hours")
        XCTAssertEqual(thursday.flatMap { $0.rows.map(\.object.event.uid) }, ["thu-10am", "thu-9pm"])

        let friday = try XCTUnwrap(bucket[try brcMidnight(day: 4)])
        XCTAssertEqual(friday.map(\.hour), [1])
        XCTAssertEqual(friday.first?.rows.map(\.object.event.uid), ["fri-1am"])
    }

    func testGroupByHour_usesBRCHours() throws {
        let sections = PlayaDBImpl.groupByHour([
            makeRow(uid: "noon", start: try brc(day: 3, hour: 12)),
            makeRow(uid: "nine", start: try brc(day: 3, hour: 21)),
        ])
        XCTAssertEqual(sections.map(\.hour), [12, 21])
    }

    // MARK: - Day filter

    func testEventFilterForDay_spansTheBRCDay() throws {
        // Any instant during BRC Thursday — here 11 PM, which is Friday afternoon in Tokyo.
        let filter = EventFilter.forDay(try brc(day: 3, hour: 23))
        XCTAssertEqual(filter.startDate, try brcMidnight(day: 3))
        XCTAssertEqual(filter.endDate, try brcMidnight(day: 4))
    }

    func testFetchEventsOnDay_usesBRCDay() async throws {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        let fixtures: [(uid: String, start: Date)] = [
            ("wed-11pm", try brc(day: 2, hour: 23)),
            ("thu-9am", try brc(day: 3, hour: 9)),
            ("thu-9pm", try brc(day: 3, hour: 21)),
            ("fri-noon", try brc(day: 4, hour: 12)),
        ]
        try await playaDB.dbQueue.write { db in
            for fixture in fixtures {
                var event = EventObject(uid: fixture.uid, name: fixture.uid, year: 2026,
                                        eventTypeLabel: "Workshop", eventTypeCode: "work")
                try event.insert(db)
                // 30 minutes, so nothing overlaps into the neighbouring BRC day.
                var occurrence = EventOccurrence(eventId: fixture.uid, startTime: fixture.start,
                                                 endTime: fixture.start.addingTimeInterval(1800))
                try occurrence.insert(db)
            }
        }

        let thursday = try await playaDB.fetchEvents(on: try brc(day: 3, hour: 12))
        XCTAssertEqual(Set(thursday.map(\.event.uid)), ["thu-9am", "thu-9pm"])
    }

    // MARK: - Starting within

    func testStartingWithinHours_isElapsedTime() async throws {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        let now = try brc(day: 3, hour: 20)
        try await playaDB.dbQueue.write { db in
            for (uid, offset) in [("in-1h59", 119.0 * 60), ("in-2h01", 121.0 * 60)] {
                var event = EventObject(uid: uid, name: uid, year: 2026,
                                        eventTypeLabel: "Workshop", eventTypeCode: "work")
                try event.insert(db)
                var occurrence = EventOccurrence(eventId: uid,
                                                 startTime: now.addingTimeInterval(offset),
                                                 endTime: now.addingTimeInterval(offset + 3600))
                try occurrence.insert(db)
            }
        }
        let soon = try await playaDB.dbQueue.read { db in
            try EventOccurrence.all().startingWithin(hours: 2, from: now).fetchAll(db)
        }
        XCTAssertEqual(soon.map(\.eventId), ["in-1h59"])
    }
}
