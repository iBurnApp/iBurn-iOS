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
    @State private var mode: ListMode = .favorites
    @State private var typeFilter: TypeFilter = .all
    @State private var showingFilters = false

    /// Which list to show: favorites, or objects by visit status.
    private enum ListMode: String, CaseIterable, Identifiable {
        case favorites
        case wantToVisit
        case visited

        var id: Self { self }

        var title: String {
            switch self {
            case .favorites: return "Favorites"
            case .wantToVisit: return "Want to Visit"
            case .visited: return "Visited"
            }
        }

        var emptyIcon: String {
            switch self {
            case .favorites: return "heart"
            case .wantToVisit: return "star"
            case .visited: return "checkmark.circle"
            }
        }

        var emptyText: String {
            switch self {
            case .favorites: return "No favorites yet"
            case .wantToVisit: return "Nothing on your list yet"
            case .visited: return "Nothing visited yet"
            }
        }
    }

    /// In-memory filter on `DataObjectType`.
    private enum TypeFilter: String, CaseIterable, Identifiable {
        case all
        case camps
        case art
        case events
        case vehicles

        var id: Self { self }

        var title: String {
            switch self {
            case .all: return "All"
            case .camps: return "Camps"
            case .art: return "Art"
            case .events: return "Events"
            case .vehicles: return "Vehicles"
            }
        }

        var objectType: DataObjectType? {
            switch self {
            case .all: return nil
            case .camps: return .camp
            case .art: return .art
            case .events: return .event
            case .vehicles: return .mutantVehicle
            }
        }
    }

    /// `.task(id:)` key so a reload runs when the token, mode, or type changes.
    private struct RefreshKey: Equatable {
        var token: Int
        var mode: ListMode
        var typeFilter: TypeFilter
    }

    private var isFiltering: Bool {
        mode != .favorites || typeFilter != .all
    }

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
                    Image(systemName: mode.emptyIcon)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(mode.emptyText)
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
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFilters = true
                } label: {
                    Image(
                        systemName: isFiltering
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }
        }
        // Menu is unavailable on watchOS, so filters live in a sheet.
        .sheet(isPresented: $showingFilters) {
            List {
                Picker("Show", selection: $mode) {
                    ForEach(ListMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("Type", selection: $typeFilter) {
                    ForEach(TypeFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            }
            .pickerStyle(.inline)
        }
        .task(id: RefreshKey(token: refreshToken, mode: mode, typeFilter: typeFilter)) {
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
        .onReceive(
            NotificationCenter.default.publisher(for: .embargoDidUnlock)
                .receive(on: DispatchQueue.main)
        ) { _ in
            // Rows here are built once per refresh, not per location fix, so an
            // unlock landing mid-screen needs an explicit re-sort with distances.
            refreshToken += 1
        }
    }

    private func refresh() async {
        do {
            let objects: [any DataObject]
            switch mode {
            case .favorites:
                objects = try await playaDB.getFavorites()
            case .wantToVisit:
                objects = try await playaDB.fetchObjects(visitStatus: .wantToVisit)
            case .visited:
                objects = try await playaDB.fetchObjects(visitStatus: .visited)
            }
            let filtered: [any DataObject]
            if let objectType = typeFilter.objectType {
                filtered = objects.filter { $0.objectType == objectType }
            } else {
                filtered = objects
            }
            let userLocation = location.location
            rows = filtered
                .map { object in
                    ObjectRow(
                        object: object,
                        distance: WatchEmbargo.distance(for: object, from: userLocation)
                    )
                }
                // Distance first where it is allowed to exist, name otherwise —
                // while a tier is embargoed every distance is nil, so the list
                // is alphabetical rather than secretly ordered by proximity.
                .sorted { lhs, rhs in
                    let left = lhs.distance ?? .infinity
                    let right = rhs.distance ?? .infinity
                    if left != right { return left < right }
                    return lhs.object.name.localizedCaseInsensitiveCompare(rhs.object.name) == .orderedAscending
                }
            loadError = nil
            loaded = true
        } catch {
            loadError = error
            loaded = true
            rows = []
        }
    }
}
