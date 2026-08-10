//
//  DependencyContainer.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import CoreLocation
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

    /// Syncs favorites with the paired Apple Watch over WatchConnectivity.
    private var watchSyncManager: PeerSyncManager?

    /// Mirrors PlayaDB favorite changes into the legacy YapDatabase so both stores agree.
    /// Lazy so BRCDatabaseManager is only touched once the first provider is used.
    private(set) lazy var favoriteSyncService: FavoriteSyncService = {
        FavoriteSyncServiceFactory.shared
    }()

    /// Owns the device-calendar (EventKit) entries for favorited events, bookkeeping
    /// their identifiers in PlayaDB. Used when
    /// `Preferences.FeatureFlags.usePlayaDBCalendarSync` is on (the default); the legacy
    /// Yap path takes over when it is off. Lazy so EventKit and BRCDatabaseManager are
    /// only touched once a favorite actually changes.
    private(set) lazy var eventCalendarService: EventCalendarService = {
        EventCalendarServiceFactory.makeService(playaDB: playaDB)
    }()

    /// Offers "favorite the other showings too?" after a single occurrence of a recurring
    /// event is favorited. Listens app-wide rather than per screen — see the type's docs.
    private(set) lazy var favoriteSeriesToastPresenter: FavoriteSeriesToastPresenter = {
        FavoriteSeriesToastPresenter(playaDB: playaDB, favoriteSync: favoriteSyncService)
    }()

    // MARK: - Data Providers (Lazy)

    /// Data provider for Art objects
    private(set) lazy var artDataProvider: ArtDataProvider = {
        ArtDataProvider(playaDB: playaDB, favoriteSync: favoriteSyncService)
    }()

    /// Data provider for Camp objects
    private(set) lazy var campDataProvider: CampDataProvider = {
        CampDataProvider(playaDB: playaDB, favoriteSync: favoriteSyncService)
    }()

    /// Data provider for Event objects
    private(set) lazy var eventDataProvider: EventDataProvider = {
        EventDataProvider(playaDB: playaDB, favoriteSync: favoriteSyncService)
    }()

    /// Data provider for MutantVehicle objects
    private(set) lazy var mutantVehicleDataProvider: MutantVehicleDataProvider = {
        MutantVehicleDataProvider(playaDB: playaDB, favoriteSync: favoriteSyncService)
    }()

    /// AI search service (nil if device doesn't support Apple Intelligence)
    private(set) lazy var aiSearchService: AISearchService? = {
        AISearchServiceFactory.create(playaDB: playaDB)
    }()

    // MARK: - Initialization

    /// Initialize the dependency container
    /// - Parameter preferenceService: The preference service to use (defaults to shared instance)
    /// - Throws: PlayaDB creation errors
    init(preferenceService: PreferenceService = PreferenceServiceFactory.shared, playaDB: PlayaDB? = nil) throws {
        // Restore a pre-populated PlayaDB from the bundled seed before the database
        // is opened. No-op for existing installs or when the seed is absent, in which
        // case the JSON import path (playaDBSeeder.seedIfNeeded, below) takes over.
        // Skipped when a PlayaDB is injected (tests/previews provide their own store).
        if playaDB == nil {
            PlayaDBSeeder.restoreBundledSeedIfNeeded()
        }

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
        let mvTask = self.mvImageDownloader.downloadUncachedImages()

        self.thumbnailImageDownloader = ThumbnailImageDownloader(playaDB: self.playaDB)
        let thumbTask = self.thumbnailImageDownloader.downloadUncachedImages()

        // After downloads complete, prefetch missing thumbnail colors
        Task.detached(priority: .utility) { [playaDB = self.playaDB] in
            _ = await mvTask.value
            _ = await thumbTask.value
            await ColorPrefetcher.prefetchMissingColors(playaDB: playaDB)
        }

        // Sync favorites and user map pins with the paired Apple Watch.
        // Favorites applied from the watch are mirrored into the legacy
        // YapDatabase so legacy surfaces (and event calendar entries) stay in
        // agreement; pins need no mirror — PlayaDB is already their source of
        // truth and FilteredMapDataSource observes them straight onto the map.
        // The callback arrives on a background queue; hop to the main actor
        // before touching self.
        let watchSyncManager = PeerSyncManager(playaDB: self.playaDB, onFavoritesApplied: { [weak self] applied in
            Task { @MainActor [weak self] in
                guard let self else { return }
                for item in applied {
                    guard let type = FavoriteSyncObjectType(objectTypeRawValue: item.objectType) else { continue }
                    // Applied items don't say which field changed, so mirror both.
                    // Each mirror is a no-op when the Yap value already matches,
                    // so this is cheap and idempotent.
                    await self.favoriteSyncService.mirrorFavorite(
                        type: type,
                        uid: item.objectId,
                        isFavorite: item.isFavorite
                    )
                    await self.favoriteSyncService.mirrorVisitStatus(
                        type: type,
                        uid: item.objectId,
                        visitStatus: item.visitStatus
                    )
                }
            }
        })
        watchSyncManager.start()
        self.watchSyncManager = watchSyncManager

        // Every heart in the app posts through PlayaDB, so one listener covers them all.
        self.favoriteSeriesToastPresenter.start()
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

    /// Create the AI Guide "Right Now" view model (nil if AI not available)
    func makeAIGuideViewModel() -> AnyObject? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let orchestrator = AgentOrchestrator(playaDB: playaDB, locationProvider: locationProvider)
            guard orchestrator.isAvailable else { return nil }
            return RightNowViewModel(playaDB: playaDB, orchestrator: orchestrator)
        }
        #endif
        return nil
    }

    /// Create a NearbyViewModel with injected dependencies
    /// - Parameter locationOverride: transient "look from here" spot (the map's dropped
    ///   person marker). Nil — the default — leaves the screen sourcing from the device.
    ///   Never persisted; it only lives as long as the view model does.
    func makeNearbyViewModel(locationOverride: CLLocation? = nil) -> NearbyViewModel {
        NearbyViewModel(
            playaDB: playaDB,
            artProvider: artDataProvider,
            campProvider: campDataProvider,
            eventProvider: eventDataProvider,
            locationProvider: locationProvider,
            sourceLocationOverride: locationOverride
        )
    }

    /// Create a NearbyCardViewModel for the on-map nearby card overlay
    func makeNearbyCardViewModel() -> NearbyCardViewModel {
        NearbyCardViewModel(
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

// MARK: - Watch Sync Mapping

private extension FavoriteSyncObjectType {
    /// Maps a `FavoriteSyncItem.objectType` (a `DataObjectType` rawValue) to the
    /// legacy mirror's object kind. Returns nil for unknown types.
    init?(objectTypeRawValue: String) {
        guard let type = DataObjectType(rawValue: objectTypeRawValue) else { return nil }
        switch type {
        case .art: self = .art
        case .camp: self = .camp
        case .event: self = .event
        case .mutantVehicle: self = .mutantVehicle
        }
    }
}

// MARK: - Preview Support

/// Shared in-memory PlayaDB for SwiftUI previews. Preview data providers override
/// their observe methods with mock data, so this exists only to satisfy the
/// initializer without opening extra connections to the real on-disk database.
@MainActor
enum PreviewPlayaDB {
    static let shared: PlayaDB = {
        do {
            return try createInMemoryPlayaDB()
        } catch {
            fatalError("Failed to create in-memory preview PlayaDB: \(error)")
        }
    }()
}
