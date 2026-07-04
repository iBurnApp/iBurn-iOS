//
//  WatchSeeder.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaAPI
import PlayaDB
import iBurn2026APIData

/// Seeds PlayaDB from the bundled APIData on first launch (watch counterpart
/// of the iOS PlayaDBSeeder — the watch has no network update path yet).
enum WatchSeeder {
    static func seedIfNeeded(_ playaDB: PlayaDB) async {
        do {
            let updateInfo = try await playaDB.getUpdateInfo()
            guard updateInfo.isEmpty else { return }

            let bundle = iBurn2026APIData.bundle
            try await playaDB.importFromData(
                artData: try BundleDataLoader.loadArt(from: bundle),
                campData: try BundleDataLoader.loadCamps(from: bundle),
                eventData: try BundleDataLoader.loadEvents(from: bundle),
                mvData: try? BundleDataLoader.loadMutantVehicles(from: bundle)
            )
        } catch {
            print("Watch seed failed: \(error)")
        }
    }
}
