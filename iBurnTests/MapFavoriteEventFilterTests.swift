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

    func testTheWindowIsExactlyTheCurrentCalendarDay() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            includeExpired: true,
            now: now,
            calendar: calendar
        )

        let window = try XCTUnwrap(filter.activeWindow)
        XCTAssertEqual(window.start, calendar.startOfDay(for: now))
        XCTAssertEqual(window.duration, 24 * 60 * 60, "The window is exactly one day wide")
        XCTAssertTrue(filter.onlyFavorites)
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
            (try date(year: 2026, month: 8, day: 9, hour: 23), try date(year: 2026, month: 8, day: 10, hour: 1)),
            (try date(year: 2026, month: 8, day: 10, hour: 23), try date(year: 2026, month: 8, day: 11, hour: 2)),
            (try date(year: 2026, month: 8, day: 12, hour: 9), try date(year: 2026, month: 8, day: 12, hour: 10)),
            (try date(year: 2026, month: 8, day: 9, hour: 9), try date(year: 2026, month: 8, day: 9, hour: 10))
        ]
        for (start, end) in cases {
            let sqlWouldMatch = start < window.end && end > window.start
            XCTAssertEqual(
                PlayaDBAnnotationDataSource.occurrenceIsToday(
                    startDate: start, endDate: end, now: now, calendar: calendar),
                sqlWouldMatch,
                "Disagreement for \(start)–\(end)"
            )
        }
    }
}
