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

    /// MV image downloader
    private let mvImageDownloader: MutantVehicleImageDownloader

    /// Art/camp thumbnail image downloader
    private let thumbnailImageDownloader: ThumbnailImageDownloader

    // MARK: - Data Providers (Lazy)

    /// Data provider for Art objects
    private(set) lazy var artDataProvider: ArtDataProvider = {
        ArtDataProvider(playaDB: playaDB)
    }()

    /// Data provider for Camp objects
    private(set) lazy var campDataProvider: CampDataProvider = {
        CampDataProvider(playaDB: playaDB)
    }()

    /// Data provider for Event objects
    private(set) lazy var eventDataProvider: EventDataProvider = {
        EventDataProvider(playaDB: playaDB)
    }()

    /// Data provider for MutantVehicle objects
    private(set) lazy var mutantVehicleDataProvider: MutantVehicleDataProvider = {
        MutantVehicleDataProvider(playaDB: playaDB)
    }()

    /// AI search service (nil if device doesn't support Apple Intelligence)
    private(set) lazy var aiSearchService: AISearchService? = {
        AISearchServiceFactory.create(playaDB: playaDB)
    }()

    /// AI assistant service for recommendations, day planner, nearby (nil if unavailable)
    private(set) lazy var aiAssistantService: AIAssistantService? = {
        AISearchServiceFactory.createAssistant(playaDB: playaDB)
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

        self.mvImageDownloader = MutantVehicleImageDownloader(playaDB: self.playaDB)
        self.mvImageDownloader.downloadUncachedImages()

        self.thumbnailImageDownloader = ThumbnailImageDownloader(playaDB: self.playaDB)
        self.thumbnailImageDownloader.downloadUncachedImages()
    }

    // MARK: - Factory Methods

    /// Create a GlobalSearchViewModel with injected dependencies
    func makeGlobalSearchViewModel() -> GlobalSearchViewModel {
        GlobalSearchViewModel(playaDB: playaDB, aiSearchService: aiSearchService)
    }

    /// Create a GlobalSearchHostingController for use as UISearchController.searchResultsController
    func makeGlobalSearchHostingController() -> GlobalSearchHostingController {
        let vm = makeGlobalSearchViewModel()
        return GlobalSearchHostingController(viewModel: vm, playaDB: playaDB)
    }

    /// Create an ArtListViewModel with injected dependencies
    /// - Parameter initialFilter: Optional initial filter (defaults to .all)
    /// - Returns: Configured ArtListViewModel
    func makeArtListViewModel(initialFilter: ArtFilter = .all) -> ArtListViewModel {
        ObjectListViewModel(
            dataProvider: artDataProvider,
            locationProvider: locationProvider,
            filterStorageKey: "artListFilter",
            initialFilter: initialFilter,
            effectiveFilterForObservation: { $0 },
            favoritesFilterForObservation: { filter in
                var f = filter
                f.searchText = nil
                f.onlyWithEvents = false
                f.onlyFavorites = true
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

    /// Create an EventListViewModel with injected dependencies
    /// - Returns: Configured EventListViewModel
    func makeEventListViewModel() -> EventListViewModel {
        EventListViewModel(
            dataProvider: eventDataProvider,
            locationProvider: locationProvider,
            festivalDays: YearSettings.festivalDays
        )
    }

    /// Create a MutantVehicleListViewModel with injected dependencies
    func makeMutantVehicleListViewModel(initialFilter: MutantVehicleFilter = .all) -> MutantVehicleListViewModel {
        ObjectListViewModel(
            dataProvider: mutantVehicleDataProvider,
            locationProvider: locationProvider,
            filterStorageKey: "mvListFilter",
            initialFilter: initialFilter,
            effectiveFilterForObservation: { $0 },
            favoritesFilterForObservation: { filter in
                var f = filter
                f.searchText = nil
                f.tag = nil
                f.onlyFavorites = true
                return f
            },
            matchesSearch: { mv, q in
                mv.name.lowercased().contains(q) ||
                mv.description?.lowercased().contains(q) == true ||
                mv.artist?.lowercased().contains(q) == true ||
                mv.hometown?.lowercased().contains(q) == true ||
                mv.tagsText?.lowercased().contains(q) == true
            },
            isDatabaseSeeded: { [mutantVehicleDataProvider] in
                await mutantVehicleDataProvider.isDatabaseSeeded()
            }
        )
    }

    /// Create an AIAssistantViewModel (nil if AI not available)
    func makeAIAssistantViewModel() -> AIAssistantViewModel? {
        guard let aiService = aiAssistantService else { return nil }
        return AIAssistantViewModel(
            aiService: aiService,
            playaDB: playaDB,
            locationProvider: locationProvider
        )
    }

    /// Create a NearbyViewModel with injected dependencies
    func makeNearbyViewModel() -> NearbyViewModel {
        NearbyViewModel(
            playaDB: playaDB,
            artProvider: artDataProvider,
            campProvider: campDataProvider,
            eventProvider: eventDataProvider,
            locationProvider: locationProvider
        )
    }

    /// Create a FavoritesViewModel with injected dependencies
    func makeFavoritesViewModel() -> FavoritesViewModel {
        FavoritesViewModel(
            artProvider: artDataProvider,
            campProvider: campDataProvider,
            eventProvider: eventDataProvider,
            mvProvider: mutantVehicleDataProvider,
            locationProvider: locationProvider
        )
    }

    /// Create a CampListViewModel with injected dependencies
    /// - Parameter initialFilter: Optional initial filter (defaults to .all)
    /// - Returns: Configured CampListViewModel
    func makeCampListViewModel(initialFilter: CampFilter = .all) -> CampListViewModel {
        ObjectListViewModel(
            dataProvider: campDataProvider,
            locationProvider: locationProvider,
            filterStorageKey: "campListFilter",
            initialFilter: initialFilter,
            effectiveFilterForObservation: { $0 },
            favoritesFilterForObservation: { filter in
                var f = filter
                f.searchText = nil
                f.onlyFavorites = true
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
