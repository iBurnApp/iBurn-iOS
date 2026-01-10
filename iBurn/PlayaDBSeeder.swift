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
                let updateInfo = try await playaDB.getUpdateInfo()
                guard updateInfo.isEmpty else { return }

                let (artData, campData, eventData) = try await Self.loadSeedData(from: dataBundle)

                try await playaDB.importFromData(
                    artData: artData,
                    campData: campData,
                    eventData: eventData
                )
            } catch {
                print("PlayaDB seed failed: \(error)")
            }
        }
    }

    private static func loadSeedData(from bundle: Bundle) async throws -> (Data, Data, Data) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let artData = try BundleDataLoader.loadArt(from: bundle)
                    let campData = try BundleDataLoader.loadCamps(from: bundle)
                    let eventData = try BundleDataLoader.loadEvents(from: bundle)
                    continuation.resume(returning: (artData, campData, eventData))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
