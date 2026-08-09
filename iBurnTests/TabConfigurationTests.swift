//
//  TabConfigurationTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/8/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import UIKit
import Combine
@testable import iBurn

/// In-memory `PreferenceService` so tab customization tests never touch the user's defaults.
private final class InMemoryPreferenceService: PreferenceService {
    private var storage: [String: Any] = [:]

    func getValue<T>(_ preference: Preference<T>) -> T {
        storage[preference.key] as? T ?? preference.defaultValue
    }

    func setValue<T>(_ value: T, for preference: Preference<T>) {
        storage[preference.key] = value
    }

    func publisher<T>(for preference: Preference<T>) -> AnyPublisher<T, Never> {
        Just(getValue(preference)).eraseToAnyPublisher()
    }

    func reset<T>(_ preference: Preference<T>) {
        storage.removeValue(forKey: preference.key)
    }

    func hasValue<T>(_ preference: Preference<T>) -> Bool {
        storage[preference.key] != nil
    }
}

final class TabConfigurationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PreferenceServiceFactory.setService(InMemoryPreferenceService())
        // The app defaults to the search-tab layout on iOS 26, which hides Favorites by
        // default and shrinks bar capacity. These tests exercise layout-independent
        // behavior under the classic layout; search-tab tests opt in explicitly.
        MapSearchLayout.current = .navigationBar
    }

    override func tearDown() {
        PreferenceServiceFactory.resetToDefault()
        super.tearDown()
    }

    // MARK: - Sanitizing

    func testDefaultIsCanonicalOrderWithNothingHidden() {
        XCTAssertEqual(TabConfiguration.default.visible, TabIdentifier.allCases)
        XCTAssertTrue(TabConfiguration.default.hidden.isEmpty)
    }

    func testSanitizeDropsUnknownIdentifiers() {
        let configuration = TabConfiguration.sanitized(
            order: ["map", "spaceship", "more"],
            hidden: ["spaceship", "events"]
        )
        XCTAssertFalse(configuration.ordered.contains { $0.rawValue == "spaceship" })
        XCTAssertEqual(configuration.hidden, [.events])
    }

    func testSanitizeAppendsMissingIdentifiersInCanonicalOrder() {
        let configuration = TabConfiguration.sanitized(order: ["more", "events"], hidden: [])
        XCTAssertEqual(configuration.visible, [.more, .events, .map, .nearby, .favorites])
    }

    func testSanitizeCollapsesDuplicates() {
        let configuration = TabConfiguration.sanitized(
            order: ["nearby", "nearby", "map"],
            hidden: []
        )
        XCTAssertEqual(configuration.visible.count, TabIdentifier.allCases.count)
        XCTAssertEqual(configuration.visible.prefix(2).map(\.rawValue), ["nearby", "map"])
    }

    func testSanitizeKeepsMapAndMoreVisible() {
        let configuration = TabConfiguration.sanitized(
            order: TabIdentifier.allCases.map(\.rawValue),
            hidden: ["map", "more", "nearby"]
        )
        XCTAssertTrue(configuration.visible.contains(.map))
        XCTAssertTrue(configuration.visible.contains(.more))
        XCTAssertEqual(configuration.hidden, [.nearby])
    }

    func testSanitizePreservesStoredOrderWithinVisibleAndHidden() {
        let configuration = TabConfiguration.sanitized(
            order: ["more", "events", "map", "favorites", "nearby"],
            hidden: ["events", "nearby"]
        )
        XCTAssertEqual(configuration.visible, [.more, .map, .favorites])
        XCTAssertEqual(configuration.hidden, [.events, .nearby])
    }

    func testEveryHideableTabCanBeHiddenAtOnce() {
        let hideable = TabIdentifier.allCases.filter(\.isHideable)
        let configuration = TabConfiguration.sanitized(
            order: TabIdentifier.allCases.map(\.rawValue),
            hidden: hideable.map(\.rawValue)
        )
        XCTAssertEqual(configuration.visible, [.map, .more])
        XCTAssertEqual(Set(configuration.hidden), Set(hideable))
    }

    // MARK: - Persistence

    func testCurrentDefaultsToCanonicalOrderWhenNothingStored() {
        XCTAssertEqual(TabConfiguration.current, .default)
    }

    func testRoundTripsOrderAndHiddenTabs() {
        TabConfiguration.current = TabConfiguration(
            visible: [.favorites, .map, .more],
            hidden: [.nearby, .events]
        )

        let restored = TabConfiguration.current
        XCTAssertEqual(restored.visible, [.favorites, .map, .more])
        XCTAssertEqual(restored.hidden, [.nearby, .events])
        XCTAssertTrue(restored.isHidden(.nearby))
        XCTAssertFalse(restored.isHidden(.map))
    }

    func testWritingSanitizesBeforePersisting() {
        TabConfiguration.current = TabConfiguration(visible: [.nearby], hidden: [.more, .map])

        let restored = TabConfiguration.current
        XCTAssertTrue(restored.hidden.isEmpty)
        XCTAssertEqual(Set(restored.visible), Set(TabIdentifier.allCases))
        XCTAssertEqual(restored.visible.first, .nearby)
    }

    func testResetRestoresDefault() {
        TabConfiguration.current = TabConfiguration(visible: [.more, .map], hidden: [.nearby, .favorites, .events])
        TabConfiguration.resetToDefault()
        XCTAssertEqual(TabConfiguration.current, .default)
    }

    func testWritingPostsChangeNotification() {
        expectation(forNotification: .tabConfigurationDidChange, object: nil)
        TabConfiguration.current = TabConfiguration(visible: [.map, .more], hidden: [.nearby, .favorites, .events])
        waitForExpectations(timeout: 1)
    }

    // MARK: - Identifiers

    func testHideableTabs() {
        XCTAssertFalse(TabIdentifier.map.isHideable)
        XCTAssertFalse(TabIdentifier.more.isHideable)
        XCTAssertTrue(TabIdentifier.nearby.isHideable)
        XCTAssertTrue(TabIdentifier.favorites.isHideable)
        XCTAssertTrue(TabIdentifier.events.isHideable)
    }

    func testTabIdentifiersAreStableAndUnique() {
        let identifiers = TabIdentifier.allCases.map(\.tabIdentifier)
        XCTAssertEqual(identifiers.count, Set(identifiers).count)
        XCTAssertEqual(TabIdentifier.map.tabIdentifier, "iBurn.tab.map")
    }

    @MainActor
    func testResolvesIdentifierThroughNavigationController() throws {
        let more = MoreViewController()
        let nav = UINavigationController(rootViewController: more)
        XCTAssertEqual(TabIdentifier.identifier(forRoot: nav), .more)
        XCTAssertEqual(TabIdentifier.identifier(forRoot: more), .more)
    }

    @MainActor
    func testUnknownRootHasNoIdentifier() {
        let unknown = UIViewController()
        XCTAssertNil(TabIdentifier.identifier(forRoot: unknown))
        XCTAssertNil(TabIdentifier.identifier(forRoot: UINavigationController(rootViewController: unknown)))
    }

    @MainActor
    func testHiddenTabIsDisplacedToMore() {
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .events, .more],
            hidden: [.nearby, .favorites]
        )
        XCTAssertTrue(TabController.isDisplacedFromTabBar(.nearby))
        XCTAssertTrue(TabController.isDisplacedFromTabBar(.favorites))
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.events))
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.map))
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.more))
    }

    // MARK: - Search-layout defaults
    //
    // The `.searchTab` layout spends a bar slot on search, so Favorites comes off the bar
    // by default — it keeps the floating button instead. That default is folded into the
    // effective configuration rather than applied by `TabController` on the way out —
    // otherwise the customization screen and the More list describe a bar that isn't the
    // one on screen, and dragging Favorites back does nothing. A tab the user has decided
    // about explicitly stops following the default.

    private func useSearchTabLayout() throws {
        MapSearchLayout.current = .searchTab
        try XCTSkipUnless(MapSearchLayout.current == .searchTab, "search tab layout needs iOS 26")
    }

    func testSearchTabLayoutHidesFavoritesByDefault() throws {
        try useSearchTabLayout()
        let configuration = TabConfiguration.current
        XCTAssertEqual(configuration.visible, [.map, .nearby, .events, .more])
        XCTAssertEqual(configuration.hidden, [.favorites])
        XCTAssertEqual(configuration, TabConfiguration.layoutDefault)
    }

    @MainActor
    func testSearchTabDefaultPutsFavoritesInMore() throws {
        try useSearchTabLayout()
        XCTAssertTrue(TabController.isDisplacedFromTabBar(.favorites))
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.events))
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.nearby))
    }

    @MainActor
    func testUserCanPutFavoritesBackAfterFreeingABarSlot() throws {
        try useSearchTabLayout()
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )

        let configuration = TabConfiguration.current
        XCTAssertEqual(configuration.visible, [.map, .nearby, .favorites, .more])
        XCTAssertEqual(configuration.hidden, [.events])
        XCTAssertFalse(TabController.isDisplacedFromTabBar(.favorites))
        XCTAssertTrue(TabController.isDisplacedFromTabBar(.events))
    }

    func testUntouchedFavoritesFollowsWhicheverLayoutIsActive() throws {
        try useSearchTabLayout()
        XCTAssertTrue(TabConfiguration.current.isHidden(.favorites))

        MapSearchLayout.current = .navigationBar
        XCTAssertFalse(TabConfiguration.current.isHidden(.favorites))

        try useSearchTabLayout()
        XCTAssertTrue(TabConfiguration.current.isHidden(.favorites))
    }

    func testHidingAnotherTabLeavesTheFavoritesDefaultAlone() throws {
        try useSearchTabLayout()
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .more],
            hidden: [.favorites, .events]
        )

        MapSearchLayout.current = .navigationBar
        let configuration = TabConfiguration.current
        XCTAssertTrue(configuration.isHidden(.events))
        XCTAssertFalse(configuration.isHidden(.favorites), "Favorites was never chosen by hand, so it comes back with the layout")
    }

    func testExplicitFavoritesChoiceSurvivesLayoutSwitches() throws {
        try useSearchTabLayout()
        // Capacity is four here, so choosing Favorites means giving up another slot first.
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )

        MapSearchLayout.current = .navigationBar
        XCTAssertFalse(TabConfiguration.current.isHidden(.favorites))

        try useSearchTabLayout()
        XCTAssertFalse(TabConfiguration.current.isHidden(.favorites), "The user asked for Favorites on the bar; the layout doesn't get to take it back")
    }

    func testExplicitlyHiddenEventsStaysHiddenOnLayoutsThatWouldShowIt() throws {
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )
        XCTAssertTrue(TabConfiguration.current.isHidden(.events))

        try useSearchTabLayout()
        XCTAssertTrue(TabConfiguration.current.isHidden(.events))

        MapSearchLayout.current = .navigationBar
        XCTAssertTrue(TabConfiguration.current.isHidden(.events))
    }

    func testResetRestoresTheActiveLayoutsDefault() throws {
        try useSearchTabLayout()
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )
        XCTAssertNotEqual(TabConfiguration.current, TabConfiguration.layoutDefault)

        TabConfiguration.resetToDefault()
        XCTAssertEqual(TabConfiguration.current, TabConfiguration.layoutDefault)
        XCTAssertTrue(TabConfiguration.current.isHidden(.favorites))
        XCTAssertFalse(TabConfiguration.current.isHidden(.events))
    }

    func testLayoutDefaultIsPlainDefaultWithoutTheSearchTab() {
        MapSearchLayout.current = .navigationBar
        XCTAssertEqual(TabConfiguration.layoutDefault, .default)
        XCTAssertTrue(TabConfiguration.layoutHiddenByDefault.isEmpty)
    }

    /// Hiding Favorites under `.searchTab` leaves the bar looking exactly like the default,
    /// but the choice behind it is not the default — `Reset` has to stay live.
    func testExplicitChoiceCountsAsTouchedEvenWhenTheBarLooksDefault() throws {
        XCTAssertTrue(TabConfiguration.isUntouched)

        try useSearchTabLayout()
        XCTAssertTrue(TabConfiguration.isUntouched)

        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .events, .more],
            hidden: [.favorites]
        )

        XCTAssertEqual(TabConfiguration.current, TabConfiguration.layoutDefault)
        XCTAssertFalse(TabConfiguration.isUntouched)

        TabConfiguration.resetToDefault()
        XCTAssertTrue(TabConfiguration.isUntouched)
    }

    // MARK: - Floating Favorites button
    //
    // The button exists to replace the Favorites tab the search layout takes away, so it
    // has to appear exactly when that trade is in effect — never alongside a live
    // Favorites tab, and never on a layout that never took the tab.

    func testFloatingFavoritesButtonNeedsBothConditions() {
        XCTAssertTrue(FavoritesFABVisibility.isVisible(searchTabActive: true, favoritesDisplaced: true))
        XCTAssertFalse(FavoritesFABVisibility.isVisible(searchTabActive: true, favoritesDisplaced: false))
        XCTAssertFalse(FavoritesFABVisibility.isVisible(searchTabActive: false, favoritesDisplaced: true))
        XCTAssertFalse(FavoritesFABVisibility.isVisible(searchTabActive: false, favoritesDisplaced: false))
    }

    @MainActor
    func testFloatingFavoritesButtonTracksTheLiveConfiguration() throws {
        XCTAssertFalse(FavoritesFABVisibility.isVisible, "classic layout keeps the Favorites tab")

        try useSearchTabLayout()
        XCTAssertTrue(FavoritesFABVisibility.isVisible)

        // Dragging Favorites back onto the bar gives up another slot — and the button,
        // which would otherwise be a second door to the same screen.
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more],
            hidden: [.events]
        )
        XCTAssertFalse(FavoritesFABVisibility.isVisible)

        TabConfiguration.resetToDefault()
        XCTAssertTrue(FavoritesFABVisibility.isVisible)
    }

    func testMovingToHiddenIgnoresTabsThatCannotBeHidden() {
        let configuration = TabConfiguration.default.movingToHidden([.map, .more])
        XCTAssertEqual(configuration, .default)
    }

    // MARK: - Capacity
    //
    // iPhone shows at most five tab bar items; a sixth makes UIKit add its own native
    // More overflow tab next to the app's More. The bar must never get there, so app
    // tabs have five slots — four while the `.searchTab` layout spends one on search.

    func testCapacityIsFiveWithoutTheSearchTab() {
        MapSearchLayout.current = .navigationBar
        XCTAssertEqual(TabConfiguration.visibleCapacity, 5)
        XCTAssertFalse(TabConfiguration.searchTabOccupiesBarSlot)
    }

    func testCapacityIsFourWhileTheSearchTabHoldsASlot() throws {
        try useSearchTabLayout()
        XCTAssertEqual(TabConfiguration.visibleCapacity, 4)
        XCTAssertTrue(TabConfiguration.searchTabOccupiesBarSlot)
    }

    func testLimitingPushesTabsOffTheEndOfTheBar() {
        let limited = TabConfiguration.default.limited(toCapacity: 4)
        XCTAssertEqual(limited.visible, [.map, .nearby, .favorites, .more])
        XCTAssertEqual(limited.hidden, [.events])
    }

    func testLimitingSkipsTabsThatCannotBeHidden() {
        let configuration = TabConfiguration.sanitized(
            order: ["nearby", "favorites", "events", "map", "more"],
            hidden: []
        )
        let limited = configuration.limited(toCapacity: 3)
        XCTAssertEqual(limited.visible, [.nearby, .map, .more])
        XCTAssertEqual(limited.hidden, [.favorites, .events])
    }

    func testLimitingIsANoOpAtOrUnderCapacity() {
        XCTAssertEqual(TabConfiguration.default.limited(toCapacity: 5), .default)
        XCTAssertEqual(TabConfiguration.default.limited(toCapacity: 6), .default)
    }

    func testEffectiveConfigurationNeverExceedsCapacityUnderTheSearchTab() throws {
        try useSearchTabLayout()
        TabConfiguration.current = TabConfiguration(visible: TabIdentifier.allCases, hidden: [])
        XCTAssertEqual(TabConfiguration.current.visible.count, TabConfiguration.visibleCapacity)
    }

    /// A bar that was legitimately full on a five-slot layout loses its last hideable
    /// tab when the search tab arrives — as layout pressure, not a recorded choice, so
    /// the tab comes straight back when capacity does.
    func testCapacityClampOnLayoutSwitchIsNotAUserChoice() throws {
        MapSearchLayout.current = .navigationBar
        // Hide and re-show Favorites so it carries an explicit "on the bar" override and
        // the search layout's Favorites default can't be what empties the slot.
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .events, .more],
            hidden: [.favorites]
        )
        TabConfiguration.current = TabConfiguration(
            visible: [.map, .nearby, .favorites, .more, .events],
            hidden: []
        )
        XCTAssertEqual(TabConfiguration.current.visible.count, 5)

        try useSearchTabLayout()
        let clamped = TabConfiguration.current
        XCTAssertEqual(clamped.visible, [.map, .nearby, .favorites, .more])
        XCTAssertEqual(clamped.hidden, [.events])

        MapSearchLayout.current = .navigationBar
        XCTAssertFalse(TabConfiguration.current.isHidden(.events))
    }

    // MARK: - Partition integrity
    //
    // The customization screen renders `visible` and `hidden` as two ForEach sections of
    // one List; an identifier in both (or missing from both) corrupts edit-mode chrome.
    // No sequence of writes may ever break the partition.

    func testEditSequenceKeepsVisibleAndHiddenAStrictPartition() throws {
        func assertPartitioned(file: StaticString = #filePath, line: UInt = #line) {
            let configuration = TabConfiguration.current
            XCTAssertTrue(
                Set(configuration.visible).isDisjoint(with: configuration.hidden),
                "identifier in both partitions", file: file, line: line
            )
            XCTAssertEqual(Set(configuration.ordered), Set(TabIdentifier.allCases), file: file, line: line)
            XCTAssertEqual(configuration.ordered.count, TabIdentifier.allCases.count, file: file, line: line)
            XCTAssertLessThanOrEqual(configuration.visible.count, TabConfiguration.visibleCapacity, file: file, line: line)
        }

        assertPartitioned()
        try useSearchTabLayout()
        assertPartitioned()

        // The reported crash sequence: free a slot, un-hide the layout-hidden tab, then
        // reorder.
        var configuration = TabConfiguration.current
        TabConfiguration.current = TabConfiguration(
            visible: configuration.visible.filter { $0 != .events },
            hidden: configuration.hidden + [.events]
        )
        assertPartitioned()

        configuration = TabConfiguration.current
        TabConfiguration.current = TabConfiguration(
            visible: configuration.visible + [.favorites],
            hidden: configuration.hidden.filter { $0 != .favorites }
        )
        assertPartitioned()
        XCTAssertFalse(TabConfiguration.current.isHidden(.favorites))

        configuration = TabConfiguration.current
        var moved = configuration.visible
        moved.move(fromOffsets: [moved.count - 1], toOffset: 0)
        TabConfiguration.current = TabConfiguration(visible: moved, hidden: configuration.hidden)
        assertPartitioned()

        MapSearchLayout.current = .navigationBar
        assertPartitioned()
        try useSearchTabLayout()
        assertPartitioned()
    }
}
