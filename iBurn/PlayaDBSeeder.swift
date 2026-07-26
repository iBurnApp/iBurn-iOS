//
//  PlayaDBSeeder.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CocoaLumberjack
import PlayaAPI
import PlayaDB
import Zip

@MainActor
final class PlayaDBSeeder {
    private let playaDB: PlayaDB
    private let dataBundle: Bundle
    private var didStart = false

    init(playaDB: PlayaDB, dataBundle: Bundle = .brc_dataBundle) {
        self.playaDB = playaDB
        self.dataBundle = dataBundle
    }

    // MARK: - Bundled Seed Restore

    /// Documents-directory URL where PlayaDB lives, matching PlayaDBImpl's on-disk
    /// path resolution. Used as the default restore destination.
    nonisolated static var defaultDocumentsURL: URL {
        PlayaDBSeedRestore.defaultDocumentsURL
    }

    /// Restores a pre-populated PlayaDB from a bundled seed zip, when one ships with
    /// this build and no database exists yet. Runs synchronously before the first
    /// `PlayaDB.create()` so the app opens the seeded file instead of an empty one.
    ///
    /// The restore itself lives in `PlayaDBSeedRestore` so the watch app performs it
    /// identically; this wrapper supplies the unzip implementation and app logging.
    /// A missing or unusable seed falls through to the JSON import path
    /// (`seedIfNeeded`), which also re-imports when the bundled JSON is newer than
    /// what the seed contains.
    ///
    /// - Parameters:
    ///   - documentsURL: Destination directory for `PlayaDB.sqlite` (default: app Documents).
    ///   - seedZipURL: Explicit seed zip to restore. When nil, resolves the
    ///     year-stamped resource `PlayaDB-<year>.zip` from `bundle`.
    ///   - bundle: Bundle searched for the seed when `seedZipURL` is nil.
    nonisolated static func restoreBundledSeedIfNeeded(
        documentsURL: URL = PlayaDBSeeder.defaultDocumentsURL,
        seedZipURL: URL? = nil,
        bundle: Bundle = .main
    ) {
        // Resolve the seed zip: an explicit URL (tests) or the year-stamped bundle
        // resource. A missing seed is expected — it's a gitignored local artifact.
        let zipURL = seedZipURL
            ?? bundle.url(forResource: "PlayaDB-\(YearSettings.playaYear)", withExtension: "zip")

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsURL,
            seedZipURL: zipURL
        ) { archive, destination in
            try Zip.unzipFile(archive, destination: destination, overwrite: true, password: nil)
        }

        switch outcome {
        case .restored:
            DDLogInfo("PlayaDB seed restored from \(zipURL?.lastPathComponent ?? "seed")")
        case .failed(let reason):
            DDLogError("PlayaDB seed restore failed: \(reason)")
        case .skippedDatabaseExists, .skippedNoSeed:
            break
        }
    }

    func seedIfNeeded() {
        guard !didStart else { return }
        didStart = true

        Task { [playaDB, dataBundle] in
            do {
                // Seed when the DB is empty OR when the bundled data is newer than what
                // was previously imported (e.g. app update shipping a new year's data).
                let updateData = try? BundleDataLoader.loadUpdateInfo(from: dataBundle)
                if let updateData {
                    guard try await playaDB.needsImport(bundleUpdateData: updateData) else { return }
                } else {
                    guard try await playaDB.getUpdateInfo().isEmpty else { return }
                }

                let seedData = try await Self.loadSeedData(from: dataBundle)

                try await playaDB.importFromData(
                    artData: seedData.artData,
                    campData: seedData.campData,
                    eventData: seedData.eventData,
                    mvData: seedData.mvData,
                    updateData: updateData
                )
            } catch {
                DDLogError("PlayaDB seed failed: \(error)")
            }
        }
    }

    private struct SeedData {
        let artData: Data
        let campData: Data
        let eventData: Data
        let mvData: Data?
    }

    private static func loadSeedData(from bundle: Bundle) async throws -> SeedData {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let artData = try BundleDataLoader.loadArt(from: bundle)
                    let campData = try BundleDataLoader.loadCamps(from: bundle)
                    let eventData = try BundleDataLoader.loadEvents(from: bundle)
                    let mvData = try? BundleDataLoader.loadMutantVehicles(from: bundle)
                    continuation.resume(returning: SeedData(
                        artData: artData,
                        campData: campData,
                        eventData: eventData,
                        mvData: mvData
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
