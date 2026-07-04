//
//  iBurnWatchApp.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

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

    var body: some Scene {
        WindowGroup {
            ContentView(playaDB: playaDB)
        }
    }
}
