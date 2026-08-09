//
//  NearbyEventFilterTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the Nearby surfaces' event filter: the 6h duration cap applied in SQL (screen
//  AND map card), the persistence rules behind it, the shared window/ordering, and the
//  regression that nothing outside the now-window can reach the list.
//

import CoreLocation
import Dispatch
import Foundation
import MapKit
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

// MARK: - Test Doubles

/// Records the filters handed to `observeObjects` and lets the test push rows afterwards.
/// Both view models start their observations on the main actor, so no extra locking.
private final class RecordingNearbyEventProvider: EventDataProvider {
    private(set) var filters: [EventFilter] = []
    private var continuations: [AsyncStream<[ListRow<EventObjectOccurrence>]>.Continuation] = []

    override func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        filters.append(filter)
        return AsyncStream { continuation in
            continuations.append(continuation)
        }
    }

    override func isDatabaseSeeded() async -> Bool { true }

    /// Push a row set to every live observation.
    func emit(_ rows: [ListRow<EventObjectOccurrence>]) {
        for continuation in continuations { continuation.yield(rows) }
    }
}

// MARK: - Tests

@MainActor
final class NearbyEventFilterTests: XCTestCase {

    private let sixHours: TimeInterval = 6 * 3600

    // MARK: - Helpers

    private func makeDefaults() throws -> UserDefaults {
        let suite = "NearbyEventFilterTests.\(UUID().uuidString)"
        return try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    private func makeStore(
        defaults: UserDefaults,
        key: String = "nearbyEventFilter"
    ) -> NearbyEventFilterStore {
        NearbyEventFilterStore(storageKey: key, defaults: defaults)
    }

    private func makeProvider() throws -> RecordingNearbyEventProvider {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return RecordingNearbyEventProvider(playaDB: playaDB)
    }

    private func makeNearbyViewModel(
        eventProvider: RecordingNearbyEventProvider,
        store: NearbyEventFilterStore
    ) throws -> NearbyViewModel {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return NearbyViewModel(
            playaDB: playaDB,
            artProvider: ArtDataProvider(playaDB: playaDB),
            campProvider: CampDataProvider(playaDB: playaDB),
            eventProvider: eventProvider,
            locationProvider: MockLocationProvider(
                mockLocation: CLLocation(latitude: 40.7864, longitude: -119.2065)
            ),
            filterStore: store
        )
    }

    private func makeCardViewModel(
        eventProvider: RecordingNearbyEventProvider,
        store: NearbyEventFilterStore
    ) throws -> NearbyCardViewModel {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return NearbyCardViewModel(
            playaDB: playaDB,
            artProvider: ArtDataProvider(playaDB: playaDB),
            campProvider: CampDataProvider(playaDB: playaDB),
            eventProvider: eventProvider,
            locationProvider: MockLocationProvider(
                mockLocation: CLLocation(latitude: 40.7864, longitude: -119.2065)
            ),
            filterStore: store
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

    private func eventRow(
        _ uid: String,
        start: Date,
        end: Date,
        latitude: Double = 40.7864,
        longitude: Double = -119.2065
    ) -> ListRow<EventObjectOccurrence> {
        let event = EventObject(
            uid: uid,
            name: uid,
            year: 2025,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )
        let occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
        return ListRow(
            object: EventObjectOccurrence(event: event, occurrence: occurrence, host: nil),
            metadata: nil,
            thumbnailColors: nil
        )
    }

    // MARK: - Persistence: default vs. explicit "Any"

    func testFreshInstallGetsSixHourCap() throws {
        let store = makeStore(defaults: try makeDefaults())

        XCTAssertEqual(store.filter.maxDuration, sixHours)
        XCTAssertEqual(EventFilterStorage.defaultMaxDuration, sixHours)
        XCTAssertFalse(store.hasNonDefaultFilters)
    }

    /// The nearby time gate is the in-memory now-window at the (warp-able) effective date;
    /// a SQL expiry predicate would compare against real wall-clock now.
    func testIncludeExpiredStaysTrue() throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults: defaults)
        XCTAssertTrue(store.filter.includeExpired)

        store.filter.includeExpired = false
        let reloaded = makeStore(defaults: defaults)
        XCTAssertTrue(reloaded.filter.includeExpired, "Nearby always queries with expiry off")

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        XCTAssertTrue(store.observationFilter(region: region).includeExpired)
    }

    func testExplicitAnyIsDistinctFromUnset() throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults: defaults)
        store.filter.maxDuration = nil

