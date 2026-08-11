//
//  DroppedPinSourceOverrideTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the transient "look from here" override behind the map's dropped person marker:
//  which location wins on each surface, that the region queries re-center on it, that the
//  GPS stream can't quietly drag the content back to the device while it is active, that
//  clearing it restores device sourcing, and that none of it is ever persisted.
//

import Combine
import CoreLocation
import Dispatch
import Foundation
import MapKit
import UIKit
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

// MARK: - Test Doubles

/// In-memory preferences that actually publish their changes.
///
/// `Just`-backed doubles are enough for code that only reads, but the card *observes* its
/// enabled preference — a hide has to come back through the publisher before the view model
/// believes it — so this one keeps a subject per key.
private final class ObservablePreferenceService: PreferenceService {
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

/// A location provider whose stream stays open, so a test can deliver GPS fixes *after* the
/// view model has started observing. `MockLocationProvider` finishes its stream immediately,
/// which is exactly the case these tests need to distinguish from "pinned".
private final class StreamingLocationProvider: @unchecked Sendable, LocationProvider {
    let locationStream: AsyncStream<CLLocation?>
    private(set) var currentLocation: CLLocation?
    private let continuation: AsyncStream<CLLocation?>.Continuation

    init(initial: CLLocation?) {
        var captured: AsyncStream<CLLocation?>.Continuation!
        locationStream = AsyncStream { captured = $0 }
        continuation = captured
        currentLocation = initial
    }

    /// Push a new device fix through the stream.
    func send(_ location: CLLocation) {
        currentLocation = location
        continuation.yield(location)
    }
}

/// Records the region each observation was started with, so a test can assert that setting
/// or clearing the override actually re-queried rather than just re-sorting.
private final class RecordingEventProvider: EventDataProvider {
    private(set) var filters: [EventFilter] = []
    private var continuations: [AsyncStream<[ListRow<EventObjectOccurrence>]>.Continuation] = []

    override func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        filters.append(filter)
        return AsyncStream { continuation in
            continuations.append(continuation)
        }
    }

    override func isDatabaseSeeded() async -> Bool { true }

    var lastRegionCenter: CLLocationCoordinate2D? { filters.last?.region?.center }
}

// MARK: - Tests

@MainActor
final class DroppedPinSourceOverrideTests: XCTestCase {

    /// Roughly the Man.
    private let deviceLocation = CLLocation(latitude: 40.7864, longitude: -119.2065)
    /// Far enough away that no radius or recenter threshold could confuse the two.
    private let droppedLocation = CLLocation(latitude: 40.7900, longitude: -119.2000)
    /// A third spot, for "the user moved the person".
    private let secondDropLocation = CLLocation(latitude: 40.7820, longitude: -119.2100)

    // MARK: - Helpers

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

    /// `XCTAssertTrue(await …)` doesn't compile — its argument is an autoclosure — so the
    /// wait and the assertion are wrapped together here.
    private func expectEventually(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let satisfied = await eventually(condition)
        XCTAssertTrue(satisfied, description, file: file, line: line)
    }

    /// The first database query has landed, so a later one can be told apart from it.
    private func awaitFirstQuery(_ provider: RecordingEventProvider) async {
        await expectEventually("The view model starts a region observation on creation") {
            !provider.filters.isEmpty
        }
    }

    private func makeEventProvider() throws -> RecordingEventProvider {
        RecordingEventProvider(playaDB: try PlayaDBImpl(dbPath: ":memory:"))
    }

    /// Card view model on its own island: an in-memory database and, unless a test supplies
    /// one, its own preference store — so nothing here can be swayed by (or leak into) the
    /// defaults the host app happens to be carrying.
    private func makeCardViewModel(
        eventProvider: RecordingEventProvider,
        locationProvider: LocationProvider,
        preferences: PreferenceService = ObservablePreferenceService()
    ) throws -> NearbyCardViewModel {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return NearbyCardViewModel(
            playaDB: playaDB,
            artProvider: ArtDataProvider(playaDB: playaDB),
            campProvider: CampDataProvider(playaDB: playaDB),
            eventProvider: eventProvider,
            locationProvider: locationProvider,
            preferences: preferences
        )
    }

