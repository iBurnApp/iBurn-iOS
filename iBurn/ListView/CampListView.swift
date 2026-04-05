//
//  CampListView.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// SwiftUI view for displaying a list of camp objects
struct CampListView: View {
    @StateObject private var viewModel: CampListViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors
    private let onSelect: (CampObject) -> Void
    private let onShowMap: ([CampObject]) -> Void

    init(
        viewModel: CampListViewModel,
        onSelect: @escaping (CampObject) -> Void = { _ in },
        onShowMap: @escaping ([CampObject]) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelect = onSelect
        self.onShowMap = onShowMap
    }

    var body: some View {
        ZStack {
            List {
                ForEach(viewModel.filteredItems, id: \.uid) { camp in
                    MediaObjectRowView(
                        object: camp,
                        subtitle: viewModel.distanceAttributedString(for: camp),
                        rightSubtitle: rightSubtitle(for: camp),
                        isFavorite: viewModel.isFavorite(camp),
                        onFavoriteTap: {
                            Task { await viewModel.toggleFavorite(camp) }
                        }
                    ) { _ in
                        EmptyView()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(camp)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search camps, descriptions, hometowns"
            )
            .navigationTitle("Camps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilterSheet = true }) {
                        Image(systemName: filterIconName)
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: showMap) {
                        Image(systemName: "map")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                CampFilterSheet(filter: $viewModel.filter)
            }

            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading camps...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            if !viewModel.isLoading && viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tent")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No camps found")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try adjusting your filters")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    } else {
                        Text("No results for \"\(viewModel.searchText)\"")
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)

                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(themeColors.secondaryColor)
                    }
                }
            }
        }
    }

    private var filterIconName: String {
        viewModel.filter.onlyFavorites
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    private func showMap() {
        onShowMap(viewModel.filteredItems)
    }

    private func rightSubtitle(for camp: CampObject) -> String? {
        if BRCEmbargo.allowEmbargoedData() {
            return camp.locationString ?? camp.intersection ?? "Location Unknown"
        }
        return "Location Restricted"
    }
}

#Preview("Camp List") {
    NavigationView {
        CampListView(
            viewModel: CampListViewModel(
                dataProvider: PreviewCampDataProvider(),
                locationProvider: MockLocationProvider(),
                filterStorageKey: "campListFilter.preview",
                initialFilter: .all,
                effectiveFilterForObservation: { $0 },
                favoritesFilterForObservation: { filter in
                    var f = filter
                    f.searchText = nil
                    f.onlyFavorites = true
                    return f
                },
                matchesSearch: { camp, q in
                    camp.name.lowercased().contains(q) ||
                    camp.description?.lowercased().contains(q) == true ||
                    camp.hometown?.lowercased().contains(q) == true ||
                    camp.landmark?.lowercased().contains(q) == true ||
                    camp.locationString?.lowercased().contains(q) == true
                }
            )
        )
    }
}

@MainActor
private class PreviewCampDataProvider: CampDataProvider {
    init() {
        super.init(playaDB: try! createPlayaDB())
    }

    override func observeObjects(filter: CampFilter) -> AsyncStream<[CampObject]> {
        AsyncStream { continuation in
            continuation.yield([
                Self.createMockCamp(name: "Solaris Camp"),
                Self.createMockCamp(name: "Dusty Mermaid"),
                Self.createMockCamp(name: "Roaming Oasis")
            ])
            continuation.finish()
        }
    }

    private nonisolated static func createMockCamp(name: String) -> CampObject {
        CampObject(
            uid: UUID().uuidString,
            name: name,
            year: 2025,
            description: "A welcoming theme camp",
            landmark: "Near Center Camp",
            locationString: "6:00 & Esplanade",
            gpsLatitude: 40.7864,
            gpsLongitude: -119.2065
        )
    }
}

// Legacy favorites store is no longer used by SwiftUI lists.
