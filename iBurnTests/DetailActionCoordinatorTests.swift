//
//  DetailActionCoordinatorTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the `DetailAction` cases that `DetailActionCoordinatorImpl` turns into UIKit
//  presentation/navigation. The coordinator is built through
//  `DetailActionCoordinatorFactory` with recording `Presentable` / `Navigable` doubles, so
//  nothing is actually put on screen.
//

import CoreLocation
import MapLibre
import UIKit
import XCTest
@testable import iBurn

private final class RecordingPresenter: Presentable {
    private(set) var presented: [UIViewController] = []
    private(set) var dismissCount = 0

    func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)?) {
        presented.append(viewControllerToPresent)
        completion?()
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        dismissCount += 1
        completion?()
    }
}

private final class RecordingNavigator: Navigable {
    private(set) var pushed: [UIViewController] = []

    func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushed.append(viewController)
    }
}

@MainActor
final class DetailActionCoordinatorTests: XCTestCase {

    // XCTest makes a fresh test-case instance per test method, so these start empty.
    private let presenter = RecordingPresenter()
    private let navigator = RecordingNavigator()

    private func makeCoordinator(withPresenter: Bool = true, withNavigator: Bool = true) -> DetailActionCoordinator {
        DetailActionCoordinatorFactory.makeCoordinator(
            dependencies: DetailActionCoordinatorDependencies(
                presenter: withPresenter ? presenter : nil,
                navigator: withNavigator ? navigator : nil
            )
        )
    }

    // MARK: - .share

    func testSharePresentsActivityController() throws {
        let coordinator = makeCoordinator()

        coordinator.handle(.share(["Check out this camp"]))

        XCTAssertEqual(presenter.presented.count, 1)
        let presented = try XCTUnwrap(presenter.presented.first)
        XCTAssertTrue(presented is UIActivityViewController)
        XCTAssertTrue(navigator.pushed.isEmpty)
    }

    func testShareWithoutPresenterPresentsNothing() {
        let coordinator = makeCoordinator(withPresenter: false)

        coordinator.handle(.share(["text"]))

        XCTAssertTrue(presenter.presented.isEmpty)
        XCTAssertTrue(navigator.pushed.isEmpty)
    }

    func testUpdatePresenterIsUsedForLaterActions() throws {
        let coordinator = makeCoordinator(withPresenter: false)
        coordinator.updatePresenter(presenter)

        coordinator.handle(.share(["text"]))

        let presented = try XCTUnwrap(presenter.presented.first)
        XCTAssertTrue(presented is UIActivityViewController)
    }

    // MARK: - .shareCoordinates

    func testShareCoordinatesPresentsActivityController() throws {
        let coordinator = makeCoordinator()

        coordinator.handle(.shareCoordinates(CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)))

        let presented = try XCTUnwrap(presenter.presented.first)
        XCTAssertTrue(presented is UIActivityViewController)
    }

    // MARK: - .editNotes

    func testEditNotesPresentsPrefilledAlert() throws {
        let coordinator = makeCoordinator()

        coordinator.handle(.editNotes(current: "Bring water", completion: { _ in }))

        XCTAssertEqual(presenter.presented.count, 1)
        let alert = try XCTUnwrap(presenter.presented.first as? UIAlertController)
        XCTAssertEqual(alert.title, "Edit Notes")
        XCTAssertEqual(alert.preferredStyle, .alert)
        let textField = try XCTUnwrap(alert.textFields?.first)
        XCTAssertEqual(textField.text, "Bring water")
        XCTAssertEqual(alert.actions.map(\.title), ["Cancel", "Save"])
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .default])
    }

    func testEditNotesWithoutPresenterPresentsNothing() {
        let coordinator = makeCoordinator(withPresenter: false)

        coordinator.handle(.editNotes(current: "", completion: { _ in }))

        XCTAssertTrue(presenter.presented.isEmpty)
    }

    // MARK: - .showMapAnnotation

    func testShowMapAnnotationPushesTitledMapList() throws {
        let coordinator = makeCoordinator()
        let annotation = MLNPointAnnotation()
        annotation.coordinate = BRCLocations.blackRockCityCenter

        coordinator.handle(.showMapAnnotation(annotation, title: "Center Camp"))

        XCTAssertEqual(navigator.pushed.count, 1)
        let mapVC = try XCTUnwrap(navigator.pushed.first as? MapListViewController)
        XCTAssertEqual(mapVC.title, "Center Camp")
        XCTAssertTrue(presenter.presented.isEmpty)
    }

    func testShowMapAnnotationWithoutNavigatorPushesNothing() {
        let coordinator = makeCoordinator(withNavigator: false)
        let annotation = MLNPointAnnotation()
        annotation.coordinate = BRCLocations.blackRockCityCenter

        coordinator.handle(.showMapAnnotation(annotation, title: "Center Camp"))

        XCTAssertTrue(navigator.pushed.isEmpty)
        XCTAssertTrue(presenter.presented.isEmpty)
    }

    // MARK: - .showShareURLScreen

    func testShowShareURLScreenPresentsQRCodeSheet() throws {
        let coordinator = makeCoordinator()
        let url = try XCTUnwrap(URL(string: "https://iburnapp.com/camp/?uid=a1b2c3"))

        coordinator.handle(.showShareURLScreen(
            title: "Some Camp",
            locationText: "7:30 & E",
            url: url,
            themeColors: BRCImageColors.dynamic
        ))

        XCTAssertEqual(presenter.presented.count, 1)
        let shareVC = try XCTUnwrap(presenter.presented.first as? ShareQRCodeHostingController)
        XCTAssertEqual(shareVC.modalPresentationStyle, .pageSheet)
    }

    func testShowShareURLScreenWithoutPresenterPresentsNothing() throws {
        let coordinator = makeCoordinator(withPresenter: false)
        let url = try XCTUnwrap(URL(string: "https://iburnapp.com/camp/?uid=a1b2c3"))

        coordinator.handle(.showShareURLScreen(
            title: "Some Camp",
            locationText: nil,
            url: url,
            themeColors: BRCImageColors.dynamic
        ))

        XCTAssertTrue(presenter.presented.isEmpty)
    }

    // MARK: - .navigateToViewController

    func testNavigateToViewControllerPushesSameInstance() throws {
        let coordinator = makeCoordinator()
        let destination = UIViewController()

        coordinator.handle(.navigateToViewController(destination))

        let pushed = try XCTUnwrap(navigator.pushed.first)
        XCTAssertTrue(pushed === destination)
        XCTAssertTrue(presenter.presented.isEmpty)
    }

    func testUpdateNavigatorIsUsedForLaterActions() throws {
        let coordinator = makeCoordinator(withNavigator: false)
        coordinator.updateNavigator(navigator)
        let destination = UIViewController()

        coordinator.handle(.navigateToViewController(destination))

        let pushed = try XCTUnwrap(navigator.pushed.first)
        XCTAssertTrue(pushed === destination)
    }

    // MARK: - .pauseAudio

    func testPauseAudioIsANoOp() {
        let coordinator = makeCoordinator()

        coordinator.handle(.pauseAudio)

        XCTAssertTrue(presenter.presented.isEmpty)
        XCTAssertTrue(navigator.pushed.isEmpty)
    }
}
