//
//  MapFavoriteEventFilterTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the window behind the map's "Today's Favorites Only" switch. The narrowing runs
//  in SQL from these two dates, so getting them wrong is the difference between a readable
//  map and every favourite of the week pinned at once.
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

    func testTodaysOnlyNarrowsToTheCurrentCalendarDay() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            showTodaysOnly: true,
            includeExpired: true,
            now: now,
            calendar: calendar
        )

        let start = try XCTUnwrap(filter.startDate)
        let end = try XCTUnwrap(filter.endDate)
        XCTAssertEqual(start, calendar.startOfDay(for: now))
        XCTAssertEqual(end.timeIntervalSince(start), 24 * 60 * 60,
                       "The window is exactly one day wide")
        XCTAssertTrue(filter.onlyFavorites)
    }

    /// The reported bug: a favourite weeks out staying on the map. The filter bounds the
    /// occurrence's *start*, so an event during the burn falls outside a pre-burn window.
    func testAnOccurrenceWeeksOutFallsOutsideTodaysWindow() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            showTodaysOnly: true,
            includeExpired: true,
            now: now,
            calendar: calendar
        )
        let start = try XCTUnwrap(filter.startDate)
        let end = try XCTUnwrap(filter.endDate)

        var burnDay = DateComponents()
        burnDay.year = 2026
        burnDay.month = 8
        burnDay.day = 31
        burnDay.hour = 9
        let weeksOut = try XCTUnwrap(calendar.date(from: burnDay))
        XCTAssertFalse((start..<end).contains(weeksOut))

        // …while something later today is inside it, so the switch isn't just "hide events".
        let laterToday = now.addingTimeInterval(3 * 60 * 60)
        XCTAssertTrue((start..<end).contains(laterToday))
    }

    /// An occurrence at one minute past midnight belongs to that day, and one at midnight
    /// tomorrow belongs to the next — the half-open window is what makes both true.
    func testWindowIsHalfOpenAroundMidnight() throws {
        let calendar = try playaCalendar()
        let now = try middayBeforeTheBurn()

        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            showTodaysOnly: true,
            includeExpired: true,
            now: now,
            calendar: calendar
        )
        let start = try XCTUnwrap(filter.startDate)
        let end = try XCTUnwrap(filter.endDate)

        XCTAssertTrue((start..<end).contains(start), "Midnight today is today")
        XCTAssertTrue((start..<end).contains(start.addingTimeInterval(60)))
        XCTAssertFalse((start..<end).contains(end), "Midnight tomorrow is tomorrow")
    }

    /// Switched off, the layer shows every favourited occurrence — no dates at all, so the
    /// SQL is left unbounded rather than bounded by a stale window.
    func testWithoutTodaysOnlyThereIsNoWindow() throws {
        let filter = PlayaDBAnnotationDataSource.favoriteEventFilter(
            showTodaysOnly: false,
            includeExpired: false,
            now: try middayBeforeTheBurn(),
            calendar: try playaCalendar()
        )
        XCTAssertNil(filter.startDate)
        XCTAssertNil(filter.endDate)
        XCTAssertTrue(filter.onlyFavorites)
        XCTAssertFalse(filter.includeExpired, "The expired-favorites preference still rides along")
    }
}
