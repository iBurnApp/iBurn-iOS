//
//  ContentView.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaAPI
import PlayaDB
import iBurn2026APIData

/// Phase 0 smoke screen: seeds PlayaDB from the bundled APIData on first launch
/// and shows object counts, proving GRDB + the data pipeline run standalone on watch.
struct ContentView: View {
    let playaDB: PlayaDB
    @State private var status = "Loading…"
    @State private var isSeeding = false

    var body: some View {
        VStack(spacing: 8) {
            Text("iBurn")
                .font(.headline)
            if isSeeding {
                ProgressView()
            }
            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let updateInfo = try await playaDB.getUpdateInfo()
            if updateInfo.isEmpty {
                isSeeding = true
                status = "Seeding database…"
                let seed = try await Self.loadSeedData()
                try await playaDB.importFromData(
                    artData: seed.art,
                    campData: seed.camps,
                    eventData: seed.events,
                    mvData: seed.mv
                )
                isSeeding = false
            }
            let artCount = try await playaDB.fetchArt().count
            let campCount = try await playaDB.fetchCamps().count
            status = "\(artCount) art\n\(campCount) camps"
        } catch {
            isSeeding = false
            status = "Error: \(error.localizedDescription)"
        }
    }

    private struct SeedData {
        let art: Data
        let camps: Data
        let events: Data
        let mv: Data?
    }

    private static func loadSeedData() async throws -> SeedData {
        let bundle = iBurn2026APIData.bundle
        return SeedData(
            art: try BundleDataLoader.loadArt(from: bundle),
            camps: try BundleDataLoader.loadCamps(from: bundle),
            events: try BundleDataLoader.loadEvents(from: bundle),
            mv: try? BundleDataLoader.loadMutantVehicles(from: bundle)
        )
    }
}

#Preview("Empty DB") {
    if let playaDB = try? createInMemoryPlayaDB() {
        ContentView(playaDB: playaDB)
    } else {
        Text("Preview DB unavailable")
    }
}
