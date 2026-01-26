//
//  ObjectListViewModelTests.swift
//  iBurnTests
//
//  Created by Codex on 1/25/26.
//

import CoreLocation
import Dispatch
import XCTest
@preconcurrency @testable import iBurn
import PlayaDB

private struct TestObject: DisplayableObject, Equatable {
    let name: String
    let description: String?
    let uid: String
}

private struct TestFilter: Codable, FavoritesFilterable, Equatable {
    var onlyFavorites: Bool
    var tag: String

    init(onlyFavorites: Bool = false, tag: String = "default") {
        self.onlyFavorites = onlyFavorites
        self.tag = tag
    }
}

private final class TestDataProvider: ObjectListDataProvider {
    typealias Object = TestObject
    typealias Filter = TestFilter

    private(set) var lastObservedFilters: [TestFilter] = []
    private(set) var favoriteCalls: [String] = []
    private(set) var favorites: Set<String> = []

    private var continuations: [String: AsyncStream<[TestObject]>.Continuation] = [:]

    func observeObjects(filter: TestFilter) -> AsyncStream<[TestObject]> {
        lastObservedFilters.append(filter)
        return AsyncStream { continuation in
            self.continuations[filter.tag] = continuation
        }
    }

    func yield(_ objects: [TestObject], tag: String = "main") {
        continuations[tag]?.yield(objects)
    }

    func finish(tag: String = "main") {
        continuations[tag]?.finish()
    }

    func toggleFavorite(_ object: TestObject) async throws {
        favoriteCalls.append(object.uid)
        if favorites.contains(object.uid) {
            favorites.remove(object.uid)
        } else {
            favorites.insert(object.uid)
        }
    }

    func isFavorite(_ object: TestObject) async throws -> Bool {
        favorites.contains(object.uid)
    }

    func distanceAttributedString(from location: CLLocation?, to object: TestObject) -> AttributedString? {
        nil
    }
}

@MainActor
final class ObjectListViewModelTests: XCTestCase {

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

    // MARK: - Tests

    func testLoadingStaysTrueUntilSeededWhenFirstEmissionIsEmpty() async {
        let provider = TestDataProvider()

        var seeded = false
        let vm = ObjectListViewModel<TestObject, TestFilter>(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            filterStorageKey: "ObjectListViewModelTests.loading.\(UUID().uuidString)",
            initialFilter: TestFilter(),
            effectiveFilterForObservation: { f in
                var f = f
                f.tag = "main"
                return f
            },
            favoritesFilterForObservation: { f in
                var f = f
                f.tag = "favorites"
                f.onlyFavorites = true
                return f
            },
            matchesSearch: { obj, q in obj.name.lowercased().contains(q) },
            isDatabaseSeeded: { seeded }
        )

        // Let observation task start.
        await Task.yield()

        provider.yield([], tag: "main") // First emission empty (common during seeding)

        let stillLoading = await eventually { vm.isLoading == true }
        XCTAssertTrue(stillLoading, "Expected isLoading to remain true after an initial empty emission while not seeded")

        seeded = true
        let doneLoading = await eventually(timeoutSeconds: 2.0) { vm.isLoading == false }
        XCTAssertTrue(doneLoading, "Expected isLoading to flip false once the seed gate reports seeded")
    }

    func testLoadingBecomesFalseOnFirstNonEmptyEmission() async {
        let provider = TestDataProvider()

        let vm = ObjectListViewModel<TestObject, TestFilter>(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            filterStorageKey: "ObjectListViewModelTests.loading2.\(UUID().uuidString)",
            initialFilter: TestFilter(),
            effectiveFilterForObservation: { f in
                var f = f
                f.tag = "main"
                return f
            },
            favoritesFilterForObservation: { f in
                var f = f
                f.tag = "favorites"
                f.onlyFavorites = true
                return f
            },
            matchesSearch: { obj, q in obj.name.lowercased().contains(q) },
            isDatabaseSeeded: { false }
        )

        await Task.yield()
        provider.yield([TestObject(name: "Hello", description: nil, uid: "1")], tag: "main")

        let ok = await eventually { vm.isLoading == false && vm.items.count == 1 }
        XCTAssertTrue(ok, "Expected isLoading to become false and items to be populated on first non-empty emission")
    }

    func testFavoriteIDsComeFromFavoritesObservation() async {
        let provider = TestDataProvider()

        let vm = ObjectListViewModel<TestObject, TestFilter>(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            filterStorageKey: "ObjectListViewModelTests.favorites.\(UUID().uuidString)",
            initialFilter: TestFilter(),
            effectiveFilterForObservation: { f in
                var f = f
                f.tag = "main"
                return f
            },
            favoritesFilterForObservation: { f in
                var f = f
                f.tag = "favorites"
                f.onlyFavorites = true
                return f
            },
            matchesSearch: { obj, q in obj.name.lowercased().contains(q) }
        )

        await Task.yield()
        provider.yield([TestObject(name: "Fav", description: nil, uid: "fav")], tag: "favorites")
        let ok = await eventually { vm.favoriteIDs == ["fav"] }
        XCTAssertTrue(ok)
    }

    func testToggleFavoriteCallsProvider() async {
        let provider = TestDataProvider()

        let vm = ObjectListViewModel<TestObject, TestFilter>(
            dataProvider: provider,
            locationProvider: MockLocationProvider(),
            filterStorageKey: "ObjectListViewModelTests.toggle.\(UUID().uuidString)",
            initialFilter: TestFilter(),
            effectiveFilterForObservation: { f in
                var f = f
                f.tag = "main"
                return f
            },
            favoritesFilterForObservation: { f in
                var f = f
                f.tag = "favorites"
                f.onlyFavorites = true
                return f
            },
            matchesSearch: { obj, q in obj.name.lowercased().contains(q) }
        )

        await Task.yield()

        let obj = TestObject(name: "Thing", description: nil, uid: "x")
        provider.yield([obj], tag: "main")

        let gotItem = await eventually { vm.items.count == 1 }
        XCTAssertTrue(gotItem)
        XCTAssertFalse(vm.isFavorite(obj))

        await vm.toggleFavorite(obj)
        let favorited = await eventually { vm.isFavorite(obj) }
        XCTAssertTrue(favorited)
        XCTAssertEqual(provider.favoriteCalls, ["x"])

        // Second toggle should flip back and also toggle provider again.
        await vm.toggleFavorite(obj)
        let unfavorited = await eventually { vm.isFavorite(obj) == false }
        XCTAssertTrue(unfavorited)
        XCTAssertEqual(provider.favoriteCalls, ["x", "x"])
    }
}
