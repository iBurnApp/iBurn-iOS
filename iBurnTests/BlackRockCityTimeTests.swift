//
//  BlackRockCityTimeTests.swift
//  iBurnTests
//
//  Festival dates are Black Rock City dates, whatever zone the device is set to.
//

import Dispatch
import Foundation
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB
import PlayaAPI

// MARK: - Test Doubles

private struct AlwaysOnPlaya: RegionStatusService {
    var hasEnteredBurningManRegion: Bool { true }
}

/// Emits one fixed day bucket from the browse observation.
private final class FixedBucketEventDataProvider: EventDataProvider {
    var bucket: [Date: [EventHourSection]] = [:]

    override func observeObjectsByDayThenHour(filter: EventFilter) -> AsyncStream<[Date: [EventHourSection]]> {
        let bucket = bucket
        return AsyncStream { continuation in
            continuation.yield(bucket)
            continuation.finish()
        }
    }

    override func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        AsyncStream { $0.finish() }
    }

    override func isDatabaseSeeded() async -> Bool { true }
}

// MARK: - Tests

/// Regression tests for the "device time zone vs Black Rock City time" sweep. Each test pins
/// the process zone away from Pacific — Honolulu (UTC−10, west of BRC, where a BRC midnight is
/// still the previous evening) or Tokyo (UTC+9, where a BRC evening is the next day) — and uses
/// the production default calendars, as the app does.
@MainActor
final class BlackRockCityTimeTests: XCTestCase {

    private var savedTimeZone: TimeZone!

    override func setUp() {
        super.setUp()
        savedTimeZone = NSTimeZone.default
    }

    override func tearDown() {
        NSTimeZone.default = savedTimeZone
        super.tearDown()
    }

    private func setDeviceZone(_ identifier: String) throws {
        NSTimeZone.default = try XCTUnwrap(TimeZone(identifier: identifier))
        XCTAssertEqual(Calendar.current.timeZone.identifier, identifier)
    }

    /// A BRC wall-clock instant.
    private func brc(month: Int = 9, day: Int, hour: Int, minute: Int = 0) throws -> Date {
        try XCTUnwrap(Calendar.burningMan.date(from: DateComponents(
            year: 2026, month: month, day: day, hour: hour, minute: minute
        )))
    }

    // MARK: - Shared definition

    func testAppReusesSharedBurningManTimeZone() {
        XCTAssertEqual(TimeZone.burningMan.identifier, "America/Los_Angeles")
        XCTAssertEqual(NSTimeZone.brc_burningManTimeZone as TimeZone, TimeZone.burningMan)
        XCTAssertEqual(DateFormatter.eventGroupDateFormatter.timeZone, TimeZone.burningMan)
    }

    // MARK: - Festival day list

    func testFestivalDaysAreBRCMidnightsInAnyZone() throws {
        for zone in ["Pacific/Honolulu", "Asia/Tokyo", "America/New_York"] {
            try setDeviceZone(zone)
            let days = YearSettings.festivalDays(from: try brc(month: 8, day: 30, hour: 0),
                                                 to: try brc(day: 7, hour: 0))
            XCTAssertEqual(days.count, 9, "Sun Aug 30 through Mon Sep 7, end-inclusive (\(zone))")
            XCTAssertEqual(days.first, try brc(month: 8, day: 30, hour: 0))
            XCTAssertEqual(days.last, try brc(day: 7, hour: 0))
            for day in days {
                XCTAssertEqual(Calendar.burningMan.startOfDay(for: day), day,
                               "Every festival day is a BRC midnight (\(zone))")
            }
            XCTAssertEqual(days.map { Calendar.burningMan.component(.weekday, from: $0) },
                           [1, 2, 3, 4, 5, 6, 7, 1, 2], "Sunday through Monday (\(zone))")
        }
    }

    func testShippedFestivalDaysAreBRCMidnights() throws {
        try setDeviceZone("Pacific/Honolulu")
        let days = YearSettings.festivalDays
        XCTAssertFalse(days.isEmpty)
        for day in days {
            XCTAssertEqual(Calendar.burningMan.startOfDay(for: day), day)
        }
    }

    // MARK: - Events tab

