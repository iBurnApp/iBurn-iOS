//
//  DetailPagingDataSourceTests.swift
//  iBurnTests
//
//  Covers the detail pager's controller caching and nav-bar deferral, which back the
//  build-114 "No view controller managing visible view" crash fix: UIKit must get the
//  same controller instance every time it asks for a neighbour, every page must report
//  to the container, and navigation-item forwarding must wait out a page transition.
//

import UIKit
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

@MainActor
final class DetailPagingDataSourceTests: XCTestCase {

    private var playaDB: PlayaDB?

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeDataSource(count: Int) throws -> DetailPagingDataSource {
        let db = try XCTUnwrap(playaDB)
        let subjects: [DetailSubject] = (0..<count).map { index in
            .art(ArtObject(uid: "art-\(index)", name: "Art \(index)", year: 2026))
        }
        return DetailPagingDataSource(subjects: subjects, playaDB: db)
    }

    private func makePager(
        _ dataSource: DetailPagingDataSource,
        initialIndex: Int
    ) throws -> (DetailPageViewController, UIViewController) {
        let pageVC = try XCTUnwrap(
            dataSource.makePageViewController(initialIndex: initialIndex) as? DetailPageViewController
        )
        let current = try XCTUnwrap(pageVC.viewControllers?.first)
        return (pageVC, current)
    }

    /// Lets queued main-queue work (the deferred navigation update) run.
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    // MARK: - Caching

    func testRepeatedNeighbourRequestsReturnTheSameInstance() throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 1)

        let after1 = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerAfter: current))
        let after2 = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerAfter: current))
        XCTAssertIdentical(after1, after2)

        let before1 = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerBefore: current))
        let before2 = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerBefore: current))
        XCTAssertIdentical(before1, before2)
        XCTAssertNotIdentical(before1, after1)
    }

    func testNeighbourOfANeighbourIsTheOriginalController() throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 1)

        let after = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerAfter: current))
        let backAgain = dataSource.pageViewController(pageVC, viewControllerBefore: after)
        XCTAssertIdentical(backAgain, current)
        XCTAssertEqual(dataSource.index(of: after), 2)
    }

    func testEndsOfTheListHaveNoNeighbours() throws {
        let dataSource = try makeDataSource(count: 3)

        let (firstPager, first) = try makePager(dataSource, initialIndex: 0)
        XCTAssertNil(dataSource.pageViewController(firstPager, viewControllerBefore: first))
        XCTAssertNotNil(dataSource.pageViewController(firstPager, viewControllerAfter: first))

        let (lastPager, last) = try makePager(dataSource, initialIndex: 2)
        XCTAssertNil(dataSource.pageViewController(lastPager, viewControllerAfter: last))
        XCTAssertNotNil(dataSource.pageViewController(lastPager, viewControllerBefore: last))
    }

    func testSingleItemHasNoNeighbours() throws {
        let dataSource = try makeDataSource(count: 1)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 0)
        XCTAssertNil(dataSource.pageViewController(pageVC, viewControllerBefore: current))
        XCTAssertNil(dataSource.pageViewController(pageVC, viewControllerAfter: current))
    }

    func testOutOfRangeIndexHasNoController() throws {
        let dataSource = try makeDataSource(count: 2)
        XCTAssertNil(dataSource.controller(at: -1))
        XCTAssertNil(dataSource.controller(at: 2))
    }

    func testForeignControllerHasNoNeighbours() throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, _) = try makePager(dataSource, initialIndex: 1)
        let foreign = UIViewController()
        XCTAssertNil(dataSource.pageViewController(pageVC, viewControllerAfter: foreign))
        XCTAssertNil(dataSource.pageViewController(pageVC, viewControllerBefore: foreign))
    }

    // MARK: - Event handler wiring

    func testEveryPageReportsToThePageViewController() throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 1)

        let initial = try XCTUnwrap(current as? DetailHostingController)
        XCTAssertIdentical(initial.eventHandler, pageVC)

        let after = try XCTUnwrap(
            dataSource.pageViewController(pageVC, viewControllerAfter: current) as? DetailHostingController
        )
        XCTAssertIdentical(after.eventHandler, pageVC)

        let before = try XCTUnwrap(
            dataSource.pageViewController(pageVC, viewControllerBefore: current) as? DetailHostingController
        )
        XCTAssertIdentical(before.eventHandler, pageVC)
    }

    /// The container owns its pages, so a strong back-reference would leak every pager.
    func testEventHandlerIsWeak() throws {
        let dataSource = try makeDataSource(count: 2)
        let child = try XCTUnwrap(dataSource.controller(at: 0) as? DetailHostingController)
        final class Handler: DynamicViewControllerEventHandler {
            func viewControllerDidTriggerEvent(_ event: ViewControllerEvent, sender: UIViewController) {}
        }
        autoreleasepool {
            let handler = Handler()
            child.eventHandler = handler
            XCTAssertNotNil(child.eventHandler)
        }
        XCTAssertNil(child.eventHandler)
    }

    // MARK: - Navigation-item deferral

    func testNavigationUpdatesWaitForThePageTransitionToEnd() async throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 1)

        pageVC.pageTransitionWillBegin()
        XCTAssertTrue(pageVC.isPageTransitionInProgress)
        XCTAssertFalse(pageVC.canUpdateNavigation)

        current.title = "Changed mid-swipe"
        pageVC.viewControllerDidTriggerEvent(.viewDidAppear, sender: current)
        XCTAssertNotEqual(pageVC.title, "Changed mid-swipe", "no nav-bar mutation while the pager is scrolling")
        XCTAssertTrue(pageVC.needsNavigationUpdate)

        pageVC.pageTransitionDidEnd(completed: false)
        XCTAssertFalse(pageVC.isPageTransitionInProgress)
        await drainMainQueue()
        XCTAssertEqual(pageVC.title, "Changed mid-swipe")
        XCTAssertFalse(pageVC.needsNavigationUpdate)
    }

    func testEventsFromOffscreenPagesAreIgnored() throws {
        let dataSource = try makeDataSource(count: 3)
        let (pageVC, current) = try makePager(dataSource, initialIndex: 1)
        let neighbour = try XCTUnwrap(dataSource.pageViewController(pageVC, viewControllerAfter: current))

        pageVC.title = current.title
        neighbour.title = "Neighbour"
        pageVC.viewControllerDidTriggerEvent(.viewDidAppear, sender: neighbour)
        XCTAssertEqual(pageVC.title, current.title)
    }
}
