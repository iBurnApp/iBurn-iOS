//
//  iBurnWatchApp.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import PlayaGeo
import SwiftUI
import PlayaDB

@main
struct IBurnWatchApp: App {
    private let playaDB: PlayaDB
    private let mapData: PlayaMapData?

    @StateObject private var locationService = LocationService()

    /// One pin observation shared by the map and the pins list.
    @StateObject private var pinStore: PinStore

    /// Kept in @State so the manager (and its WCSession delegate + database
    /// observations) survives re-runs of the root `.task`.
    @State private var syncManager: PeerSyncManager?

    init() {
        let db: PlayaDB
        do {
            db = try createPlayaDB()
        } catch {
            fatalError("PlayaDB init failed: \(error)")
        }
        playaDB = db
        mapData = try? PlayaMapData.load(from: .main)
        _pinStore = StateObject(wrappedValue: PinStore(playaDB: db))
    }

    var body: some Scene {
        WindowGroup {
            // NavigationStack root (not a paging TabView): the map owns the
            // Digital Crown for zoom and drags for panning, which would fight
            // vertical page switching.
            NavigationStack {
                if let mapData {
                    MapScreen(
                        mapData: mapData,
                        location: locationService,
                        pinStore: pinStore
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink {
                                BrowseScreen(
                                    playaDB: playaDB,
                                    mapData: mapData,
                                    location: locationService,
                                    pinStore: pinStore
                                )
                            } label: {
                                Image(systemName: "list.bullet")
                            }
                            .accessibilityLabel("Browse")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink {
                                FavoritesScreen(
                                    playaDB: playaDB,
                                    mapData: mapData,
                                    location: locationService
                                )
                            } label: {
                                Image(systemName: "heart.circle")
                            }
                            .accessibilityLabel("Favorites")
                        }
                    }
                } else {
                    Text("Map data unavailable")
                }
            }
            .task {
                await WatchSeeder.seedIfNeeded(playaDB)
                if syncManager == nil {
                    // Applied favorites came from the phone; let visible screens
                    // (e.g. FavoritesScreen) refresh themselves. Pins need no
                    // equivalent — PinStore is driven by a database observation
                    // that fires on its own.
                    let manager = PeerSyncManager(
                        playaDB: playaDB,
                        onFavoritesApplied: { _ in
                            NotificationCenter.default.post(name: .favoritesSyncDidApply, object: nil)
                        }
                    )
                    manager.start()
                    syncManager = manager
                }
            }
        }
    }
}

extension Notification.Name {
    /// Posted (from a background queue) after favorites synced from the paired
    /// phone have been applied to the local PlayaDB.
    static let favoritesSyncDidApply = Notification.Name("favoritesSyncDidApply")
}