    private func makeNearbyViewModel(
        eventProvider: RecordingEventProvider,
        locationProvider: LocationProvider,
        sourceLocationOverride: CLLocation? = nil
    ) throws -> NearbyViewModel {
        let playaDB = try PlayaDBImpl(dbPath: ":memory:")
        return NearbyViewModel(
            playaDB: playaDB,
            artProvider: ArtDataProvider(playaDB: playaDB),
            campProvider: CampDataProvider(playaDB: playaDB),
            eventProvider: eventProvider,
            locationProvider: locationProvider,
            sourceLocationOverride: sourceLocationOverride
        )
    }

    private func assertSameCoordinate(
        _ lhs: CLLocationCoordinate2D?,
        _ rhs: CLLocationCoordinate2D,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let lhs else {
            XCTFail("\(message) — no coordinate", file: file, line: line)
            return
        }
        XCTAssertEqual(lhs.latitude, rhs.latitude, accuracy: 0.000_001, message, file: file, line: line)
        XCTAssertEqual(lhs.longitude, rhs.longitude, accuracy: 0.000_001, message, file: file, line: line)
    }

    // MARK: - Card view model: precedence

    func testCardPrefersDroppedPinOverDeviceLocation() throws {
        let provider = try makeEventProvider()
        let vm = try makeCardViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )

        assertSameCoordinate(vm.currentLocation?.coordinate, deviceLocation.coordinate,
                             "Starts on the device")
        XCTAssertFalse(vm.isSourceOverridden)

        vm.setSourceLocationOverride(droppedLocation)

