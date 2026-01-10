//
//  CampListViewModel.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

/// View model for the Camp list view
@MainActor
class CampListViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All camp objects from the database (filtered by current filter)
    @Published var items: [CampObject] = []

    /// Current filter applied to the list
    @Published var filter: CampFilter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    /// Search text for in-memory filtering
    @Published var searchText: String = ""

    /// Loading state (true during initial load)
    @Published var isLoading: Bool = true

    /// Current user location for distance calculations
    @Published var currentLocation: CLLocation?

    /// Favorite IDs from the legacy YapDatabase metadata
    @Published private(set) var favoriteIDs: Set<String> = []

    // MARK: - Private Properties

    private let dataProvider: CampDataProvider
    private let locationProvider: LocationProvider
    private let legacyDataStore: LegacyDataStore
    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var favoritesTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        dataProvider: CampDataProvider,
        locationProvider: LocationProvider,
        initialFilter: CampFilter = .all,
        legacyDataStore: LegacyDataStore = LegacyDataStore()
    ) {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.legacyDataStore = legacyDataStore
        self.filter = Self.loadFilter() ?? initialFilter
        self.currentLocation = locationProvider.currentLocation

        startObserving()
        startLocationUpdates()
        refreshFavorites()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        favoritesTask?.cancel()
    }

    // MARK: - Observation

    private func startObserving() {
        observationTask?.cancel()
        isLoading = true
        let effectiveFilter = filterWithoutFavorites()

        observationTask = Task { [weak self] in
            guard let self = self else { return }

            for await items in self.dataProvider.observeObjects(filter: effectiveFilter) {
                await MainActor.run {
                    self.items = items
                    self.isLoading = false
                }
            }
        }
    }

    private func startLocationUpdates() {
        locationTask?.cancel()

        locationTask = Task { [weak self] in
            guard let self = self else { return }

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

    // MARK: - Actions

    func toggleFavorite(_ object: CampObject) async {
        do {
            try await dataProvider.toggleFavorite(object)
            let isFavorite = try await dataProvider.isFavorite(object)
            await legacyDataStore.updateFavoriteStatus(
                uid: object.uid,
                type: .camp,
                isFavorite: isFavorite
            )
            refreshFavorites()
        } catch {
            print("Error toggling favorite for \(object.name): \(error)")
        }
    }

    func distanceString(for object: CampObject) -> String? {
        dataProvider.distanceString(from: currentLocation, to: object)
    }

    func isFavorite(_ object: CampObject) -> Bool {
        favoriteIDs.contains(object.uid)
    }

    // MARK: - Computed Properties

    var filteredItems: [CampObject] {
        let baseItems = filter.onlyFavorites
            ? items.filter { favoriteIDs.contains($0.uid) }
            : items

        guard !searchText.isEmpty else { return baseItems }

        let lowercasedSearch = searchText.lowercased()
        return baseItems.filter { camp in
            camp.name.lowercased().contains(lowercasedSearch) ||
            camp.description?.lowercased().contains(lowercasedSearch) == true ||
            camp.hometown?.lowercased().contains(lowercasedSearch) == true ||
            camp.landmark?.lowercased().contains(lowercasedSearch) == true ||
            camp.locationString?.lowercased().contains(lowercasedSearch) == true
        }
    }

    // MARK: - Favorites

    private func refreshFavorites() {
        favoritesTask?.cancel()
        favoritesTask = Task { [weak self] in
            guard let self = self else { return }
            let ids = await self.legacyDataStore.favoriteIDs(for: .camp)
            await MainActor.run {
                self.favoriteIDs = ids
            }
        }
    }

    private func filterWithoutFavorites() -> CampFilter {
        var effectiveFilter = filter
        effectiveFilter.onlyFavorites = false
        return effectiveFilter
    }

    // MARK: - Filter Persistence

    private func saveFilter() {
        if let data = try? JSONEncoder().encode(filter) {
            UserDefaults.standard.set(data, forKey: "campListFilter")
        }
    }

    private static func loadFilter() -> CampFilter? {
        guard let data = UserDefaults.standard.data(forKey: "campListFilter"),
              let filter = try? JSONDecoder().decode(CampFilter.self, from: data) else {
            return nil
        }
        return filter
    }
}
