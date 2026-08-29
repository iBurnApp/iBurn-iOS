//
//  EventListDurationFilterTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/18/26.
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

/// Covers the Events-tab max-duration preference: the 6h default (fresh + existing installs),
/// that it flows into both the browse and search observations, and that persistence keeps an
/// explicit "Any" distinct from the default.
@MainActor
final class EventListDurationFilterTests: XCTestCase {

    // MARK: - Helpers

    private func uniqueKey() -> String {
        "EventListDurationFilterTests.\(UUID().uuidString)"
    }

    private func makeProvider() throws -> RecordingEventDataProvider {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return RecordingEventDataProvider(playaDB: playaDB)
    }

    private func makeViewModel(
        provider: RecordingEventDataProvider,
        key: String,
        hasEnteredRegion: Bool = true
    ) -> EventListViewModel {
        EventListViewModel(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            regionStatus: MockRegionStatusService(hasEnteredBurningManRegion: hasEnteredRegion),
            filterStorageKey: key,
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

    // MARK: - Default (fresh install)

    func testFreshInstallDefaultsToSixHourMaxDuration() throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, key: uniqueKey())

        XCTAssertEqual(vm.filter.maxDuration, EventListViewModel.defaultMaxDuration)
        XCTAssertEqual(EventListViewModel.defaultMaxDuration, 6 * 3600)
    }

    func testBrowseObservationCarriesSixHourDefault() async throws {
        let provider = try makeProvider()
        // Retain the view model: its observation task bails via `guard let self` once the
        // VM deallocates, so the filter would never be recorded if it weren't kept alive.
        let vm = makeViewModel(provider: provider, key: uniqueKey())

        let observed = await eventually { !provider.dayThenHourFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.dayThenHourFilters.last)
        XCTAssertEqual(observedFilter.maxDuration, EventListViewModel.defaultMaxDuration)
        XCTAssertEqual(vm.filter.maxDuration, EventListViewModel.defaultMaxDuration)
    }

    func testSearchObservationCarriesSixHourDefault() async throws {
        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, key: uniqueKey())

        vm.searchText = "yoga"

        let observed = await eventually { !provider.flatFilters.isEmpty }
        XCTAssertTrue(observed)

        let observedFilter = try XCTUnwrap(provider.flatFilters.last)
        XCTAssertEqual(observedFilter.searchText, "yoga")
        XCTAssertEqual(observedFilter.maxDuration, EventListViewModel.defaultMaxDuration)
    }

    // MARK: - Default (existing install)

    /// A pre-existing install has a persisted EventFilter blob that predates `maxDuration`
    /// (and therefore no stored duration preference). It must still adopt the 6h default.
    func testExistingInstallWithoutStoredDurationDefaultsToSixHours() throws {
        let key = uniqueKey()

        // Simulate a legacy blob written before maxDuration existed.
        let legacy = EventFilter(includeExpired: false, eventTypeCodes: ["work", "food"])
        let data = try JSONEncoder().encode(legacy)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.removeObject(forKey: "\(key).maxDuration")

        let provider = try makeProvider()
        let vm = makeViewModel(provider: provider, key: key)

        XCTAssertEqual(vm.filter.maxDuration, EventListViewModel.defaultMaxDuration)
        // Other persisted preferences still load unchanged.
        XCTAssertFalse(vm.filter.includeExpired)
        XCTAssertEqual(vm.filter.eventTypeCodes, ["work", "food"])
    }

    // MARK: - Persistence round-trip

    func testCustomDurationPersistsAcrossViewModels() throws {
        let key = uniqueKey()

        let vm1 = makeViewModel(provider: try makeProvider(), key: key)
        vm1.filter.maxDuration = 3 * 3600

        let vm2 = makeViewModel(provider: try makeProvider(), key: key)
        XCTAssertEqual(vm2.filter.maxDuration, 3 * 3600)
    }

    /// Choosing "Any" (no limit) must round-trip as `nil` — NOT be re-coerced to the 6h
    /// default. This is the case the same-blob persistence approach cannot represent, because
    /// synthesized Codable omits nil optionals.
    func testExplicitAnyPersistsAsNoLimit() throws {
        let key = uniqueKey()

        let vm1 = makeViewModel(provider: try makeProvider(), key: key)
        vm1.filter.maxDuration = nil

        let vm2 = makeViewModel(provider: try makeProvider(), key: key)
        XCTAssertNil(vm2.filter.maxDuration)
    }
}
