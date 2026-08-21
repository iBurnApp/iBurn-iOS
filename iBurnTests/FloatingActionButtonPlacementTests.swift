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

/// The rule that decides whether the tab bar's state takes the button off screen — and, since
/// the cold-launch bug, refuses to answer from frames that don't exist yet.
final class FloatingActionButtonBarVisibilityTests: XCTestCase {

    /// The bug: the button is installed before the window has a root view controller, so the
    /// bar's `minY` and the view's height are both 0 and `0 >= 0` read as "the bar slid off the
    /// bottom". On a slow launch no later layout pass corrected it and the button was missing
    /// from the first tab until the user switched tabs.
    func testZeroGeometryAtColdLaunchDoesNotHide() {
        XCTAssertFalse(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: false,
                tabBarAlpha: 1,
                barFrameMinY: 0,
                viewHeight: 0
            )
        )
    }

    /// Same rule when the frame can't be converted at all: unknown is not off screen.
    func testUnknownBarFrameDoesNotHide() {
        XCTAssertFalse(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: false,
                tabBarAlpha: 1,
                barFrameMinY: nil,
                viewHeight: 852
            )
        )
    }

    /// A bar that has really been moved off the bottom edge takes the button with it.
    func testBarBelowTheViewHides() {
        XCTAssertTrue(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: false,
                tabBarAlpha: 1,
                barFrameMinY: 852,
                viewHeight: 852
            )
        )
    }

    /// The normal case: bar docked at the bottom of a real view, button on screen.
    func testDockedBarShowsTheButton() {
        XCTAssertFalse(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: false,
                tabBarAlpha: 1,
                barFrameMinY: 770,
                viewHeight: 852
            )
        )
    }

    /// `isHidden`/`alpha` are states the bar was explicitly put into, not measurements, so they
    /// hide the button even with no geometry to check.
    func testHiddenBarHidesRegardlessOfGeometry() {
        XCTAssertTrue(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: true,
                tabBarAlpha: 1,
                barFrameMinY: nil,
                viewHeight: 0
            )
        )
    }

    func testTransparentBarHidesRegardlessOfGeometry() {
        XCTAssertTrue(
            FloatingActionButtonBarVisibility.isHidden(
                tabBarHidden: false,
                tabBarAlpha: 0,
                barFrameMinY: 770,
                viewHeight: 852
            )
        )
    }
}
