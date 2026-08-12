//
//  NearbyEmbargoGatingTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The Nearby screen and the map's nearby card both source art, camps and events from
//  *region* (spatial) queries. A region result places its objects by presence and rank
//  alone — a locked camp that shows up in a "within 100 m of you" list has had its
//  placement leaked whether or not its address is drawn — so both surfaces have to apply
//  the same two-tier embargo the map's annotation paths do. These cases pin that:
//  no art/camp observation is even started while its tier is closed, occurrences are
//  filtered per host tier, and an unlock restarts the observations rather than waiting
//  for a relaunch.
//

import Combine
import CoreLocation
import Dispatch
import Foundation
import MapKit
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

// MARK: - Test Doubles

/// Art provider that records every region query it is asked for and never answers, so a
/// test can tell "the observation was started" from "the embargo suppressed it".
private final class RecordingArtProvider: ArtDataProvider {
    private(set) var filters: [ArtFilter] = []

    override func observeObjects(filter: ArtFilter) -> AsyncStream<[ListRow<ArtObject>]> {
        filters.append(filter)
        return AsyncStream { _ in }
    }

    override func isDatabaseSeeded() async -> Bool { true }
}

private final class RecordingCampProvider: CampDataProvider {
    private(set) var filters: [CampFilter] = []

    override func observeObjects(filter: CampFilter) -> AsyncStream<[ListRow<CampObject>]> {
        filters.append(filter)
        return AsyncStream { _ in }
    }

    override func isDatabaseSeeded() async -> Bool { true }
}

/// Event provider whose streams stay open, so a test can push occurrences into a live
/// view model and watch what survives the tier filter.
private final class EmittingEventProvider: EventDataProvider {
    private(set) var filters: [EventFilter] = []
    private var continuations: [AsyncStream<[ListRow<EventObjectOccurrence>]>.Continuation] = []

    override func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        filters.append(filter)
        return AsyncStream { continuation in
            continuations.append(continuation)
        }
    }

    override func isDatabaseSeeded() async -> Bool { true }

    /// Deliver `rows` to every stream handed out so far — the view model's own (latest)
    /// task is the only one still listening.
    func emit(_ rows: [ListRow<EventObjectOccurrence>]) {
        for continuation in continuations {
            continuation.yield(rows)
        }
    }
}

/// In-memory preferences so the card's own visibility and type toggles are fixed at their
/// defaults (card on, all three types on) rather than inherited from the host app.
private final class InMemoryPreferenceService: PreferenceService {
    private var storage: [String: Any] = [:]
    private var subjects: [String: Any] = [:]

    func getValue<T>(_ preference: Preference<T>) -> T {
        storage[preference.key] as? T ?? preference.defaultValue
    }

    func setValue<T>(_ value: T, for preference: Preference<T>) {
        storage[preference.key] = value
        subject(for: preference).send(value)
    }

    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never> {
        subject(for: preference).eraseToAnyPublisher()
    }

    func reset<T>(_ preference: Preference<T>) {
        storage.removeValue(forKey: preference.key)
        subject(for: preference).send(preference.defaultValue)
    }

    func hasValue<T>(_ preference: Preference<T>) -> Bool {
        storage[preference.key] != nil
    }

    private func subject<T>(for preference: Preference<T>) -> CurrentValueSubject<T, Never> {
        if let existing = subjects[preference.key] as? CurrentValueSubject<T, Never> {
            return existing
        }
        let created = CurrentValueSubject<T, Never>(getValue(preference))
        subjects[preference.key] = created
        return created
    }
}

// MARK: - Tests

@MainActor
final class NearbyEmbargoGatingTests: XCTestCase {

    /// Roughly the Man — both view models query a region centred here.
    private let deviceLocation = CLLocation(latitude: 40.7864, longitude: -119.2065)

    private var originalUnlocked = false
    private var originalTimeShift: TimeShiftConfiguration?

    override func setUpWithError() throws {
        try super.setUpWithError()
        originalUnlocked = UserDefaults.enteredEmbargoPasscode
        UserDefaults.enteredEmbargoPasscode = false
        originalTimeShift = UserSettings.nearbyTimeShiftConfig
        UserSettings.nearbyTimeShiftConfig = nil
        UserDefaults.standard.set(true, forKey: "BRCMockDateEnabled")
        // Default: before either tier opens.
        try timeTravel(to: lockedDate)
    }

