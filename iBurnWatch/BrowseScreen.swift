//
//  BrowseScreen.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/12/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import PlayaDB
import PlayaGeo
import SwiftUI

/// Top-level browse menu: nearby results plus full lists of every data type.
struct BrowseScreen: View {
    let playaDB: PlayaDB
    let mapData: PlayaMapData
    @ObservedObject var location: LocationService
    @ObservedObject var pinStore: PinStore

    var body: some View {
        List {
            NavigationLink {
                NearbyScreen(
                    playaDB: playaDB,
                    mapData: mapData,
                    location: location
                )
            } label: {
                row(emoji: "📍", title: "Nearby")
            }
            NavigationLink {
                PinsScreen(
                    mapData: mapData,
                    pinStore: pinStore,
                    location: location
                )
            } label: {
                row(emoji: "📌", title: "Pins")
            }
            NavigationLink {
                ObjectListScreen(
                    title: "Camps",
                    loader: { try await playaDB.fetchCamps() },
                    playaDB: playaDB,
                    mapData: mapData,
                    location: location
                )
            } label: {
                row(emoji: "🏕️", title: "Camps")
            }
            NavigationLink {
                ObjectListScreen(
                    title: "Art",
                    loader: { try await playaDB.fetchArt() },
                    playaDB: playaDB,
                    mapData: mapData,
                    location: location
                )
            } label: {
                row(emoji: "🎨", title: "Art")
            }
            NavigationLink {
                ObjectListScreen(
                    title: "Vehicles",
                    loader: { try await playaDB.fetchMutantVehicles() },
                    playaDB: playaDB,
                    mapData: mapData,
                    location: location
                )
            } label: {
                row(emoji: "🚌", title: "Vehicles")
            }
            NavigationLink {
                EventListScreen(
                    playaDB: playaDB,
                    mapData: mapData,
                    location: location
                )
            } label: {
                row(emoji: "🎪", title: "Events")
            }
        }
        .navigationTitle("Browse")
    }

    private func row(emoji: String, title: String) -> some View {
        HStack {
            Text(emoji)
            Text(title)
                .font(.footnote)
        }
    }
}
