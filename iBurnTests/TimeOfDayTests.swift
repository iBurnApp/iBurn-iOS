//
//  TimeOfDayTests.swift
//  iBurnTests
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn

final class TimeOfDayTests: XCTestCase {

    private var brcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .burningManTimeZone
        return c
    }

    /// A moment comfortably inside the festival (~2.5 days after gates).
    private var midFestival: Date {
        YearSettings.eventStart.addingTimeInterval(2.5 * 86400)
    }

    func testNowWindowIsNextTwoHours() {
        let now = midFestival
        let window = TimeOfDay.now.dateWindow(now: now)
        XCTAssertEqual(window.start, now)
        XCTAssertEqual(window.end.timeIntervalSince(now), 2 * 3600, accuracy: 1)
    }

    func testAllPeriodsHaveStartBeforeOrEqualEnd() {
        let now = midFestival
        for tod in TimeOfDay.allCases {
            let window = tod.dateWindow(now: now)
            XCTAssertLessThanOrEqual(window.start, window.end, "\(tod) start should be <= end")
        }
    }

    func testNamedPeriodsAreOrderedAcrossTheDay() {
        let now = midFestival
        let order: [TimeOfDay] = [.sunrise, .morning, .midday, .afternoon, .evening, .night]
        let starts = order.map { $0.dateWindow(now: now).start }
        for i in 1..<starts.count {
            XCTAssertLessThan(starts[i - 1], starts[i], "\(order[i - 1]) should start before \(order[i])")
        }
    }

    func testLateNightSpillsIntoNextDay() {
        let now = midFestival
        let night = TimeOfDay.night.dateWindow(now: now)
        let late = TimeOfDay.lateNight.dateWindow(now: now)
        XCTAssertGreaterThanOrEqual(late.start, night.start)

        let anchorDay = brcCalendar.startOfDay(for: now)
        guard let nextDay = brcCalendar.date(byAdding: .day, value: 1, to: anchorDay) else {
            return XCTFail("Could not compute next day")
        }
        XCTAssertEqual(brcCalendar.startOfDay(for: late.start), nextDay,
                       "late night should fall on the next calendar day")
    }

    func testWindowsClampToFestivalRange() {
        let beforeSeason = YearSettings.eventStart.addingTimeInterval(-10 * 86400)
        let window = TimeOfDay.now.dateWindow(now: beforeSeason)
        XCTAssertEqual(window.start, YearSettings.eventStart)
        XCTAssertEqual(window.end, YearSettings.eventStart)
    }

    func testContainsNowIsTrueForNowHorizon() {
        XCTAssertTrue(TimeOfDay.now.containsNow(midFestival))
    }
}