    override func tearDownWithError() throws {
        UserDefaults.enteredEmbargoPasscode = originalUnlocked
        UserSettings.nearbyTimeShiftConfig = originalTimeShift
        UserDefaults.standard.removeObject(forKey: "BRCMockDateEnabled")
        UserDefaults.standard.removeObject(forKey: "BRCMockDateValue")
        try super.tearDownWithError()
    }

    /// Everything locked.
    private let lockedDate = "2026-08-10T12:00:00Z"
    /// Inside the camp window: camps visible, art still hidden until gates open.
    private let campWindowDate = "2026-08-25T12:00:00Z"
    /// After gates open: everything visible.
    private let gatesOpenDate = "2026-08-31T12:00:00Z"

    private func timeTravel(to iso8601: String) throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: iso8601))
        UserDefaults.standard.set(date, forKey: "BRCMockDateValue")
    }

    // MARK: - Fixtures

    private func occurrenceRow(
        uid: String,
        hostedByCamp: String? = nil,
        locatedAtArt: String? = nil,
        at coordinate: CLLocationCoordinate2D? = nil,
        start: Date,
        end: Date
    ) -> ListRow<EventObjectOccurrence> {
        let event = EventObject(
            uid: uid,
            name: uid,
            year: 2026,
            eventTypeLabel: "Party",
            eventTypeCode: "prty",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt,
            gpsLatitude: coordinate?.latitude,
            gpsLongitude: coordinate?.longitude
        )
        let occurrence = EventOccurrence(eventId: uid, startTime: start, endTime: end)
        return ListRow(
            object: EventObjectOccurrence(event: event, occurrence: occurrence, host: nil),
            metadata: nil,
            thumbnailColors: nil
        )
    }

    /// A camp-hosted and an art-located occurrence, both happening right now at the
    /// device's own coordinate so nothing but the embargo can drop them.
    private func hereAndNowOccurrences() -> [ListRow<EventObjectOccurrence>] {
        let now = Date.present
        return [
            occurrenceRow(uid: "camp-event",
                          hostedByCamp: "camp-1",
                          at: deviceLocation.coordinate,
                          start: now.addingTimeInterval(-600),
                          end: now.addingTimeInterval(3600)),
            occurrenceRow(uid: "art-event",
                          locatedAtArt: "art-1",
                          at: deviceLocation.coordinate,
                          start: now.addingTimeInterval(-600),
                          end: now.addingTimeInterval(3600))
        ]
    }

    // MARK: - Async helpers

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

    private func expectEventually(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let satisfied = await eventually(condition)
        XCTAssertTrue(satisfied, description, file: file, line: line)
    }

    /// Give the observation tasks a chance to run, for the assertions that are about
    /// something *not* happening.
    private func settle() async {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    // MARK: - View model construction

    private struct Providers {
        let art: RecordingArtProvider
        let camp: RecordingCampProvider
        let event: EmittingEventProvider
        let playaDB: PlayaDB
    }

    private func makeProviders() throws -> Providers {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return Providers(
            art: RecordingArtProvider(playaDB: playaDB),
            camp: RecordingCampProvider(playaDB: playaDB),
            event: EmittingEventProvider(playaDB: playaDB),
            playaDB: playaDB
        )
    }

    private func makeNearbyViewModel(_ providers: Providers) -> NearbyViewModel {
        NearbyViewModel(
            playaDB: providers.playaDB,
            artProvider: providers.art,
            campProvider: providers.camp,
            eventProvider: providers.event,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            filterStore: makeFilterStore()
        )
    }

    private func makeCardViewModel(_ providers: Providers) -> NearbyCardViewModel {
        NearbyCardViewModel(
            playaDB: providers.playaDB,
            artProvider: providers.art,
            campProvider: providers.camp,
            eventProvider: providers.event,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: InMemoryPreferenceService(),
            filterStore: makeFilterStore()
        )
    }

    /// Its own storage key, so neither the user's saved nearby filter nor these tests can
    /// reach each other.
    private func makeFilterStore() -> NearbyEventFilterStore {
        NearbyEventFilterStore(storageKey: "nearbyEmbargoGatingTests")
    }

    // MARK: - The shared occurrence gate

    // `BRCEmbargo.visibleNearbyEvents` is the one definition of "which occurrences may a
    // proximity surface list", used by both view models.

    func testNoOccurrenceIsListedBeforeEitherTierOpens() throws {
        try timeTravel(to: lockedDate)
        XCTAssertEqual(BRCEmbargo.visibleNearbyEvents(hereAndNowOccurrences()).count, 0)
    }

    func testCampHostedOccurrenceIsListedInsideTheCampWindowButArtLocatedIsNot() throws {
        try timeTravel(to: campWindowDate)
        let visible = BRCEmbargo.visibleNearbyEvents(hereAndNowOccurrences())
        XCTAssertEqual(visible.map(\.object.event.uid), ["camp-event"],
                       "An event at an art installation would place the art a week early")
    }

    func testEveryOccurrenceIsListedOnceGatesOpen() throws {
        try timeTravel(to: gatesOpenDate)
        XCTAssertEqual(BRCEmbargo.visibleNearbyEvents(hereAndNowOccurrences()).map(\.object.event.uid),
                       ["camp-event", "art-event"])
    }

    func testPasscodeUnlocksEveryOccurrenceEarly() throws {
        try timeTravel(to: lockedDate)
        UserDefaults.enteredEmbargoPasscode = true
        XCTAssertEqual(BRCEmbargo.visibleNearbyEvents(hereAndNowOccurrences()).count, 2)
    }

    /// A hostless occurrence has no placement to leak beyond its own coordinates, which
    /// still come from the API — it rides the camp tier, same as `canShowLocation(for:)`.
    func testHostlessOccurrenceRidesTheCampTier() throws {
        let now = Date.present
        let row = occurrenceRow(uid: "hostless",
                                at: deviceLocation.coordinate,
                                start: now.addingTimeInterval(-600),
                                end: now.addingTimeInterval(3600))
        try timeTravel(to: lockedDate)
        XCTAssertEqual(BRCEmbargo.visibleNearbyEvents([row]).count, 0)
        try timeTravel(to: campWindowDate)
        XCTAssertEqual(BRCEmbargo.visibleNearbyEvents([row]).count, 1)
    }

    // MARK: - Nearby screen: art + camp observations

    func testNearbyScreenStartsNoArtOrCampQueryWhileBothTiersAreClosed() async throws {
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await settle()

        XCTAssertTrue(providers.art.filters.isEmpty,
                      "A region query for art is itself the leak — it must not be issued")
        XCTAssertTrue(providers.camp.filters.isEmpty)
        XCTAssertTrue(vm.artItems.isEmpty)
        XCTAssertTrue(vm.campItems.isEmpty)
        XCTAssertFalse(providers.event.filters.isEmpty,
                       "Events are still queried; the tier is applied per occurrence")
    }

    func testNearbyScreenQueriesCampsButNotArtInsideTheCampWindow() async throws {
        try timeTravel(to: campWindowDate)
        let providers = try makeProviders()
        // Held, not discarded: the observations run inside `Task { [weak self] … }`, so a
        // released view model never issues a query and every assertion below passes for
        // the wrong reason.
        let vm = makeNearbyViewModel(providers)
        await settle()

        XCTAssertFalse(providers.camp.filters.isEmpty, "Camps are open a week before gates")
        XCTAssertTrue(providers.art.filters.isEmpty, "Art waits for gates")
        XCTAssertTrue(vm.artItems.isEmpty)
    }

    func testNearbyScreenQueriesEverythingOnceUnlocked() async throws {
        try timeTravel(to: gatesOpenDate)
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await expectEventually("Art is queried once gates open") { !providers.art.filters.isEmpty }
        await expectEventually("…and so are camps") { !providers.camp.filters.isEmpty }
        XCTAssertNotNil(vm.searchRegion)
    }

    /// The embargo state is read imperatively when an observation starts, so unlocking has
    /// to restart them — otherwise the screen stays empty until the next relaunch.
    func testNearbyScreenRestartsItsObservationsWhenTheEmbargoClears() async throws {
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await settle()
        XCTAssertTrue(providers.art.filters.isEmpty)

        UserDefaults.enteredEmbargoPasscode = true
        NotificationCenter.default.post(name: .BRCEmbargoDidClear, object: nil)

        await expectEventually("Unlocking restarts the art observation") {
            !providers.art.filters.isEmpty
        }
        await expectEventually("…and the camp observation") { !providers.camp.filters.isEmpty }
        XCTAssertNotNil(vm.searchRegion)
    }

    // MARK: - Nearby screen: per-occurrence tier

    func testNearbyScreenDropsArtLocatedOccurrencesWhileArtIsLocked() async throws {
        try timeTravel(to: campWindowDate)
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await expectEventually("The event observation is running") { !providers.event.filters.isEmpty }

        providers.event.emit(hereAndNowOccurrences())

        await expectEventually("Only the camp-hosted occurrence survives the tier filter") {
            vm.eventItems.map(\.object.event.uid) == ["camp-event"]
        }
    }

    func testNearbyScreenListsNoOccurrencesWhileEverythingIsLocked() async throws {
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await expectEventually("The event observation is running") { !providers.event.filters.isEmpty }

        providers.event.emit(hereAndNowOccurrences())
        await settle()

        XCTAssertTrue(vm.eventItems.isEmpty)
        XCTAssertTrue(vm.isEmpty, "Nothing at all is offered before the camp tier opens")
    }

    func testNearbyScreenListsEveryOccurrenceOnceGatesOpen() async throws {
        try timeTravel(to: gatesOpenDate)
        let providers = try makeProviders()
        let vm = makeNearbyViewModel(providers)
        await expectEventually("The event observation is running") { !providers.event.filters.isEmpty }

        providers.event.emit(hereAndNowOccurrences())

        await expectEventually("Both occurrences are listed") {
            Set(vm.eventItems.map(\.object.event.uid)) == ["camp-event", "art-event"]
        }
    }

    // MARK: - Map nearby card

    func testCardStartsNoArtOrCampQueryWhileBothTiersAreClosed() async throws {
        let providers = try makeProviders()
        let vm = makeCardViewModel(providers)
        await settle()

        XCTAssertTrue(providers.art.filters.isEmpty)
        XCTAssertTrue(providers.camp.filters.isEmpty)
        XCTAssertTrue(vm.items.isEmpty)
    }

    func testCardQueriesCampsButNotArtInsideTheCampWindow() async throws {
        try timeTravel(to: campWindowDate)
        let providers = try makeProviders()
        let vm = makeCardViewModel(providers)
        await settle()

        XCTAssertFalse(providers.camp.filters.isEmpty)
        XCTAssertTrue(providers.art.filters.isEmpty)
        XCTAssertTrue(vm.isCardVisible)
    }

    func testCardDropsArtLocatedOccurrencesWhileArtIsLocked() async throws {
        try timeTravel(to: campWindowDate)
        let providers = try makeProviders()
        let vm = makeCardViewModel(providers)
        await expectEventually("The event observation is running") { !providers.event.filters.isEmpty }

        providers.event.emit(hereAndNowOccurrences())

        await expectEventually("The card pages only the camp-hosted occurrence") {
            vm.items.count == 1 && vm.items.first?.id.hasPrefix("event-camp-event") == true
        }
    }

    func testCardShowsNothingWhileEverythingIsLocked() async throws {
        let providers = try makeProviders()
        let vm = makeCardViewModel(providers)
        await expectEventually("The event observation is running") { !providers.event.filters.isEmpty }

        providers.event.emit(hereAndNowOccurrences())
        await settle()

        XCTAssertTrue(vm.items.isEmpty)
    }

    func testCardRestartsItsObservationsWhenTheEmbargoClears() async throws {
        let providers = try makeProviders()
        let vm = makeCardViewModel(providers)
        await settle()
        XCTAssertTrue(providers.art.filters.isEmpty)
        XCTAssertTrue(vm.isCardVisible)

        UserDefaults.enteredEmbargoPasscode = true
        NotificationCenter.default.post(name: .BRCEmbargoDidClear, object: nil)

        await expectEventually("Unlocking restarts the card's art observation") {
            !providers.art.filters.isEmpty
        }
        await expectEventually("…and its camp observation") { !providers.camp.filters.isEmpty }
    }
}
