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

    /// Wakes are how a watch app learns the clock moved; the camp tier unlocks
    /// on the date alone, so each `.active` re-checks the embargo.
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Restore the pre-populated database before it's opened, so a fresh install
        // opens the seeded file instead of an empty one. No-op for existing installs
        // or when the build ships without a seed, in which case the JSON import path
        // (WatchSeeder.seedIfNeeded, in the root .task) takes over.
        WatchSeeder.restoreBundledSeedIfNeeded()

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
                        },
                        onEmbargoUnlocked: {
                            // The phone has the passcode entered; latch it so the
                            // watch stops embargoing camp/art locations too.
                            WatchEmbargo.setUnlockedFromPhone()
                        }
                    )
                    manager.start()
                    syncManager = manager
                }
            }
            .onChange(of: scenePhase) { _, phase in
                // A tier can now open on the calendar alone, so a watch that was
                // asleep across the unlock instant has to notice on wake. Posts
                // only on a real locked -> unlocked transition.
                guard phase == .active else { return }
                WatchEmbargo.refreshUnlockState()
            }
        }
    }
}

extension Notification.Name {
    /// Posted (from a background queue) after favorites synced from the paired
    /// phone have been applied to the local PlayaDB.
    static let favoritesSyncDidApply = Notification.Name("favoritesSyncDidApply")

    /// Posted when an embargo latch flips — the phone's passcode unlock, or this
    /// watch's first fix inside the Burning Man region. Surfaces whose rows
    /// aren't already recomputed on every location fix listen so they stop
    /// hiding distances while they're on screen.
    static let embargoDidUnlock = Notification.Name("embargoDidUnlock")
}
