import XCTest
@testable import PlayaDB

final class EventHourSectionTests: XCTestCase {

    private func makeRow(uid: String, hour: Int, minute: Int = 0) throws -> ListRow<EventObjectOccurrence> {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 24
        components.hour = hour
        components.minute = minute
        let start = try XCTUnwrap(Calendar.current.date(from: components))
        let end = start.addingTimeInterval(3600)

        let event = EventObject(
            uid: uid,
            name: "Test \(uid)",
            year: 2026,
            eventTypeLabel: "Workshop",
            eventTypeCode: "work"
        )
        let occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
        let combined = EventObjectOccurrence(event: event, occurrence: occurrence)
        return ListRow(object: combined, metadata: nil, thumbnailColors: nil)
    }

    func testGroupByHour_emptyInputProducesEmptyOutput() {
        XCTAssertTrue(PlayaDBImpl.groupByHour([]).isEmpty)
    }

    func testGroupByHour_singleHourYieldsSingleSection() throws {
        let row = try makeRow(uid: "e1", hour: 14)
        let sections = PlayaDBImpl.groupByHour([row])

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.hour, 14)
        XCTAssertEqual(sections.first?.rows.count, 1)
        XCTAssertEqual(sections.first?.rows.first?.object.event.uid, "e1")
    }

    func testGroupByHour_sortsAscendingAndPreservesRowOrder() throws {
        let r23 = try makeRow(uid: "e23", hour: 23)
        let r0 = try makeRow(uid: "e0", hour: 0)
        let r13a = try makeRow(uid: "e13a", hour: 13, minute: 0)
        let r13b = try makeRow(uid: "e13b", hour: 13, minute: 30)

        // Input order intentionally jumbled so the grouper must sort.
        let sections = PlayaDBImpl.groupByHour([r23, r0, r13a, r13b])

        XCTAssertEqual(sections.map(\.hour), [0, 13, 23], "Sections should be sorted ascending by hour")

        let thirteen = try XCTUnwrap(sections.first { $0.hour == 13 })
        XCTAssertEqual(
            thirteen.rows.map { $0.object.event.uid },
            ["e13a", "e13b"],
            "Row order within a section should match input order"
        )
    }
}
