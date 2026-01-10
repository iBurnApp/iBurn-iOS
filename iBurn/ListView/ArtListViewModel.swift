//
//  ArtListViewModel.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

/// View model for the Art list view
///
/// Manages state for displaying and filtering art objects, including:
/// - Observing art objects from PlayaDB via AsyncStream
/// - Tracking current location for distance calculations
/// - Managing filter state with persistence
/// - Handling search text filtering (in-memory)
@MainActor
class ArtListViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All art objects from the database (filtered by current filter)
    @Published var items: [ArtObject] = []

    /// Current filter applied to the list
    @Published var filter: ArtFilter {
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

    private let dataProvider: ArtDataProvider
    private let locationProvider: LocationProvider
    private let legacyDataStore: LegacyDataStore
    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var favoritesTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the view model
    /// - Parameters:
    ///   - dataProvider: The data provider for art objects
    ///   - locationProvider: The provider for location updates
    ///   - initialFilter: Optional initial filter (uses persisted or default)
    init(
        dataProvider: ArtDataProvider,
        locationProvider: LocationProvider,
        initialFilter: ArtFilter = .all,
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

    /// Start observing art objects from the database
    ///
    /// Creates a Task that consumes the AsyncStream from the data provider.
    /// Updates are automatically published to the `items` property.
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

    /// Start observing location updates
    ///
    /// Creates a Task that consumes the AsyncStream from the location provider.
    /// Location updates trigger distance recalculations in the view.
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

    /// Restart observation with current filter
    ///
    /// Called when filter changes to fetch new results from the database.
    private func restartObservation() {
        startObserving()
        refreshFavorites()
    }

    // MARK: - Actions

    /// Toggle the favorite status of an art object
    /// - Parameter object: The art object to toggle
    func toggleFavorite(_ object: ArtObject) async {
        do {
            try await dataProvider.toggleFavorite(object)
            let isFavorite = try await dataProvider.isFavorite(object)
            await legacyDataStore.updateFavoriteStatus(
                uid: object.uid,
                type: .art,
                isFavorite: isFavorite
            )
            refreshFavorites()
        } catch {
            print("Error toggling favorite for \(object.name): \(error)")
        }
    }

    /// Get distance string for an art object
    /// - Parameter object: The art object
    /// - Returns: Formatted distance string or nil if location unavailable
    func distanceString(for object: ArtObject) -> String? {
        dataProvider.distanceString(from: currentLocation, to: object)
    }

    /// Check if an art object is marked as favorite
    /// - Parameter object: The art object to check
    func isFavorite(_ object: ArtObject) -> Bool {
        favoriteIDs.contains(object.uid)
    }

    // MARK: - Computed Properties

    /// Items filtered by search text (in-memory filtering)
    ///
    /// This performs client-side filtering on top of the database filtering.
    /// Search looks in name, description, and artist name.
    var filteredItems: [ArtObject] {
        let baseItems = filter.onlyFavorites
            ? items.filter { favoriteIDs.contains($0.uid) }
            : items

        guard !searchText.isEmpty else { return baseItems }

        let lowercasedSearch = searchText.lowercased()
        return baseItems.filter { art in
            art.name.lowercased().contains(lowercasedSearch) ||
            art.description?.lowercased().contains(lowercasedSearch) == true ||
            art.artist?.lowercased().contains(lowercasedSearch) == true
        }
    }

    // MARK: - Favorites

    private func refreshFavorites() {
        favoritesTask?.cancel()
        favoritesTask = Task { [weak self] in
            guard let self = self else { return }
            let ids = await self.legacyDataStore.favoriteIDs(for: .art)
            await MainActor.run {
                self.favoriteIDs = ids
            }
        }
    }

    private func filterWithoutFavorites() -> ArtFilter {
        var effectiveFilter = filter
        effectiveFilter.onlyFavorites = false
        return effectiveFilter
    }

    // MARK: - Filter Persistence

    /// Save the current filter to UserDefaults
    private func saveFilter() {
        if let data = try? JSONEncoder().encode(filter) {
            UserDefaults.standard.set(data, forKey: "artListFilter")
        }
    }

    /// Load the persisted filter from UserDefaults
    /// - Returns: The persisted filter or nil if not found
    private static func loadFilter() -> ArtFilter? {
        guard let data = UserDefaults.standard.data(forKey: "artListFilter"),
              let filter = try? JSONDecoder().decode(ArtFilter.self, from: data) else {
            return nil
        }
        return filter
    }
}
