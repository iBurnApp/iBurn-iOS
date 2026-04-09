import XCTest
@testable import PlayaDB

final class EventOccurrenceCorrectionTests: XCTestCase {

    // Use a fixed Playa calendar for all tests
    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }()

    private func makeDate(month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2025,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )
        return calendar.date(from: components)!
    }

    // MARK: - No Correction Needed

    func testNormalOccurrence_NoCorrection() {
        let start = makeDate(month: 8, day: 28, hour: 9, minute: 0)
        let end = makeDate(month: 8, day: 28, hour: 14, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, end)
    }

    func testShortEvent_NoCorrection() {
        let start = makeDate(month: 8, day: 26, hour: 10, minute: 0)
        let end = makeDate(month: 8, day: 26, hour: 10, minute: 15)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, end)
    }

    func testExactly24Hours_NoCorrection() {
        let start = makeDate(month: 8, day: 25, hour: 9, minute: 0)
        let end = makeDate(month: 8, day: 26, hour: 9, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, end)
    }

    func testMidnightCrossing_NoCorrection() {
        // 10pm to 2am next day = 4 hours, should not be corrected
        let start = makeDate(month: 8, day: 26, hour: 22, minute: 0)
        let end = makeDate(month: 8, day: 27, hour: 2, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, end)
    }

    // MARK: - Negative Duration Correction

    func testNegativeDuration_CorrectedToSameDay() {
        // API returns: start Aug 28 09:00, end Aug 24 14:00 (-91h)
        // Should correct to: end Aug 28 14:00 (5h)
        let start = makeDate(month: 8, day: 28, hour: 9, minute: 0)
        let end = makeDate(month: 8, day: 24, hour: 14, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        let expectedEnd = makeDate(month: 8, day: 28, hour: 14, minute: 0)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, expectedEnd)
    }

    func testNegativeDuration_MidnightCrossing() {
        // API returns: start Aug 26 21:00, end Aug 26 02:00 (-19h)
        // End time-of-day (02:00) < start time-of-day (21:00), crosses midnight
        // Should correct to: end Aug 27 02:00 (5h)
        let start = makeDate(month: 8, day: 26, hour: 21, minute: 0)
        let end = makeDate(month: 8, day: 26, hour: 2, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        let expectedEnd = makeDate(month: 8, day: 27, hour: 2, minute: 0)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, expectedEnd)
    }

    // MARK: - Excessive Duration Correction

    func testExcessiveDuration_CorrectedToSameDay() {
        // API returns: start Aug 25 09:00, end Aug 30 11:45 (122.75h)
        // Should correct to: end Aug 25 11:45 (2h 45m)
        let start = makeDate(month: 8, day: 25, hour: 9, minute: 0)
        let end = makeDate(month: 8, day: 30, hour: 11, minute: 45)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        let expectedEnd = makeDate(month: 8, day: 25, hour: 11, minute: 45)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, expectedEnd)
    }

    func testExcessiveDuration_MidnightCrossing() {
        // API returns: start Aug 25 22:00, end Aug 30 02:00
        // End time-of-day (02:00) < start time-of-day (22:00), crosses midnight
        // Should correct to: end Aug 26 02:00 (4h)
        let start = makeDate(month: 8, day: 25, hour: 22, minute: 0)
        let end = makeDate(month: 8, day: 30, hour: 2, minute: 0)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        let expectedEnd = makeDate(month: 8, day: 26, hour: 2, minute: 0)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, expectedEnd)
    }

    func testJustOver24Hours_Corrected() {
        // 24h 15m should trigger correction
        let start = makeDate(month: 8, day: 25, hour: 9, minute: 0)
        let end = makeDate(month: 8, day: 26, hour: 9, minute: 15)

        let result = PlayaDBImpl.correctedOccurrenceTimes(startTime: start, endTime: end, calendar: calendar)

        let expectedEnd = makeDate(month: 8, day: 25, hour: 9, minute: 15)
        XCTAssertEqual(result.startTime, start)
        XCTAssertEqual(result.endTime, expectedEnd)
    }
}
