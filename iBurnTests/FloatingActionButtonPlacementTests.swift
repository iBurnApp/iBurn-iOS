//
//  FloatingActionButtonPlacementTests.swift
//  iBurnTests
//
//  Copyright © 2026 iBurn. All rights reserved.
//

import XCTest
@testable import iBurn

/// The rule that keeps the floating action button from constraining itself to a tab bar that
/// isn't in its view hierarchy — the iPad launch crash (`no common ancestor`) in 2026.0.
final class FloatingActionButtonPlacementTests: XCTestCase {

    /// iPhone: bar is a bottom-docked subview, so the button stacks on it as it always has.
    func testDockedInHierarchyBarHangsTheButtonAboveIt() {
        XCTAssertEqual(
            FloatingActionButtonPlacement.placement(tabBarIsInHierarchy: true, tabBarIsDockedAtBottom: true),
            .aboveTabBar
        )
    }

    /// iPad on iOS 26: the floating top bar lives outside this view. Constraining to it throws.
    func testBarOutsideHierarchyFallsBackToSafeArea() {
        XCTAssertEqual(
            FloatingActionButtonPlacement.placement(tabBarIsInHierarchy: false, tabBarIsDockedAtBottom: false),
            .bottomSafeArea
        )
    }

    /// Being in the hierarchy is not enough: a bar at the top would put the button under the
    /// status bar rather than above the bar.
    func testInHierarchyButNotDockedFallsBackToSafeArea() {
        XCTAssertEqual(
            FloatingActionButtonPlacement.placement(tabBarIsInHierarchy: true, tabBarIsDockedAtBottom: false),
            .bottomSafeArea
        )
    }

    /// And neither is being at the bottom — the ancestor check is the one that prevents the
    /// exception, so it has to win on its own.
    func testDockedButOutsideHierarchyFallsBackToSafeArea() {
        XCTAssertEqual(
            FloatingActionButtonPlacement.placement(tabBarIsInHierarchy: false, tabBarIsDockedAtBottom: true),
            .bottomSafeArea
        )
    }
}
