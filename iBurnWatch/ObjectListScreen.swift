//
//  ObjectListScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import PlayaDB
import PlayaGeo
import SwiftUI

/// Generic alphabetical browse list for camps, art, and mutant vehicles.
/// Loads once via the injected fetcher and filters by name in memory —
/// these lists top out around a thousand rows and `List` renders lazily.
struct ObjectListScreen: View {
    let title: String
    let loader: () async throws -> [any DataObject]
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    @State private var objects: [any DataObject] = []
    @State private var loaded = false
    @State private var loadError: Error?
    @State private var searchText = ""

    private var rows: [ObjectRow] {
        let userLocation = location.location
        let filtered = searchText.isEmpty
            ? objects
            : objects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return filtered.map { object in
            ObjectRow(
                object: object,
                distance: userLocation.flatMap { user in object.location?.distance(from: user) }
            )
        }
    }

    var body: some View {
        Group {
            if loaded, let loadError {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Couldn't load \(title.lowercased())")
                        .font(.footnote)
                    Text(loadError.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if !loaded {
                ProgressView()
            } else {
                List(rows) { row in
                    NavigationLink {
                        DetailScreen(
                            object: row.object,
                            playaDB: playaDB,
                            mapData: mapData,
                            location: location
                        )
                    } label: {
                        HStack {
                            Text(row.object.objectType.emoji)
                            VStack(alignment: .leading) {
                                Text(row.object.name)
                                    .font(.footnote)
                                    .lineLimit(2)
                                if let distance = row.distance {
                                    Text(formatDistance(distance))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle(title)
        .task {
            await load()
        }
    }

    private func load() async {
        guard !loaded else { return }
        do {
            objects = try await loader().sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            loadError = nil
        } catch {
            loadError = error
        }
        loaded = true
    }
}
