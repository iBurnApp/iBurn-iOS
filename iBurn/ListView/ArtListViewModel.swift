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

    // MARK: - Private Properties

    private let dataProvider: ArtDataProvider
    private let locationProvider: LocationProvider
    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Initialize the view model
    /// - Parameters:
    ///   - dataProvider: The data provider for art objects
    ///   - locationProvider: The provider for location updates
    ///   - initialFilter: Optional initial filter (uses persisted or default)
    init(
        dataProvider: ArtDataProvider,
        locationProvider: LocationProvider,
        initialFilter: ArtFilter = .all
    ) {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.filter = Self.loadFilter() ?? initialFilter
        self.currentLocation = locationProvider.currentLocation

        startObserving()
        startLocationUpdates()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
    }

    // MARK: - Observation

    /// Start observing art objects from the database
    ///
    /// Creates a Task that consumes the AsyncStream from the data provider.
    /// Updates are automatically published to the `items` property.
    private func startObserving() {
        observationTask?.cancel()
        isLoading = true

        observationTask = Task { [weak self] in
            guard let self = self else { return }

            for await items in self.dataProvider.observeObjects(filter: self.filter) {
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
    }

    // MARK: - Actions

    /// Toggle the favorite status of an art object
    /// - Parameter object: The art object to toggle
    func toggleFavorite(_ object: ArtObject) async {
        do {
            try await dataProvider.toggleFavorite(object)
            // AsyncStream will automatically update items
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

    // MARK: - Computed Properties

    /// Items filtered by search text (in-memory filtering)
    ///
    /// This performs client-side filtering on top of the database filtering.
    /// Search looks in name, description, and artist name.
    var filteredItems: [ArtObject] {
        guard !searchText.isEmpty else { return items }

        let lowercasedSearch = searchText.lowercased()
        return items.filter { art in
            art.name.lowercased().contains(lowercasedSearch) ||
            art.description?.lowercased().contains(lowercasedSearch) == true ||
            art.artist?.lowercased().contains(lowercasedSearch) == true
        }
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