    /// The day picker hands the view model a festival day (a BRC midnight) and the view model
    /// looks it up in PlayaDB's day buckets (also BRC midnights). With a device calendar in
    /// Honolulu, `startOfDay` of a BRC midnight is the *previous* Honolulu midnight, so every
    /// day tab came up empty.
    func testEventListSelectedDayFindsItsBRCBucket() async throws {
        try setDeviceZone("Pacific/Honolulu")
        let wednesday = try brc(day: 2, hour: 0)
        let thursday = try brc(day: 3, hour: 0)

        let provider = FixedBucketEventDataProvider(playaDB: try PlayaDBImpl(dbPath: ":memory:"))
        provider.bucket = [
            wednesday: [EventHourSection(hour: 9, rows: [])],
            thursday: [EventHourSection(hour: 21, rows: [])],
        ]
        let key = "BlackRockCityTimeTests.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let vm = EventListViewModel(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            regionStatus: AlwaysOnPlaya(),
            filterStorageKey: key,
            festivalDays: YearSettings.festivalDays
        )

        let delivered = await eventually { !vm.dayBuckets.isEmpty }
        XCTAssertTrue(delivered)

        vm.selectedDay = thursday
        XCTAssertEqual(vm.browseSections.map(\.hour), [21])
        vm.selectedDay = wednesday
        XCTAssertEqual(vm.browseSections.map(\.hour), [9])
    }

    func testEventDayPickerLabelsInBRCTime() throws {
        try setDeviceZone("Pacific/Honolulu")
        let sunday = try brc(month: 8, day: 30, hour: 0)
        let reference = DateFormatter()
        reference.locale = EventDayPickerView.weekdayFormatter.locale
        reference.timeZone = TimeZone.burningMan
        reference.dateFormat = "EEE"
        XCTAssertEqual(EventDayPickerView.weekdayFormatter.string(from: sunday),
                       reference.string(from: sunday))
        XCTAssertEqual(EventDayPickerView.dayNumberFormatter.string(from: sunday), "30",
                       "Sun Aug 30 BRC is Sat Aug 29 in Honolulu; the chip must say 30")
    }

    // MARK: - Detail "Today" / "Tomorrow"

    func testDetailTodayAndTomorrowAreBRCDays() throws {
        try setDeviceZone("Asia/Tokyo")
        // Thursday 10 PM on playa: Friday 2 PM in Tokyo.
        let now = try brc(day: 3, hour: 22)
        let laterTonight = try brc(day: 3, hour: 23)
        let fridayMorning = try brc(day: 4, hour: 9)
        let saturday = try brc(day: 5, hour: 9)

        let tonight = DetailViewModel.formatEventTimeAndDuration(
            startDate: laterTonight, endDate: laterTonight.addingTimeInterval(3600), now: now)
        XCTAssertTrue(tonight.hasPrefix("Today at "), tonight)

        let tomorrow = DetailViewModel.formatEventTimeAndDuration(
            startDate: fridayMorning, endDate: fridayMorning.addingTimeInterval(3600), now: now)
        XCTAssertTrue(tomorrow.hasPrefix("Tomorrow at "), tomorrow)

        let later = DetailViewModel.formatEventTimeAndDuration(
            startDate: saturday, endDate: saturday.addingTimeInterval(3600), now: now)
        XCTAssertFalse(later.hasPrefix("Today") || later.hasPrefix("Tomorrow"), later)
    }

    // MARK: - Map "today"

    func testMapTodayWindowIsTheBRCDay() throws {
        try setDeviceZone("Asia/Tokyo")
        let window = PlayaDBAnnotationDataSource.todayWindow(now: try brc(day: 3, hour: 22))
        XCTAssertEqual(window.start, try brc(day: 3, hour: 0))
        XCTAssertEqual(window.end, try brc(day: 4, hour: 0))
    }

    // MARK: - Time shift

    func testTimeShiftQuickTimesAreBRCTimes() throws {
        try setDeviceZone("Asia/Tokyo")
        let thursdayFiveAM = try brc(day: 3, hour: 5)
        XCTAssertEqual(TimeShiftViewModel.next(hour: 7, after: thursdayFiveAM), try brc(day: 3, hour: 7))
        XCTAssertEqual(TimeShiftViewModel.next(hour: 19, after: thursdayFiveAM), try brc(day: 3, hour: 19))

        let thursdayTenPM = try brc(day: 3, hour: 22)
        XCTAssertEqual(TimeShiftViewModel.next(hour: 7, after: thursdayTenPM), try brc(day: 4, hour: 7))
        XCTAssertEqual(TimeShiftViewModel.next(hour: 12, after: thursdayTenPM), try brc(day: 4, hour: 12))
    }

    // MARK: - Helpers

    private func eventually(
        timeoutSeconds: TimeInterval = 1.0,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeoutSeconds * 1_000_000_000)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }
}
