//
//  FavoritesScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Combine
import CoreLocation
import PlayaDB
import PlayaGeo
import SwiftUI

struct FavoritesScreen: View {
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService

    @State private var rows: [ObjectRow] = []
    @State private var loaded = false
    @State private var loadError: Error?
    @State private var refreshToken = 0

    var body: some View {
        Group {
            if loaded, let loadError {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Couldn't load favorites")
                        .font(.footnote)
                    Text(loadError.localizedDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if loaded && rows.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "heart")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No favorites yet")
                        .font(.footnote)
                }
            } else {
                List(rows) { row in
                    NavigationLink {
                        DetailScreen(
                            object: row.object,
                            playaDB: playaDB,
                            mapData: mapData,
                            location: location,
                            onFavoriteChange: { refreshToken += 1 }
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
            }
        }
        .navigationTitle("Favorites")
        .task(id: refreshToken) {
            await refresh()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .favoritesSyncDidApply)
                .receive(on: DispatchQueue.main)
        ) { _ in
            // Favorites synced from the phone were applied; re-query so they
            // appear while this screen is open.
            refreshToken += 1
        }
    }

    private func refresh() async {
        do {
            let favorites = try await playaDB.getFavorites()
            let userLocation = location.location
            rows = favorites
                .map { object in
                    ObjectRow(
                        object: object,
                        distance: userLocation.flatMap { user in object.location?.distance(from: user) }
                    )
                }
                .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
            loadError = nil
            loaded = true
        } catch {
            loadError = error
            loaded = true
            rows = []
        }
    }
}
