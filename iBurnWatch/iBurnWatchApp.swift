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
                                    NearbyScreen(
                                        playaDB: playaDB,
                                        mapData: mapData,
                                        location: locationService
                                    )
                                } label: {
                                    Image(systemName: "location.circle")
                                }
                                .accessibilityLabel("Nearby")
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
            }
        }
    }
}
