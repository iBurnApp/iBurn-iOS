//
//  MapTabReselectionTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers what tapping the Map tab does when the Map tab is already selected. The rule is
//  shared by both tab systems the app runs on — `viewControllers` below iOS 26 and `UITab`
//  on the search-tab layout — so testing it once covers both delegate callbacks.
//

import XCTest
@testable import iBurn

final class MapTabReselectionTests: XCTestCase {

    // MARK: - Not a re-tap

    func testSwitchingToTheMapFromAnotherTabDoesNothing() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: .map, isAlreadySelected: false, navigationStackDepth: 1),
            .ignore,
            "Arriving at the map is not a request to reset it"
        )
    }

    func testSwitchingToTheMapFromAnotherTabDoesNotPopItsStackEither() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: .map, isAlreadySelected: false, navigationStackDepth: 3),
            .ignore,
            "A tab you come back to keeps whatever you left pushed on it"
        )
    }

    func testReselectingAnotherTabDoesNothingHere() {
        for tab in TabIdentifier.allCases where tab != .map {
            XCTAssertEqual(
                MapTabReselection.outcome(selected: tab, isAlreadySelected: true, navigationStackDepth: 1),
                .ignore,
                "\(tab.rawValue) re-tap is UIKit's business, not the map's"
            )
        }
    }

    /// The search tab's identifier matches no `TabIdentifier`, so it arrives as nil.
    func testAnUnrecognizedTabDoesNothing() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: nil, isAlreadySelected: true, navigationStackDepth: 1),
            .ignore
        )
    }

    // MARK: - Re-tap

    func testReTapAtTheRootRecenters() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: .map, isAlreadySelected: true, navigationStackDepth: 1),
            .recenter,
            "With the map itself on screen, the only thing left to reset is the camera"
        )
    }

    func testReTapWithSomethingPushedPopsFirst() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: .map, isAlreadySelected: true, navigationStackDepth: 2),
            .popToRoot,
            "Standard re-tap behavior: get back to the tab's own screen before anything else"
        )
    }

    func testReTapWithADeepStackStillJustPops() {
        XCTAssertEqual(
            MapTabReselection.outcome(selected: .map, isAlreadySelected: true, navigationStackDepth: 5),
            .popToRoot,
            "One pop unwinds the whole stack; depth beyond 1 is the only thing that matters"
        )
    }

    /// The two-step sequence the user actually performs: the first re-tap unwinds a pushed
    /// detail screen, the second — now at the root — flies the camera home.
    func testPopThenRecenterIsTheSequence() {
        let pushed = MapTabReselection.outcome(selected: .map, isAlreadySelected: true, navigationStackDepth: 2)
        XCTAssertEqual(pushed, .popToRoot)

        let afterPop = MapTabReselection.outcome(selected: .map, isAlreadySelected: true, navigationStackDepth: 1)
        XCTAssertEqual(afterPop, .recenter)
    }

    // MARK: - Identifier round trip

    /// `shouldSelectTab` reports a tab by identifier string; the map has to be findable that
    /// way or the `UITab` layout silently loses the behavior.
    func testEveryTabIdentifierRoundTripsThroughItsTabIdentifier() {
        for tab in TabIdentifier.allCases {
            XCTAssertEqual(TabIdentifier.identifier(forTabIdentifier: tab.tabIdentifier), tab)
        }
    }

    func testAnUnknownTabIdentifierResolvesToNil() {
        XCTAssertNil(TabIdentifier.identifier(forTabIdentifier: "iBurn.tab.search"))
        XCTAssertNil(TabIdentifier.identifier(forTabIdentifier: ""))
    }
}
