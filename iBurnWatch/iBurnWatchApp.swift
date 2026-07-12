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
    private let playaDB: PlayaDB = {
        do {
            return try createPlayaDB()
        } catch {
            fatalError("PlayaDB init failed: \(error)")
        }
    }()

    private let mapData: PlayaMapData? = try? PlayaMapData.load(from: .main)

    @StateObject private var locationService = LocationService()

    /// Kept in @State so the manager (and its WCSession delegate + database
    /// observation) survives re-runs of the root `.task`.
    @State private var syncManager: FavoritesSyncManager?

    var body: some Scene {
        WindowGroup {
            // NavigationStack root (not a paging TabView): the map owns the
            // Digital Crown for zoom and drags for panning, which would fight
            // vertical page switching.
            NavigationStack {
                if let mapData {
                    MapScreen(mapData: mapData, location: locationService)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                NavigationLink {
                                    BrowseScreen(
                                        playaDB: playaDB,
                                        mapData: mapData,
                                        location: locationService
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
                    let manager = FavoritesSyncManager(playaDB: playaDB) { _ in
                        // Applied favorites came from the phone; let visible
                        // screens (e.g. FavoritesScreen) refresh themselves.
                        NotificationCenter.default.post(name: .favoritesSyncDidApply, object: nil)
                    }
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
