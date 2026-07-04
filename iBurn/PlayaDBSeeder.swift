//
//  PlayaDBSeeder.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaAPI
import PlayaDB

@MainActor
final class PlayaDBSeeder {
    private let playaDB: PlayaDB
    private let dataBundle: Bundle
    private var didStart = false

    init(playaDB: PlayaDB, dataBundle: Bundle = .brc_dataBundle) {
        self.playaDB = playaDB
        self.dataBundle = dataBundle
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
                print("PlayaDB seed failed: \(error)")
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