        let reloaded = makeStore(defaults: defaults)
        XCTAssertNil(reloaded.filter.maxDuration, "Explicit Any must not decay back to 6h")
        XCTAssertTrue(reloaded.hasNonDefaultFilters)
    }

    func testExplicitLimitRoundTrips() throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults: defaults)
        store.filter.maxDuration = 2 * 3600

        let reloaded = makeStore(defaults: defaults)
        XCTAssertEqual(reloaded.filter.maxDuration, 2 * 3600)
        XCTAssertTrue(reloaded.hasNonDefaultFilters)
    }

    func testEventTypeSelectionRoundTrips() throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults: defaults)
        store.filter.eventTypeCodes = ["prty", "food"]

        let reloaded = makeStore(defaults: defaults)
        XCTAssertEqual(reloaded.filter.eventTypeCodes, ["prty", "food"])
        XCTAssertEqual(reloaded.filter.maxDuration, sixHours, "Types and duration persist independently")
        XCTAssertTrue(reloaded.hasNonDefaultFilters)
    }

    /// Nearby uses its own key so the Events tab's choices stay separate.
    func testNearbyKeyIsIndependentOfEventListKey() throws {
        let defaults = try makeDefaults()
        let nearby = makeStore(defaults: defaults, key: "nearbyEventFilter")
        nearby.filter.maxDuration = nil

        XCTAssertEqual(
            EventFilterStorage.loadMaxDuration(filterKey: "eventListFilter", defaults: defaults),
            sixHours,
            "The Events tab must still see its own unset default"
        )
    }

    func testObservationFilterStripsPerQueryState() throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults: defaults)
        store.filter.maxDuration = 3 * 3600
        store.filter.onlyFavorites = true
        store.filter.searchText = "yoga"
        store.filter.startDate = Date()

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            latitudinalMeters: 500,
            longitudinalMeters: 500
        )
        let observed = store.observationFilter(region: region)

        XCTAssertEqual(observed.maxDuration, 3 * 3600)
        XCTAssertTrue(observed.onlyFavorites)
        XCTAssertNil(observed.searchText)
        XCTAssertNil(observed.startDate)
        XCTAssertNil(observed.activeWindow)
        XCTAssertFalse(observed.happeningNow)
        XCTAssertNotNil(observed.region)
    }

    // MARK: - The cap reaches the queries

    func testNearbyScreenQueryCarriesDurationCap() async throws {
        let provider = try makeProvider()
        let store = makeStore(defaults: try makeDefaults())
        // Retained: the observation task bails via `guard let self` once the VM deallocates.
        let vm = try makeNearbyViewModel(eventProvider: provider, store: store)

        let observed = await eventually { !provider.filters.isEmpty }
        XCTAssertTrue(observed)

        let filter = try XCTUnwrap(provider.filters.last)
        XCTAssertEqual(filter.maxDuration, sixHours)
        XCTAssertNotNil(filter.region)
        XCTAssertNotNil(vm.searchRegion)
    }

    func testNearbyCardQueryCarriesDurationCap() async throws {
        let provider = try makeProvider()
        let store = makeStore(defaults: try makeDefaults())
        let vm = try makeCardViewModel(eventProvider: provider, store: store)

        let observed = await eventually { !provider.filters.isEmpty }
        XCTAssertTrue(observed)

        let filter = try XCTUnwrap(provider.filters.last)
        XCTAssertEqual(filter.maxDuration, sixHours)
        XCTAssertNotNil(vm.searchRegion)
    }

    /// The cap is a SQL predicate, so changing it has to re-query rather than re-filter
    /// what's already in memory — on both surfaces, from the one shared store.
    func testChangingTheFilterRequeriesBothSurfaces() async throws {
        let store = makeStore(defaults: try makeDefaults())
        let screenProvider = try makeProvider()
        let cardProvider = try makeProvider()
        let screenVM = try makeNearbyViewModel(eventProvider: screenProvider, store: store)
        let cardVM = try makeCardViewModel(eventProvider: cardProvider, store: store)

        _ = await eventually { !screenProvider.filters.isEmpty && !cardProvider.filters.isEmpty }

        store.filter.maxDuration = 2 * 3600

        let requeried = await eventually {
            screenProvider.filters.last?.maxDuration == 2 * 3600
                && cardProvider.filters.last?.maxDuration == 2 * 3600
        }
        XCTAssertTrue(requeried, "Both Nearby surfaces re-query when the shared filter changes")
        XCTAssertNotNil(screenVM.searchRegion)
        XCTAssertNotNil(cardVM.searchRegion)
    }

    // MARK: - Window regression

    /// Nothing outside the ~30 minute lookahead may reach the screen's sections, no matter
    /// what the region query returns.
    func testSectionsExcludeEventsOutsideTheWindow() async throws {
        let provider = try makeProvider()
        let store = makeStore(defaults: try makeDefaults())
        let vm = try makeNearbyViewModel(eventProvider: provider, store: store)

        _ = await eventually { !provider.filters.isEmpty }

        let now = vm.effectiveDate
        provider.emit([
            eventRow("running", start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(1800)),
            eventRow("soon", start: now.addingTimeInterval(600), end: now.addingTimeInterval(3600)),
            eventRow("hoursOut", start: now.addingTimeInterval(4 * 3600), end: now.addingTimeInterval(5 * 3600)),
            eventRow("tomorrow", start: now.addingTimeInterval(26 * 3600), end: now.addingTimeInterval(28 * 3600)),
            eventRow("over", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-60))
        ])

        let delivered = await eventually { !vm.eventItems.isEmpty }
        XCTAssertTrue(delivered)

        let ids = vm.happeningEvents.map(\.object.uid)
        XCTAssertEqual(ids, ["soon_0", "running_0"], "Only the now-window survives, starting-soon first")

        let sectionIDs = vm.sections
            .first { $0.id == .events }?
            .items.map(\.id) ?? []
        XCTAssertFalse(sectionIDs.contains { $0.contains("hoursOut") })
        XCTAssertFalse(sectionIDs.contains { $0.contains("tomorrow") })
        XCTAssertFalse(sectionIDs.contains { $0.contains("over") })
    }

    /// The timing readout on each row is measured against the effective (warped) date, not
    /// wall-clock now — otherwise a warped list reads as events hours away.
    func testDisplayDateFollowsTimeShift() async throws {
        let provider = try makeProvider()
        let store = makeStore(defaults: try makeDefaults())
        let vm = try makeNearbyViewModel(eventProvider: provider, store: store)
        let original = vm.timeShiftConfig
        defer { vm.timeShiftConfig = original }

        let warped = Date.present.addingTimeInterval(48 * 3600)
        vm.timeShiftConfig = TimeShiftConfiguration(date: warped, location: nil, isActive: true)

        XCTAssertEqual(vm.effectiveDate, warped)
        XCTAssertEqual(vm.now, warped, "Row timing labels must use the warped date")
    }

    // MARK: - Ordering

    private func order(
        _ rows: [ListRow<EventObjectOccurrence>],
        now: Date
    ) -> [String] {
        NearbyEventOrdering.sorted(rows, now: now).map(\.object.uid)
    }

    func testStartingSoonSortsAboveAlreadyRunning() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            eventRow("longRunner", start: now.addingTimeInterval(-5 * 3600), end: now.addingTimeInterval(3600)),
            eventRow("justStarted", start: now.addingTimeInterval(-300), end: now.addingTimeInterval(3600)),
            eventRow("startsSoon", start: now.addingTimeInterval(900), end: now.addingTimeInterval(3600))
        ]

        XCTAssertEqual(
            order(rows, now: now),
            ["startsSoon_0", "justStarted_0", "longRunner_0"],
            "Future starts first, then most-recently-started"
        )
    }

    func testStartingSoonOrderedBySoonestFirst() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            eventRow("in25", start: now.addingTimeInterval(1500), end: now.addingTimeInterval(3600)),
            eventRow("in5", start: now.addingTimeInterval(300), end: now.addingTimeInterval(3600)),
            eventRow("in15", start: now.addingTimeInterval(900), end: now.addingTimeInterval(3600))
        ]

        XCTAssertEqual(order(rows, now: now), ["in5_0", "in15_0", "in25_0"])
    }

    func testAlreadyStartedOrderedByMostRecentFirst() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            eventRow("sixHoursAgo", start: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(3600)),
            eventRow("tenMinAgo", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(3600)),
            eventRow("twoHoursAgo", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(3600))
        ]

        XCTAssertEqual(order(rows, now: now), ["tenMinAgo_0", "twoHoursAgo_0", "sixHoursAgo_0"])
    }

    /// Boundary: an occurrence starting exactly at `now` has begun, so it belongs to the
    /// started phase — and, being the most recent start possible, leads it.
    func testEventStartingExactlyNowCountsAsStarted() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            eventRow("oneSecondOut", start: now.addingTimeInterval(1), end: now.addingTimeInterval(3600)),
            eventRow("exactlyNow", start: now, end: now.addingTimeInterval(3600)),
            eventRow("aMinuteAgo", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(3600))
        ]

        XCTAssertEqual(order(rows, now: now), ["oneSecondOut_0", "exactlyNow_0", "aMinuteAgo_0"])
    }

    /// Rebuilt on every location fix and timer tick, so equal start times must not shuffle.
    func testIdenticalStartTimesBreakTiesStably() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = now.addingTimeInterval(-600)
        let end = now.addingTimeInterval(3600)
        let forward = [
            eventRow("bravo", start: start, end: end),
            eventRow("alpha", start: start, end: end),
            eventRow("charlie", start: start, end: end)
        ]
        let reversed: [ListRow<EventObjectOccurrence>] = forward.reversed()

        XCTAssertEqual(order(forward, now: now), ["alpha_0", "bravo_0", "charlie_0"])
        XCTAssertEqual(order(reversed, now: now), order(forward, now: now))
    }

    // MARK: - Sheet defaults helper

    func testSheetDefaultsComparisonIgnoresExpiredWhenHidden() throws {
        var filter = EventFilter.nearbyDefaults
        XCTAssertTrue(filter.matchesSheetDefaults(.nearbyDefaults, includingExpired: false))

        filter.maxDuration = nil
        XCTAssertFalse(filter.matchesSheetDefaults(.nearbyDefaults, includingExpired: false))

        var typed = EventFilter.nearbyDefaults
        typed.eventTypeCodes = ["prty"]
        XCTAssertFalse(typed.matchesSheetDefaults(.nearbyDefaults, includingExpired: false))

        var expiredFlipped = EventFilter.nearbyDefaults
        expiredFlipped.includeExpired = false
        XCTAssertTrue(
            expiredFlipped.matchesSheetDefaults(.nearbyDefaults, includingExpired: false),
            "A hidden control can't make the badge read as filtered"
        )
    }
}
