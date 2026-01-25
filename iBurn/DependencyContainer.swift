//
//  DependencyContainer.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB

/// Central container for app-wide dependencies
/// Ensures single instances of core services (PlayaDB, LocationProvider)
/// and provides factory methods for creating ViewModels with injected dependencies
@MainActor
class DependencyContainer {
    // MARK: - Core Services

    /// Single PlayaDB instance for the entire app
    let playaDB: PlayaDB

    /// Location provider for user location updates
    let locationProvider: LocationProvider

    /// Preference service for app settings
    let preferenceService: PreferenceService

    /// Background seeder for PlayaDB
    private let playaDBSeeder: PlayaDBSeeder

    // MARK: - Data Providers (Lazy)

    /// Data provider for Art objects
    private(set) lazy var artDataProvider: ArtDataProvider = {
        ArtDataProvider(playaDB: playaDB)
    }()

    /// Data provider for Camp objects
    private(set) lazy var campDataProvider: CampDataProvider = {
        CampDataProvider(playaDB: playaDB)
    }()

    // MARK: - Initialization

    /// Initialize the dependency container
    /// - Parameter preferenceService: The preference service to use (defaults to shared instance)
    /// - Throws: PlayaDB creation errors
    init(preferenceService: PreferenceService = PreferenceServiceFactory.shared, playaDB: PlayaDB? = nil) throws {
        // Create PlayaDB once using factory method, or use injected instance
        self.playaDB = try playaDB ?? createPlayaDB()

        // Create location provider once
        // Note: This assumes BRCAppDelegate.shared is available
        // In tests, you'd pass a mock location manager
        self.locationProvider = CoreLocationProvider(
            locationManager: BRCAppDelegate.shared.locationManager
        )

        self.preferenceService = preferenceService

        self.playaDBSeeder = PlayaDBSeeder(playaDB: self.playaDB)
        self.playaDBSeeder.seedIfNeeded()
    }

    // MARK: - Factory Methods

    /// Create an ArtListViewModel with injected dependencies
    /// - Parameter initialFilter: Optional initial filter (defaults to .all)
    /// - Returns: Configured ArtListViewModel
    func makeArtListViewModel(initialFilter: ArtFilter = .all) -> ArtListViewModel {
        ObjectListViewModel(
            dataProvider: artDataProvider,
            locationProvider: locationProvider,
            legacyType: .art,
            filterStorageKey: "artListFilter",
            initialFilter: initialFilter,
            effectiveFilterForObservation: { filter in
                var f = filter
                f.onlyFavorites = false
                return f
            },
            matchesSearch: { art, q in
                art.name.lowercased().contains(q) ||
                art.description?.lowercased().contains(q) == true ||
                art.artist?.lowercased().contains(q) == true
            },
            isDatabaseSeeded: { [artDataProvider] in
                await artDataProvider.isDatabaseSeeded()
            }
        )
    }

    /// Create a CampListViewModel with injected dependencies
    /// - Parameter initialFilter: Optional initial filter (defaults to .all)
    /// - Returns: Configured CampListViewModel
    func makeCampListViewModel(initialFilter: CampFilter = .all) -> CampListViewModel {
        ObjectListViewModel(
            dataProvider: campDataProvider,
            locationProvider: locationProvider,
            legacyType: .camp,
            filterStorageKey: "campListFilter",
            initialFilter: initialFilter,
            effectiveFilterForObservation: { filter in
                var f = filter
                f.onlyFavorites = false
                return f
            },
            matchesSearch: { camp, q in
                camp.name.lowercased().contains(q) ||
                camp.description?.lowercased().contains(q) == true ||
                camp.hometown?.lowercased().contains(q) == true ||
                camp.landmark?.lowercased().contains(q) == true ||
                camp.locationString?.lowercased().contains(q) == true
            },
            isDatabaseSeeded: { [campDataProvider] in
                await campDataProvider.isDatabaseSeeded()
            }
        )
    }
}
