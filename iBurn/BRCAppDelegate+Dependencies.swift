//
//  BRCAppDelegate+Dependencies.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import CocoaLumberjack
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

    // MARK: - Data Updates

    /// Kicks off the launch-time over-the-air data update check (PlayaDB-native;
    /// replaces `BRCDataImporter.loadUpdatesFromURL:`). Fire-and-forget — the
    /// service throttles itself to once a day and honors the "Automatic Updates"
    /// preference, and lists refresh through GRDB observations when data lands.
    ///
    /// Must be called on the main thread; `BRCAppDelegate.m` dispatches to it.
    @MainActor @objc
    func checkForDataUpdates() {
        let service = dependencies.dataUpdateService
        Task { @MainActor in
            do {
                let outcome = try await service.checkForUpdates(force: false)
                DDLogInfo("Data update check finished: \(outcome)")
            } catch {
                DDLogError("Data update check failed: \(error)")
            }
        }
    }

    /// Same check, for the BGAppRefreshTask handler. `completion` reports whether
    /// new data was actually imported.
    @MainActor @objc
    func checkForDataUpdates(completion: @escaping (Bool) -> Void) {
        let service = dependencies.dataUpdateService
        Task { @MainActor in
            do {
                let outcome = try await service.checkForUpdates(force: false)
                DDLogInfo("Background data update finished: \(outcome)")
                if case .updated = outcome {
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                DDLogError("Background data update failed: \(error)")
                completion(false)
            }
        }
    }

    /// Creates the favorites view controller. Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createFavoritesViewController() -> UIViewController {
        FavoritesListHostingController(dependencies: dependencies)
    }

    /// Creates the nearby view controller. Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createNearbyViewController() -> UIViewController {
        createNearbyViewController(locationOverride: nil)
    }

    /// Same screen, optionally measured from somewhere other than the device.
    ///
    /// `locationOverride` carries the map's dropped person marker through to the list. It is
    /// a Swift-only overload because the no-argument spelling above is what `BRCAppDelegate.m`
    /// calls for tab-bar setup, and a default argument would rename the ObjC selector.
    @MainActor
    func createNearbyViewController(locationOverride: CLLocation?) -> UIViewController {
        NearbyListHostingController(
            dependencies: dependencies,
            locationOverride: locationOverride
        )
    }

    /// Creates the events view controller. Callable from ObjC for tab bar setup.
    @MainActor @objc
    func createEventsViewController() -> UIViewController {
        EventListHostingController(dependencies: dependencies)
    }
}
