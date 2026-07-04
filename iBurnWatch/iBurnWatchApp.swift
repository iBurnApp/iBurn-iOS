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
            TabView {
                if let mapData {
                    MapScreen(mapData: mapData, location: locationService)
                }
                ContentView(playaDB: playaDB)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
