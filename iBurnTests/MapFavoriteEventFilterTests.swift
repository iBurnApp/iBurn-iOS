//
//  MapFavoriteEventFilterTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the window behind the map's favourited-events layer. The narrowing runs in SQL
//  from this interval, so getting it wrong is the difference between a readable map and
//  every favourite of the week pinned at once.
//

import Foundation
import XCTest
@testable import iBurn

final class MapFavoriteEventFilterTests: XCTestCase {

    private func playaCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        return calendar
    }

    /// 2026-08-10 14:30 Pacific — three weeks before gates, which is when a favourited
    /// burn-week event must *not* be on the map.
    private func middayBeforeTheBurn() throws -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        components.hour = 14
        components.minute = 30
        return try XCTUnwrap(playaCalendar().date(from: components))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return try XCTUnwrap(playaCalendar().date(from: components))
    }

    // MARK: - The SQL window

    func testTheWindowEndsAtMidnightAndStartsAtTheGraceEdge() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: true,
            now: now,
            calendar: calendar
        )

        let window = try XCTUnwrap(filter.activeWindow)
        XCTAssertEqual(window.end,
                       try XCTUnwrap(calendar.date(byAdding: .day, value: 1,
                                                   to: calendar.startOfDay(for: now))),
                       "The window still runs to the end of today")
        XCTAssertEqual(window.start,
                       now.addingTimeInterval(-PlayaDBAnnotationDataSource.recentlyEndedGrace),
                       "…and its front edge is the grace edge, not the top of the day")
        XCTAssertTrue(filter.onlyFavorites)
    }

    /// Early in the morning the grace edge is still before midnight, so the day boundary wins
    /// and the window can't reach back into yesterday.
    func testTheWindowNeverReachesBackIntoYesterday() throws {
        let calendar = try playaCalendar()
        let now = try date(year: 2026, month: 8, day: 10, hour: 0, minute: 20)

        let window = try XCTUnwrap(PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: true, now: now, calendar: calendar
        ).activeWindow)

        XCTAssertEqual(window.start, calendar.startOfDay(for: now))
    }

    /// There is no "show me the whole week" escape any more: the layer is always today's.
    func testTheWindowIsAppliedUnconditionally() throws {
        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: false,
            now: try middayBeforeTheBurn(),
            calendar: try playaCalendar()
        )
        XCTAssertNotNil(filter.activeWindow)
        XCTAssertTrue(filter.onlyFavorites)
        XCTAssertFalse(filter.includeExpired, "The expired-favorites preference still rides along")
    }

    /// Start-time bucketing would drop an occurrence already in progress, which is exactly
    /// the one worth walking to — so the filter uses the overlap window, not startDate/endDate.
    func testTheWindowIsAnOverlapWindowNotAStartTimeRange() throws {
        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: true,
            now: try middayBeforeTheBurn(),
            calendar: try playaCalendar()
        )
        XCTAssertNil(filter.startDate)
        XCTAssertNil(filter.endDate)
    }

    // MARK: - The in-memory rule the window is built from

    /// The reported bug: a favourite weeks out staying on the map. Favourites are per
    /// occurrence, so a Wednesday-of-the-burn set must not pin the map three weeks earlier.
    func testAnOccurrenceWeeksOutIsNotToday() throws {
        let now = try middayBeforeTheBurn()
        let burnNight = try date(year: 2026, month: 8, day: 31, hour: 21)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceIsToday(
            startDate: burnNight,
            endDate: burnNight.addingTimeInterval(2 * 60 * 60),
            now: now,
            calendar: try playaCalendar()
        ))
    }

    func testAnOccurrenceLaterTodayIsToday() throws {
        let now = try middayBeforeTheBurn()
        let laterToday = now.addingTimeInterval(3 * 60 * 60)

        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceIsToday(
            startDate: laterToday,
            endDate: laterToday.addingTimeInterval(60 * 60),
            now: now,
            calendar: try playaCalendar()
        ))
    }

    /// Overlap, not start time: a set that began at 11pm yesterday and runs to 2am is on
    /// tonight's map while it runs — the case a `startDate >= startOfDay` bound would drop.
    func testAnOccurrenceRunningAcrossMidnightCountsOnBothDays() throws {
        let calendar = try playaCalendar()
        let start = try date(year: 2026, month: 8, day: 10, hour: 23)
        let end = try date(year: 2026, month: 8, day: 11, hour: 2)

        let lastNight = try date(year: 2026, month: 8, day: 10, hour: 23, minute: 30)
        let earlyHours = try date(year: 2026, month: 8, day: 11, hour: 1)

        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceIsToday(
            startDate: start, endDate: end, now: lastNight, calendar: calendar))
        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceIsToday(
            startDate: start, endDate: end, now: earlyHours, calendar: calendar))
    }

    /// Yesterday's finished occurrence is gone the moment the day turns over.
    func testYesterdaysFinishedOccurrenceIsNotToday() throws {
        let calendar = try playaCalendar()
        let start = try date(year: 2026, month: 8, day: 10, hour: 9)
        let end = try date(year: 2026, month: 8, day: 10, hour: 11)
        let today = try date(year: 2026, month: 8, day: 11, hour: 9)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceIsToday(
            startDate: start, endDate: end, now: today, calendar: calendar))
    }

    // MARK: - The grace period for occurrences that just ended

    /// The reported bug in its second form: this morning's workshop still pinned at 2pm.
    func testAnOccurrenceThatEndedHoursAgoIsOffTheMap() throws {
        let now = try middayBeforeTheBurn()
        let end = now.addingTimeInterval(-3 * 60 * 60)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: end.addingTimeInterval(-60 * 60),
            endDate: end,
            now: now,
            calendar: try playaCalendar()
        ))
    }

    /// …but the set you were walking to twenty minutes ago is still worth a red pin.
    func testAnOccurrenceThatJustEndedStaysOnTheMap() throws {
        let now = try middayBeforeTheBurn()
        let end = now.addingTimeInterval(-20 * 60)

        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: end.addingTimeInterval(-60 * 60),
            endDate: end,
            now: now,
            calendar: try playaCalendar()
        ))
    }

    /// The boundary is exclusive: at exactly one hour past the end time the pin is gone.
    func testTheGraceBoundaryIsExactlyAnHour() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()
        let grace = PlayaDBAnnotationDataSource.recentlyEndedGrace
        XCTAssertEqual(grace, 60 * 60)

        let atTheEdge = now.addingTimeInterval(-grace)
        let justInside = now.addingTimeInterval(-grace + 1)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: atTheEdge.addingTimeInterval(-3600), endDate: atTheEdge,
            now: now, calendar: calendar))
        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: justInside.addingTimeInterval(-3600), endDate: justInside,
            now: now, calendar: calendar))
    }

    /// Grace only ever removes finished things. Anything still running, or yet to start, is
    /// untouched by it.
    func testRunningAndNotYetStartedOccurrencesAreUnaffected() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: now.addingTimeInterval(-4 * 60 * 60),
            endDate: now.addingTimeInterval(60 * 60),
            now: now, calendar: calendar), "A long set still in progress stays")
        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: now.addingTimeInterval(3 * 60 * 60),
            endDate: now.addingTimeInterval(4 * 60 * 60),
            now: now, calendar: calendar), "Tonight's favourite is still tonight's")
    }

    /// The day rule outranks the grace: an occurrence that ended ten minutes before midnight
    /// is inside the grace at 00:05, but it is not today's any more.
    func testGraceDoesNotResurrectYesterdaysOccurrence() throws {
        let calendar = try playaCalendar()
        let now = try date(year: 2026, month: 8, day: 11, hour: 0, minute: 5)
        let end = try date(year: 2026, month: 8, day: 10, hour: 23, minute: 55)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: end.addingTimeInterval(-3600), endDate: end,
            now: now, calendar: calendar))
    }

    /// Favourites are per occurrence (`EventFavoriteKey` embeds the start instant), so two
    /// showings of the same event are judged one at a time: the noon one ages off while the
    /// evening one waits its turn.
    func testTwoOccurrencesOfOneEventAreJudgedIndependently() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let noonStart = try date(year: 2026, month: 8, day: 10, hour: 10)
        let noonEnd = try date(year: 2026, month: 8, day: 10, hour: 11)
        let eveningStart = try date(year: 2026, month: 8, day: 10, hour: 20)
        let eveningEnd = try date(year: 2026, month: 8, day: 10, hour: 22)

        XCTAssertFalse(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: noonStart, endDate: noonEnd, now: now, calendar: calendar))
        XCTAssertTrue(PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
            startDate: eveningStart, endDate: eveningEnd, now: now, calendar: calendar))
    }

    /// The in-memory rule and the SQL window are the same predicate; if they drift, a pin
    /// the query fetched would survive the re-check (or vice versa).
    func testTheInMemoryRuleAgreesWithTheQueryWindow() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()
        let window = try XCTUnwrap(PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: true, now: now, calendar: calendar
        ).activeWindow)

        let cases: [(Date, Date)] = [
            (try date(year: 2026, month: 8, day: 10, hour: 9), try date(year: 2026, month: 8, day: 10, hour: 11)),
            (try date(year: 2026, month: 8, day: 10, hour: 13), try date(year: 2026, month: 8, day: 10, hour: 14, minute: 20)),
            (try date(year: 2026, month: 8, day: 10, hour: 12), try date(year: 2026, month: 8, day: 10, hour: 15)),
            (try date(year: 2026, month: 8, day: 9, hour: 23), try date(year: 2026, month: 8, day: 10, hour: 1)),
            (try date(year: 2026, month: 8, day: 10, hour: 23), try date(year: 2026, month: 8, day: 11, hour: 2)),
            (try date(year: 2026, month: 8, day: 12, hour: 9), try date(year: 2026, month: 8, day: 12, hour: 10)),
            (try date(year: 2026, month: 8, day: 9, hour: 9), try date(year: 2026, month: 8, day: 9, hour: 10))
        ]
        for (start, end) in cases {
            let sqlWouldMatch = start < window.end && end > window.start
            XCTAssertEqual(
                PlayaDBAnnotationDataSource.occurrenceBelongsOnMap(
                    startDate: start, endDate: end, now: now, calendar: calendar),
                sqlWouldMatch,
                "Disagreement for \(start)–\(end)"
            )
        }
    }
}