        assertSameCoordinate(vm.currentLocation?.coordinate, droppedLocation.coordinate,
                             "The dropped pin outranks the device fix")
        XCTAssertTrue(vm.isSourceOverridden)
    }

    func testCardSearchRegionRecentersOnTheDroppedPin() async throws {
        let provider = try makeEventProvider()
        let vm = try makeCardViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )

        await awaitFirstQuery(provider)
        assertSameCoordinate(provider.lastRegionCenter, deviceLocation.coordinate,
                             "First query is centered on the device")

        vm.setSourceLocationOverride(droppedLocation)

        // Not just re-sorted in memory: the 100 m circle really moved, so a *different*
        // set of rows comes back from the database.
        assertSameCoordinate(vm.searchRegion?.center, droppedLocation.coordinate,
                             "The card's search region follows the pin")
        let requeried = await eventually {
            provider.lastRegionCenter.map { $0.isSameCoordinate(as: self.droppedLocation.coordinate) } ?? false
        }
        XCTAssertTrue(requeried, "Setting the override has to restart the region observations")
    }

    func testCardGpsUpdatesDoNotClobberAnActiveOverride() async throws {
        let provider = try makeEventProvider()
        let locationProvider = StreamingLocationProvider(initial: deviceLocation)
        let vm = try makeCardViewModel(eventProvider: provider, locationProvider: locationProvider)

        await awaitFirstQuery(provider)
        vm.setSourceLocationOverride(droppedLocation)
        await expectEventually("The drop re-queried around the pin") {
            provider.lastRegionCenter.map { $0.isSameCoordinate(as: self.droppedLocation.coordinate) } ?? false
        }
        let queriesAfterDrop = provider.filters.count

        // A real, large GPS move — far more than the 25 m recenter threshold.
        locationProvider.send(CLLocation(latitude: 40.7700, longitude: -119.2300))
        try? await Task.sleep(nanoseconds: 200_000_000)

        assertSameCoordinate(vm.currentLocation?.coordinate, droppedLocation.coordinate,
                             "Walking around must not drag the card off the dropped pin")
        assertSameCoordinate(provider.lastRegionCenter, droppedLocation.coordinate,
                             "…and must not re-center the query either")
        XCTAssertEqual(provider.filters.count, queriesAfterDrop,
                       "A pinned card doesn't re-query on GPS movement at all")
    }

    func testCardClearingTheOverrideRestoresDeviceSourcing() async throws {
        let provider = try makeEventProvider()
        let locationProvider = StreamingLocationProvider(initial: deviceLocation)
        let vm = try makeCardViewModel(eventProvider: provider, locationProvider: locationProvider)

        await awaitFirstQuery(provider)
        vm.setSourceLocationOverride(droppedLocation)

        // The device kept moving while the person was down; clearing must pick up the
        // *current* fix, not the one from when the pin was dropped.
        let walkedTo = CLLocation(latitude: 40.7700, longitude: -119.2300)
        locationProvider.send(walkedTo)
        try? await Task.sleep(nanoseconds: 200_000_000)

        vm.clearSourceLocationOverride()

        XCTAssertFalse(vm.isSourceOverridden)
        assertSameCoordinate(vm.currentLocation?.coordinate, walkedTo.coordinate,
                             "Back on the live device fix")
        let recentered = await eventually {
            provider.lastRegionCenter.map { $0.isSameCoordinate(as: walkedTo.coordinate) } ?? false
        }
        XCTAssertTrue(recentered, "Clearing re-queries around the device")
    }

    // MARK: - Visibility rule

    /// The whole truth table for "is the card on screen", which is the fix for the report
    /// that dropping the person on a hidden card put a marker on the map with nothing to
    /// read.
    func testVisibilityRule() {
        XCTAssertTrue(NearbyCardVisibility.isVisible(cardEnabled: true, overrideActive: false),
                      "The ordinary case: the card is on and sourcing from the device")
        XCTAssertTrue(NearbyCardVisibility.isVisible(cardEnabled: true, overrideActive: true),
                      "A drop doesn't hide a card that was already showing")
        XCTAssertTrue(NearbyCardVisibility.isVisible(cardEnabled: false, overrideActive: true),
                      "A drop shows the card even when the preference has it hidden")
        XCTAssertFalse(NearbyCardVisibility.isVisible(cardEnabled: false, overrideActive: false),
                       "Hidden and nothing dropped: stays hidden")
    }

    func testHideActionDependsOnlyOnWhetherAPinIsDown() {
        XCTAssertEqual(NearbyCardVisibility.hideAction(overrideActive: true), .clearDroppedPin)
        XCTAssertEqual(NearbyCardVisibility.hideAction(overrideActive: false), .disableCard)

        XCTAssertFalse(NearbyCardHideAction.clearDroppedPin.disablesCard,
                       "Retiring a pin must never write the preference")
        XCTAssertTrue(NearbyCardHideAction.disableCard.disablesCard)
    }

    // MARK: - Card view model: visibility + hide semantics

    /// The reported bug: with the card hidden, dropping the person showed only the marker.
    func testDroppingShowsTheCardEvenWhenThePreferenceHidesIt() async throws {
        let preferences = ObservablePreferenceService()
        preferences.setValue(false, for: Preferences.NearbyCard.enabled)
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        await expectEventually("The stored preference reaches the view model") { !vm.isCardVisible }

        vm.setSourceLocationOverride(droppedLocation)
        XCTAssertTrue(vm.isCardVisible, "The drop shows the card transiently")

        // …and the transient show is exactly that: nothing was written back.
        XCTAssertFalse(preferences.getValue(Preferences.NearbyCard.enabled),
                       "Showing the card for a drop must not turn the card on")

        vm.clearSourceLocationOverride()
        XCTAssertFalse(vm.isCardVisible, "Removing the person returns the card to the preference")
    }

    func testCardStaysVisibleAcrossADropWhenThePreferenceHasItOn() async throws {
        let preferences = ObservablePreferenceService()
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        XCTAssertTrue(vm.isCardVisible, "Default preference is on")

        vm.setSourceLocationOverride(droppedLocation)
        XCTAssertTrue(vm.isCardVisible)

        vm.clearSourceLocationOverride()
        XCTAssertTrue(vm.isCardVisible, "Back to the device, still showing")
    }

    /// The second reported bug: hiding while the person was down persisted the card off.
    func testHidingWhileDroppedRetiresThePinAndLeavesThePreferenceAlone() async throws {
        let preferences = ObservablePreferenceService()
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        vm.setSourceLocationOverride(droppedLocation)

        XCTAssertEqual(vm.hide(), .clearDroppedPin)

        XCTAssertFalse(vm.isSourceOverridden, "The person comes off the map")
        XCTAssertTrue(preferences.getValue(Preferences.NearbyCard.enabled),
                      "\"Nearby yourself\" is untouched by the \"check out that spot\" flow")
        XCTAssertTrue(vm.isCardVisible, "…so the card stays, now sourcing from the device")
    }

    /// Same gesture from the transient-show state: the card was only there for the pin, so it
    /// goes away again — and the already-off preference is still off, not written twice.
    func testHidingATransientlyShownCardJustTakesThePinAway() async throws {
        let preferences = ObservablePreferenceService()
        preferences.setValue(false, for: Preferences.NearbyCard.enabled)
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        await expectEventually("The stored preference reaches the view model") { !vm.isCardVisible }
        vm.setSourceLocationOverride(droppedLocation)
        XCTAssertTrue(vm.isCardVisible)

        XCTAssertEqual(vm.hide(), .clearDroppedPin)

        XCTAssertFalse(vm.isSourceOverridden)
        XCTAssertFalse(vm.isCardVisible, "The card disappears again")
        XCTAssertFalse(preferences.getValue(Preferences.NearbyCard.enabled), "Still off, as it was")
    }

    /// The one path that is still allowed to change the setting.
    func testHidingWithNoPinDownIsTheOneThatPersists() async throws {
        let preferences = ObservablePreferenceService()
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        XCTAssertTrue(vm.isCardVisible)

        XCTAssertEqual(vm.hide(), .disableCard)

        XCTAssertFalse(preferences.getValue(Preferences.NearbyCard.enabled),
                       "Hiding the card in its normal state is what turns it off")
        await expectEventually("…and the view model follows the preference") { !vm.isCardVisible }
    }

    /// Turning the card back on from the map filter screen still works, drop or no drop.
    func testReenablingThePreferenceBringsTheCardBack() async throws {
        let preferences = ObservablePreferenceService()
        preferences.setValue(false, for: Preferences.NearbyCard.enabled)
        let vm = try makeCardViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            preferences: preferences
        )
        await expectEventually("Starts hidden") { !vm.isCardVisible }

        preferences.setValue(true, for: Preferences.NearbyCard.enabled)

        await expectEventually("The map filter's switch brings the card back") { vm.isCardVisible }
    }

    // MARK: - Card view model: header text

    func testCardHeaderTextOnlyExistsWhileOverridden() throws {
        let provider = try makeEventProvider()
        let vm = try makeCardViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )

        XCTAssertNil(vm.headerText, "No header while the card is sourcing from the device")

        vm.setSourceLocationOverride(droppedLocation)
        XCTAssertEqual(vm.headerText, "Nearby dropped pin", "Fallback until the geocoder answers")

        vm.setSourceLocationAddress("G & 4:47", for: droppedLocation.coordinate)
        XCTAssertEqual(vm.headerText, "Nearby G & 4:47")

        vm.clearSourceLocationOverride()
        XCTAssertNil(vm.headerText)
    }

    func testCardIgnoresGeocodeResultsForASpotThePersonHasLeft() throws {
        let provider = try makeEventProvider()
        let vm = try makeCardViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )

        vm.setSourceLocationOverride(droppedLocation)
        // The user drops the person again before the first lookup comes back.
        vm.setSourceLocationOverride(secondDropLocation)
        vm.setSourceLocationAddress("G & 4:47", for: droppedLocation.coordinate)

        XCTAssertNil(vm.sourceLocationAddress, "A stale lookup must not label the new spot")
        XCTAssertEqual(vm.headerText, "Nearby dropped pin")

        vm.setSourceLocationAddress("D & 7:30", for: secondDropLocation.coordinate)
        XCTAssertEqual(vm.headerText, "Nearby D & 7:30")
    }

    func testCardMovingThePersonRecentersAgain() async throws {
        let provider = try makeEventProvider()
        let vm = try makeCardViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )
        await awaitFirstQuery(provider)

        vm.setSourceLocationOverride(droppedLocation)
        vm.setSourceLocationOverride(secondDropLocation)

        assertSameCoordinate(vm.searchRegion?.center, secondDropLocation.coordinate,
                             "The second drop wins")
        let requeried = await eventually {
            provider.lastRegionCenter.map { $0.isSameCoordinate(as: self.secondDropLocation.coordinate) } ?? false
        }
        XCTAssertTrue(requeried)
    }

    // MARK: - Nearby screen: precedence

    func testNearbyScreenPrecedenceIsPinThenWarpThenDevice() throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )

        assertSameCoordinate(vm.currentLocation?.coordinate, deviceLocation.coordinate,
                             "Device by default")
        XCTAssertFalse(vm.isSourcePinned)

        // Warp to a place: second in precedence, and the only source until a pin arrives.
        let warpLocation = CLLocation(latitude: 40.7950, longitude: -119.1950)
        vm.timeShiftConfig = TimeShiftConfiguration(
            date: Date.present.addingTimeInterval(3600),
            location: warpLocation,
            isActive: true
        )
        assertSameCoordinate(vm.currentLocation?.coordinate, warpLocation.coordinate,
                             "Warp location outranks the device")
        XCTAssertTrue(vm.isSourcePinned)

        // Dropping the person is the newer explicit choice, so it takes over the *where*
        // while leaving the warped *when* alone.
        vm.setSourceLocationOverride(droppedLocation)
        assertSameCoordinate(vm.currentLocation?.coordinate, droppedLocation.coordinate,
                             "The dropped pin outranks the warp location")
        XCTAssertEqual(vm.effectiveDate, vm.timeShiftConfig?.date,
                       "The person changes where, never when")

        // Clearing falls back to the warp location, not straight to the device.
        vm.clearSourceLocationOverride()
        assertSameCoordinate(vm.currentLocation?.coordinate, warpLocation.coordinate,
                             "Falls back to the still-active warp location")
    }

    func testWarpingToAPlaceRetiresAnEarlierDroppedPin() throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            sourceLocationOverride: droppedLocation
        )
        XCTAssertNotNil(vm.sourceLocationOverride)

        let warpLocation = CLLocation(latitude: 40.7950, longitude: -119.1950)
        vm.timeShiftConfig = TimeShiftConfiguration(
            date: Date.present,
            location: warpLocation,
            isActive: true
        )

        XCTAssertNil(vm.sourceLocationOverride, "Most recent explicit action wins")
        assertSameCoordinate(vm.currentLocation?.coordinate, warpLocation.coordinate, "…so the warp wins")
    }

    func testWarpingInTimeOnlyLeavesTheDroppedPinStanding() throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            sourceLocationOverride: droppedLocation
        )

        let warped = Date.present.addingTimeInterval(24 * 3600)
        vm.timeShiftConfig = TimeShiftConfiguration(date: warped, location: nil, isActive: true)

        assertSameCoordinate(vm.currentLocation?.coordinate, droppedLocation.coordinate,
                             "A time-only warp says nothing about where")
        XCTAssertEqual(vm.effectiveDate, warped)
    }

    // MARK: - Nearby screen: region + GPS

    func testNearbyScreenQueriesAroundTheOverrideItWasHanded() async throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            sourceLocationOverride: droppedLocation
        )

        await awaitFirstQuery(provider)
        assertSameCoordinate(vm.searchRegion?.center, droppedLocation.coordinate,
                             "\"See all\" opens already measuring from the pin")
        assertSameCoordinate(provider.lastRegionCenter, droppedLocation.coordinate,
                             "…including the very first database query")
    }

    func testNearbyScreenGpsUpdatesDoNotClobberAnActiveOverride() async throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let locationProvider = StreamingLocationProvider(initial: deviceLocation)
        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: locationProvider,
            sourceLocationOverride: droppedLocation
        )
        await awaitFirstQuery(provider)
        let queriesAfterOpen = provider.filters.count

        locationProvider.send(CLLocation(latitude: 40.7700, longitude: -119.2300))
        try? await Task.sleep(nanoseconds: 200_000_000)

        assertSameCoordinate(vm.currentLocation?.coordinate, droppedLocation.coordinate,
                             "The list stays measured from the pin")
        XCTAssertEqual(provider.filters.count, queriesAfterOpen,
                       "…and doesn't re-query around the device")
    }

    func testNearbyScreenClearingRestoresDeviceSourcing() async throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation),
            sourceLocationOverride: droppedLocation
        )
        await awaitFirstQuery(provider)

        vm.clearSourceLocationOverride()

        XCTAssertFalse(vm.isSourcePinned)
        assertSameCoordinate(vm.currentLocation?.coordinate, deviceLocation.coordinate, "Back on the device")
        let recentered = await eventually {
            provider.lastRegionCenter.map { $0.isSameCoordinate(as: self.deviceLocation.coordinate) } ?? false
        }
        XCTAssertTrue(recentered)
    }

    // MARK: - Transience

    /// The override is session state, not a setting. Nothing about dropping, moving or
    /// clearing the person may reach `UserSettings`.
    func testDroppedPinIsNeverPersisted() throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )
        vm.setSourceLocationOverride(droppedLocation)
        vm.setSourceLocationAddress("G & 4:47", for: droppedLocation.coordinate)

        XCTAssertNil(UserSettings.nearbyTimeShiftConfig,
                     "A dropped pin must not be smuggled into the persisted warp config")

        // A freshly built screen — the state a relaunch would see — has no pin.
        let reopened = try makeNearbyViewModel(
            eventProvider: try makeEventProvider(),
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )
        XCTAssertNil(reopened.sourceLocationOverride)
        XCTAssertNil(reopened.sourceLocationLabel)
    }

    func testNearbyScreenBannerLabel() throws {
        let provider = try makeEventProvider()
        let original = UserSettings.nearbyTimeShiftConfig
        defer { UserSettings.nearbyTimeShiftConfig = original }
        UserSettings.nearbyTimeShiftConfig = nil

        let vm = try makeNearbyViewModel(
            eventProvider: provider,
            locationProvider: MockLocationProvider(mockLocation: deviceLocation)
        )
        XCTAssertNil(vm.sourceLocationLabel)

        vm.setSourceLocationOverride(droppedLocation)
        XCTAssertEqual(vm.sourceLocationLabel, DroppedPersonAnnotation.fallbackTitle)

        vm.setSourceLocationAddress("G & 4:47", for: droppedLocation.coordinate)
        XCTAssertEqual(vm.sourceLocationLabel, "G & 4:47")
    }

    // MARK: - Card height arithmetic

    func testCardGrowsByExactlyTheHeaderWhenTheHeaderIsPresent() {
        let pageHeight: CGFloat = 72
        let headerHeight: CGFloat = 24

        let withoutHeader = NearbyCardView.cardHeight(pageHeight: pageHeight, headerHeight: nil)
        let withHeader = NearbyCardView.cardHeight(pageHeight: pageHeight, headerHeight: headerHeight)

        XCTAssertEqual(withoutHeader, pageHeight + NearbyCardView.footerHeight,
                       "Unchanged from before the feature when no pin is dropped")
        XCTAssertEqual(withHeader, withoutHeader + headerHeight,
                       "The header costs exactly its own height, no more")
    }

    func testDefaultDynamicTypeCardHeights() {
        // 10 (content inset) + 60 (thumbnail) + 2 (row/footer gap) = 72
        let pageHeight: CGFloat = 72
        let headerHeight = NearbyCardView.baseHeaderLineHeight + NearbyCardView.headerTopInset

        XCTAssertEqual(NearbyCardView.cardHeight(pageHeight: pageHeight, headerHeight: nil), 100)
        XCTAssertEqual(NearbyCardView.cardHeight(pageHeight: pageHeight, headerHeight: headerHeight), 124)
    }

    // MARK: - Marker artwork

    /// The marker's glyph is an SF Symbol eye, deliberately *not* the Burning Man figure the
    /// `pin_center` imageset carries — that artwork is trademarked and this feature has no
    /// claim on it. A typo'd symbol name would leave the marker an empty blue dot.
    func testEyeGlyphResolvesFromSFSymbols() throws {
        XCTAssertEqual(DroppedPersonMarker.glyphSymbolName, "eye.fill",
                       "The marker glyph is an eye; the Man is trademarked and off-limits here")
        let glyph = try XCTUnwrap(DroppedPersonMarker.makeGlyph(),
                                  "SF Symbol \(DroppedPersonMarker.glyphSymbolName) did not resolve")
        XCTAssertEqual(glyph.renderingMode, .alwaysOriginal,
                       "The white glyph must survive the annotation view's tint")
    }

    /// `eye.fill` is much wider than it is tall, so the draw size is aspect-fitted rather
    /// than scaled by height — height-scaling would push the eye past the chip's face.
    func testGlyphIsAspectFittedInsideTheChipFace() throws {
        let wide = DroppedPersonMarker.fittedGlyphSize(for: CGSize(width: 60, height: 20))
        XCTAssertEqual(wide.width / wide.height, 3, accuracy: 0.001, "Aspect ratio is preserved")
        XCTAssertLessThanOrEqual(max(wide.width, wide.height), DroppedPersonMarker.diameter,
                                 "The glyph has to fit inside the chip")

        let glyph = try XCTUnwrap(DroppedPersonMarker.makeGlyph())
        let drawn = DroppedPersonMarker.fittedGlyphSize(for: glyph.size)
        XCTAssertLessThan(max(drawn.width, drawn.height), DroppedPersonMarker.diameter,
                          "The real symbol leaves a margin inside the chip's ring")
    }

    func testMarkerImageIsBuiltAtChipSizePlusShadowRoom() {
        let image = DroppedPersonMarker.makeImage()
        XCTAssertGreaterThan(image.size.width, DroppedPersonMarker.diameter,
                             "The chip's shadow needs room inside the image bounds")
        XCTAssertEqual(image.size.width, image.size.height, accuracy: 0.001, "The chip is round")
        XCTAssertEqual(image.renderingMode, .alwaysOriginal,
                       "A template image would be tinted flat by the map's tint color")
    }

    // MARK: - Coordinate identity helper

    func testCoordinateIdentityHelpers() {
        let a = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let b = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let c = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2066)

        XCTAssertTrue(a.isSameCoordinate(as: b))
        XCTAssertFalse(a.isSameCoordinate(as: c))

        XCTAssertTrue(isSameSourceLocation(nil, nil))
        XCTAssertFalse(isSameSourceLocation(nil, CLLocation(latitude: a.latitude, longitude: a.longitude)))
        XCTAssertTrue(isSameSourceLocation(
            CLLocation(latitude: a.latitude, longitude: a.longitude),
            CLLocation(latitude: b.latitude, longitude: b.longitude)
        ))
    }
}
