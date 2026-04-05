//
//  BRCAppDelegate+Dependencies.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

extension BRCAppDelegate {
    /// Lazy-loaded dependency container
    /// Created once on first access and reused throughout the app lifecycle
    private static var _dependencies: DependencyContainer?

    @MainActor
    var dependencies: DependencyContainer {
        get {
            if let existing = BRCAppDelegate._dependencies {
                return existing
            }

            do {
                let container = try DependencyContainer()
                BRCAppDelegate._dependencies = container
                return container
            } catch {
                fatalError("Failed to initialize DependencyContainer: \(error)")
            }
        }
    }

    /// Creates the favorites view controller, using SwiftUI when the feature flag is enabled.
    /// Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createFavoritesViewController() -> UIViewController {
        #if DEBUG
        let preferenceService = PreferenceServiceFactory.shared
        if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
            return FavoritesListHostingController(dependencies: dependencies)
        }
        #endif

        let dbManager = BRCDatabaseManager.shared
        let showExpiredEvents = UserSettings.showExpiredEventsInFavorites
        let favoritesViewName = showExpiredEvents
            ? dbManager.everythingFilteredByFavorite
            : dbManager.everythingFilteredByFavoriteAndExpiration
        let legacyVC = FavoritesViewController(
            viewName: favoritesViewName,
            searchViewName: dbManager.searchFavoritesView
        )
        legacyVC.title = "Favorites"
        return legacyVC
    }

    /// Creates the events view controller, using SwiftUI when the feature flag is enabled.
    /// Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createEventsViewController() -> UIViewController {
        #if DEBUG
        let preferenceService = PreferenceServiceFactory.shared
        if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
            return EventListHostingController(dependencies: dependencies)
        }
        #endif

        let dbManager = BRCDatabaseManager.shared
        let legacyVC = EventListViewController(
            viewName: dbManager.eventsFilteredByDayExpirationAndTypeViewName,
            searchViewName: dbManager.searchEventsView
        )
        legacyVC.title = "Events"
        return legacyVC
    }
}
