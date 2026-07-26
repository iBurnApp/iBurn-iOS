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
import Zip
import iBurn2026APIData

/// Gets PlayaDB populated on the watch (counterpart of the iOS `PlayaDBSeeder` —
/// the watch has no network update path yet).
///
/// Two stages, same as the phone:
///
/// 1. `restoreBundledSeedIfNeeded()` — synchronous, must run *before* the database is
///    opened. Unpacks the pre-built seed so a fresh install skips the JSON import
///    entirely. Parsing ~3.4 MB of JSON is slow on watch hardware, which is exactly
///    what this avoids.
/// 2. `seedIfNeeded(_:)` — asynchronous, after the database is open. Imports the
///    bundled JSON when there's no seed to restore, and re-imports when the bundled
///    JSON is *newer* than what the seed contains (an app update shipping refreshed
///    data on top of an older baked database).
enum WatchSeeder {

    /// Restores the pre-populated database shipped in the watch bundle.
    ///
    /// Seeds are gitignored build artifacts (`swift run --package-path Packages/PlayaSeed
    /// playa-seed`), so a build made without one simply has no seed to restore and falls
    /// through to `seedIfNeeded`.
    static func restoreBundledSeedIfNeeded(
        documentsURL: URL = PlayaDBSeedRestore.defaultDocumentsURL,
        seedZipURL: URL? = nil,
        bundle: Bundle = .main
    ) {
        let zipURL = seedZipURL
            ?? bundle.url(forResource: "PlayaDB-\(iBurn2026APIData.year)", withExtension: "zip")

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsURL,
            seedZipURL: zipURL
        ) { archive, destination in
            try Zip.unzipFile(archive, destination: destination, overwrite: true, password: nil)
        }

        switch outcome {
        case .restored:
            print("Watch PlayaDB seed restored from \(zipURL?.lastPathComponent ?? "seed")")
        case .failed(let reason):
            print("Watch PlayaDB seed restore failed: \(reason)")
        case .skippedDatabaseExists, .skippedNoSeed:
            break
        }
    }

    static func seedIfNeeded(_ playaDB: PlayaDB) async {
        do {
            let bundle = iBurn2026APIData.bundle

            // Seed when the DB is empty OR when the bundled data is newer than what
            // was previously imported (e.g. app update shipping a new year's data,
            // or JSON refreshed after the bundled seed was baked).
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
