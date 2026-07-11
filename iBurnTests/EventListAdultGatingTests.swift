//
//  EventListAdultGatingTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Dispatch
import Foundation
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

// MARK: - Test Doubles

private struct MockRegionStatusService: RegionStatusService {
    var hasEnteredBurningManRegion: Bool
}

/// Records the filters passed to each observation call and yields nothing.
private final class RecordingEventDataProvider: EventDataProvider {
    private(set) var dayThenHourFilters: [EventFilter] = []
    private(set) var flatFilters: [EventFilter] = []

    override func observeObjectsByDayThenHour(filter: EventFilter) -> AsyncStream<[Date: [EventHourSection]]> {
        dayThenHourFilters.append(filter)
        return AsyncStream { continuation in
            continuation.finish()
        }
    }

    override func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        flatFilters.append(filter)
        return AsyncStream { continuation in
            continuation.finish()
        }
    }

    override func isDatabaseSeeded() async -> Bool {
        true
    }
}

// MARK: - Tests

@MainActor
final class EventListAdultGatingTests: XCTestCase {

    private let adultCode = EventFilter.adultEventTypeCode

    // MARK: - Helpers

    private func makeProvider() throws -> RecordingEventDataProvider {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return RecordingEventDataProvider(playaDB: playaDB)
    }

    private func makeViewModel(
        provider: RecordingEventDataProvider,
        hasEnteredRegion: Bool
    ) -> EventListViewModel {
        EventListViewModel(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            regionStatus: MockRegionStatusService(hasEnteredBurningManRegion: hasEnteredRegion),
            filterStorageKey: "EventListAdultGatingTests.\(UUID().uuidString)",
            festivalDays: YearSettings.festivalDays
        )
    }

    private func eventually(
        timeoutSeconds: TimeInterval = 1.0,
        pollNanoseconds: UInt64 = 20_000_000,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let timeoutNanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }

    // MARK: - EventFilter.excludingAdultEvents

    func testExcludingAdultEventsWithNoTypeSelectionExcludesOnlyAdult() throws {
        let gated = EventFilter().excludingAdultEvents()

        let codes = try XCTUnwrap(gated.eventTypeCodes)
        XCTAssertFalse(codes.contains(adultCode))
        // Other known types remain visible
        XCTAssertTrue(codes.contains("work"))
        XCTAssertTrue(codes.contains("prty"))
        XCTAssertTrue(codes.contains("kid"))
    }

    func testExcludingAdultEventsRemovesAdultFromUserSelection() throws {
        var filter = EventFilter()
        filter.eventTypeCodes = ["work", adultCode]

        let gated = filter.excludingAdultEvents()

        XCTAssertEqual(gated.eventTypeCodes, ["work"])
    }

    func testExcludingAdultEventsLeavesNonAdultSelectionUntouched() throws {
        var filter = EventFilter()
        filter.eventTypeCodes = ["work", "food"]

        let gated = filter.excludingAdultEvents()

        XCTAssertEqual(gated.eventTypeCodes, ["work", "food"])
    }

    func testExcludingAdultEventsWithOnlyAdultSelectedMatchesNothing() throws {
        var filter = EventFilter()
        filter.eventTypeCodes = [adultCode]

        let gated = filter.excludingAdultEvents()

        // Must not collapse to nil/empty (PlayaDB treats those as "no filtering"),
        // and must not match any real event type. Matches legacy: selecting only
        // Mature Audiences outside the region shows an empty list.
        let codes = try XCTUnwrap(gated.eventTypeCodes)
        XCTAssertFalse(codes.isEmpty)
        XCTAssertFalse(codes.contains(adultCode))
        let realCodes: Set<String> = [
            "cere", "prty", "work", "game", "food", "perf", "care", "fire",
            "para", "kid", "none", "othr", "arts", "tea", "heal", "LGBT",
            "live", "RIDE", "repr", "sust", "yoga",
        ]
        XCTAssertTrue(codes.isDisjoint(with: realCodes))
    }

    // MARK: - EventListViewModel browse observation

    func testBrowseFilterExcludesAdultWhenOutsideRegion() async throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, hasEnteredRegion: false)

        let observed = await eventually { !provider.dayThenHourFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.dayThenHourFilters.last)
        let codes = try XCTUnwrap(observedFilter.eventTypeCodes)
        XCTAssertFalse(codes.contains(adultCode))

        // The gate is observation-only: the user-facing filter is not mutated,
        // so the filter sheet still reflects the user's own selection.
        XCTAssertNil(vm.filter.eventTypeCodes)
    }

    func testBrowseFilterKeepsAdultWhenInsideRegion() async throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, hasEnteredRegion: true)

        let observed = await eventually { !provider.dayThenHourFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.dayThenHourFilters.last)
        // No user type selection + unlocked region = no type filtering at all
        XCTAssertNil(observedFilter.eventTypeCodes)
        XCTAssertNil(vm.filter.eventTypeCodes)
    }

    // MARK: - EventListViewModel search observation

    func testSearchFilterExcludesAdultWhenOutsideRegion() async throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, hasEnteredRegion: false)

        vm.searchText = "disco"

        let observed = await eventually { !provider.flatFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.flatFilters.last)
        XCTAssertEqual(observedFilter.searchText, "disco")
        let codes = try XCTUnwrap(observedFilter.eventTypeCodes)
        XCTAssertFalse(codes.contains(adultCode))
    }

    func testSearchFilterKeepsAdultWhenInsideRegion() async throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, hasEnteredRegion: true)

        vm.searchText = "disco"

        let observed = await eventually { !provider.flatFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.flatFilters.last)
        XCTAssertEqual(observedFilter.searchText, "disco")
        XCTAssertNil(observedFilter.eventTypeCodes)
    }
}
