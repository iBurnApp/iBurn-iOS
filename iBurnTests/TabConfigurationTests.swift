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
}
