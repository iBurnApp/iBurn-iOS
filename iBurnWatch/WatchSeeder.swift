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
            let bundle = iBurn2026APIData.bundle

            // Seed when the DB is empty OR when the bundled data is newer than what
            // was previously imported (e.g. app update shipping a new year's data).
            let updateData = try? BundleDataLoader.loadUpdateInfo(from: bundle)
            if let updateData {
                guard try await playaDB.needsImport(bundleUpdateData: updateData) else { return }
            } else {
                guard try await playaDB.getUpdateInfo().isEmpty else { return }
            }

            try await playaDB.importFromData(
                artData: try BundleDataLoader.loadArt(from: bundle),
                campData: try BundleDataLoader.loadCamps(from: bundle),
                eventData: try BundleDataLoader.loadEvents(from: bundle),
                mvData: try? BundleDataLoader.loadMutantVehicles(from: bundle),
                updateData: updateData
            )
        } catch {
            print("Watch seed failed: \(error)")
        }
    }
}
