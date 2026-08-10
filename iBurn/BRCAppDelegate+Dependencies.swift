//
//  BRCAppDelegate+Dependencies.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import CoreLocation
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
        let preferenceService = PreferenceServiceFactory.shared
        if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
            return FavoritesListHostingController(dependencies: dependencies)
        }

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

    /// Creates the nearby view controller, using SwiftUI when the feature flag is enabled.
    /// Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createNearbyViewController() -> UIViewController {
        createNearbyViewController(locationOverride: nil)
    }

    /// Same screen, optionally measured from somewhere other than the device.
    ///
    /// `locationOverride` carries the map's dropped person marker through to the list. It is
    /// a Swift-only overload because the no-argument spelling above is what `BRCAppDelegate.m`
    /// calls for tab-bar setup, and a default argument would rename the ObjC selector.
    ///
    /// Legacy caveat: the UIKit `NearbyViewController` (feature flag `useSwiftUILists` off)
    /// ignores the override. Its location source is wired through its own persisted
    /// time-shift configuration, and the override must not be persisted, so honoring it
    /// there is a rewrite rather than a parameter — out of scope while the SwiftUI list is
    /// the shipping path.
    @MainActor
    func createNearbyViewController(locationOverride: CLLocation?) -> UIViewController {
        let preferenceService = PreferenceServiceFactory.shared
        if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
            return NearbyListHostingController(
                dependencies: dependencies,
                locationOverride: locationOverride
            )
        }

        let nearbyVC = NearbyViewController(
            style: .grouped,
            extensionName: BRCDatabaseManager.shared.rTreeIndex
        )
        nearbyVC.title = "Nearby"
        return nearbyVC
    }

    /// Creates the events view controller, using SwiftUI when the feature flag is enabled.
    /// Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createEventsViewController() -> UIViewController {
        let preferenceService = PreferenceServiceFactory.shared
        if preferenceService.getValue(Preferences.FeatureFlags.useSwiftUILists) {
            return EventListHostingController(dependencies: dependencies)
        }

        let dbManager = BRCDatabaseManager.shared
        let legacyVC = EventListViewController(
            viewName: dbManager.eventsFilteredByDayExpirationAndTypeViewName,
            searchViewName: dbManager.searchEventsView
        )
        legacyVC.title = "Events"
        return legacyVC
    }
}
