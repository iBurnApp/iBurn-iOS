//
//  ObjectListViewModel.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import CoreLocation
import Dispatch
import Foundation
import PlayaDB

@MainActor
final class ObjectListViewModel<Object: DisplayableObject, Filter: Codable & FavoritesFilterable>: ObservableObject {
    // MARK: - Published

    @Published var items: [Object] = []

    @Published var filter: Filter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?
    @Published private(set) var favoriteIDs: Set<String> = []

    // MARK: - Dependencies

    private let dataProvider: any ObjectListDataProvider<Object, Filter>
    private let locationProvider: LocationProvider
    private let legacyDataStore: any LegacyFavoritesStoring
    private let legacyType: DataObjectType
    private let filterStorageKey: String
    private let effectiveFilterForObservation: (Filter) -> Filter
    private let matchesSearch: (Object, String) -> Bool
    private let isDatabaseSeeded: (() async -> Bool)?

    // MARK: - Tasks

    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var favoritesTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?

    // MARK: - Init

    init<DataProvider: ObjectListDataProvider>(
        dataProvider: DataProvider,
        locationProvider: LocationProvider,
        legacyType: DataObjectType,
        filterStorageKey: String,
        initialFilter: Filter,
        legacyDataStore: any LegacyFavoritesStoring = LegacyDataStore(),
        effectiveFilterForObservation: @escaping (Filter) -> Filter,
        matchesSearch: @escaping (Object, String) -> Bool,
        isDatabaseSeeded: (() async -> Bool)? = nil
    ) where DataProvider.Object == Object, DataProvider.Filter == Filter {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.legacyDataStore = legacyDataStore
        self.legacyType = legacyType
        self.filterStorageKey = filterStorageKey
        self.effectiveFilterForObservation = effectiveFilterForObservation
        self.matchesSearch = matchesSearch
        self.isDatabaseSeeded = isDatabaseSeeded

        self.filter = Self.loadFilter(key: filterStorageKey) ?? initialFilter
        self.currentLocation = locationProvider.currentLocation

        startObserving()
        startLocationUpdates()
        refreshFavorites()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        favoritesTask?.cancel()
        loadingGateTask?.cancel()
    }

    // MARK: - Derived

    func isFavorite(_ object: Object) -> Bool {
        favoriteIDs.contains(object.uid)
    }

    func distanceAttributedString(for object: Object) -> AttributedString? {
        dataProvider.distanceAttributedString(from: currentLocation, to: object)
    }

    var filteredItems: [Object] {
        let baseItems = filter.onlyFavorites
            ? items.filter { favoriteIDs.contains($0.uid) }
            : items

        guard !searchText.isEmpty else { return baseItems }
        let q = searchText.lowercased()
        return baseItems.filter { matchesSearch($0, q) }
    }

    // MARK: - Actions

    func toggleFavorite(_ object: Object) async {
        // Legacy (Yap) favorites are the current UI source of truth during migration.
        // PlayaDB may be out-of-sync initially, so always drive the desired state from the UI.
        let desiredIsFavorite = !isFavorite(object)

        // Optimistically update UI to keep the row responsive.
        if desiredIsFavorite {
            favoriteIDs.insert(object.uid)
        } else {
            favoriteIDs.remove(object.uid)
        }

        await legacyDataStore.updateFavoriteStatus(
            uid: object.uid,
            type: legacyType,
            isFavorite: desiredIsFavorite
        )

        do {
            try await ensurePlayaDBFavoriteMatches(object, desiredIsFavorite: desiredIsFavorite)
        } catch {
            print("Error syncing PlayaDB favorite for \(object.name): \(error)")
        }

        refreshFavorites()
    }

    // MARK: - Observation

    private func startObserving() {
        observationTask?.cancel()
        loadingGateTask?.cancel()

        isLoading = true
        let filterForObservation = effectiveFilterForObservation(filter)

        observationTask = Task { [weak self] in
            guard let self else { return }

            var didReceiveFirstEmission = false
            for await observedItems in self.dataProvider.observeObjects(filter: filterForObservation) {
                didReceiveFirstEmission = true
                await MainActor.run {
                    self.items = observedItems
                    if !observedItems.isEmpty {
                        self.isLoading = false
                    }
                }

                if didReceiveFirstEmission, !observedItems.isEmpty {
                    loadingGateTask?.cancel()
                } else if didReceiveFirstEmission, observedItems.isEmpty {
                    startLoadingGateIfNeeded()
                }
            }
        }
    }

    private func startLoadingGateIfNeeded() {
        guard loadingGateTask == nil else { return }
        guard let isDatabaseSeeded else {
            isLoading = false
            return
        }

        loadingGateTask = Task { [weak self] in
            guard let self else { return }

            let timeoutNanoseconds: UInt64 = 5_000_000_000
            let pollNanoseconds: UInt64 = 200_000_000
            let start = DispatchTime.now().uptimeNanoseconds

            while !Task.isCancelled {
                if await isDatabaseSeeded() {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                let elapsed = DispatchTime.now().uptimeNanoseconds - start
                if elapsed >= timeoutNanoseconds {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }
        }
    }

    private func startLocationUpdates() {
        locationTask?.cancel()

        locationTask = Task { [weak self] in
            guard let self else { return }

            for await location in self.locationProvider.locationStream {
                await MainActor.run {
                    self.currentLocation = location
                }
            }
        }
    }

    private func restartObservation() {
        startObserving()
        refreshFavorites()
    }

    // MARK: - Favorites

    private func refreshFavorites() {
        favoritesTask?.cancel()
        favoritesTask = Task { [weak self] in
            guard let self else { return }
            let ids = await self.legacyDataStore.favoriteIDs(for: self.legacyType)
            await MainActor.run {
                self.favoriteIDs = ids
            }
        }
    }

    private func ensurePlayaDBFavoriteMatches(_ object: Object, desiredIsFavorite: Bool) async throws {
        let current = try await dataProvider.isFavorite(object)
        guard current != desiredIsFavorite else { return }
        try await dataProvider.toggleFavorite(object)
    }

    // MARK: - Filter Persistence

    private func saveFilter() {
        guard let data = try? JSONEncoder().encode(filter) else { return }
        UserDefaults.standard.set(data, forKey: filterStorageKey)
    }

    private static func loadFilter(key: String) -> Filter? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let filter = try? JSONDecoder().decode(Filter.self, from: data) else {
            return nil
        }
        return filter
    }
}
