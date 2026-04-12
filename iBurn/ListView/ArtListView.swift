//
//  ArtListView.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// SwiftUI view for displaying a list of art objects
///
/// Features:
/// - Searchable list with real-time filtering
/// - Filter button to configure display options (onlyWithEvents, onlyFavorites)
/// - Map button to view art on map
/// - Distance display from user location
/// - Favorite toggling per item
/// - Navigation to detail view
/// - Theme support
struct ArtListView: View {
    @StateObject private var viewModel: ArtListViewModel
    @State private var showingFilterSheet = false
    @Environment(\.themeColors) var themeColors
    private let audioPlayer: any AudioPlayerProtocol
    private let onSelect: (ArtObject) -> Void
    private let onShowMap: ([ArtObject]) -> Void

    init(
        viewModel: ArtListViewModel,
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance,
        onSelect: @escaping (ArtObject) -> Void = { _ in },
        onShowMap: @escaping ([ArtObject]) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.audioPlayer = audioPlayer
        self.onSelect = onSelect
        self.onShowMap = onShowMap
    }

    var body: some View {
        ZStack {
            // Main list content
            List {
                ForEach(viewModel.filteredItems, id: \.object.uid) { row in
                    ObjectRowView(
                        object: row.object,
                        subtitle: viewModel.distanceAttributedString(for: row.object),
                        rightSubtitle: row.object.artist,
                        isFavorite: row.isFavorite,
                        thumbnailColors: row.thumbnailColors,
                        onFavoriteTap: {
                            Task { await viewModel.toggleFavorite(row) }
                        }
                    ) { assets in
                        if let audioURL = assets.audioURL {
                            AudioTourButton(
                                track: BRCAudioTourTrack(
                                    uid: row.object.uid,
                                    title: row.object.name,
                                    artist: row.object.artist,
                                    audioURL: audioURL,
                                    artworkURL: BRCMediaDownloader.localMediaURL("\(row.object.uid).jpg")
                                ),
                                audioPlayer: audioPlayer
                            )
                        } else {
                            EmptyView()
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(row.object)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $viewModel.searchText,
                prompt: "Search art, artists, descriptions"
            )
            .navigationTitle("Art")
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
                ArtFilterSheet(filter: $viewModel.filter)
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading art...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 64))
                        .foregroundColor(themeColors.detailColor)

                    if viewModel.searchText.isEmpty {
                        Text("No art found")
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

    // MARK: - Helper Properties

    /// Icon name for filter button (filled when filters are active)
    private var filterIconName: String {
        if viewModel.filter.onlyWithEvents || viewModel.filter.onlyFavorites {
            return "line.3.horizontal.decrease.circle.fill"
        } else {
            return "line.3.horizontal.decrease.circle"
        }
    }

    // MARK: - Helper Methods

    /// Show the map view with current art items
    private func showMap() {
        onShowMap(viewModel.filteredItems.map(\.object))
    }

}


// MARK: - Preview

#Preview("Art List") {
    NavigationView {
        ArtListView(
            viewModel: ArtListViewModel(
                dataProvider: PreviewArtDataProvider(),
                locationProvider: MockLocationProvider(),
                filterStorageKey: "artListFilter.preview",
                initialFilter: .all,
                effectiveFilterForObservation: { $0 },
                favoritesFilterForObservation: { filter in
                    var f = filter
                    f.searchText = nil
                    f.onlyWithEvents = false
                    f.onlyFavorites = true
                    return f
                },
                matchesSearch: { art, q in
                    art.name.lowercased().contains(q) ||
                    art.description?.lowercased().contains(q) == true ||
                    art.artist?.lowercased().contains(q) == true
                }
            )
        )
    }
}

#Preview("Art List - With Filters") {
    NavigationView {
        ArtListView(
            viewModel: ArtListViewModel(
                dataProvider: PreviewArtDataProvider(),
                locationProvider: MockLocationProvider(),
                filterStorageKey: "artListFilter.preview",
                initialFilter: ArtFilter(onlyWithEvents: true),
                effectiveFilterForObservation: { $0 },
                favoritesFilterForObservation: { filter in
                    var f = filter
                    f.searchText = nil
                    f.onlyWithEvents = false
                    f.onlyFavorites = true
                    return f
                },
                matchesSearch: { art, q in
                    art.name.lowercased().contains(q) ||
                    art.description?.lowercased().contains(q) == true ||
                    art.artist?.lowercased().contains(q) == true
                }
            )
        )
    }
}

// MARK: - Preview Helpers

@MainActor
private class PreviewArtDataProvider: ArtDataProvider {
    init() {
        // This will fail in preview but that's okay
        super.init(playaDB: try! createPlayaDB())
    }

    override func observeObjects(filter: ArtFilter) -> AsyncStream<[ListRow<ArtObject>]> {
        AsyncStream { continuation in
            continuation.yield([
                Self.createMockArt(name: "Temple of Transition"),
                Self.createMockArt(name: "The Man"),
                Self.createMockArt(name: "Galaxy Portal")
            ].map { ListRow(object: $0, metadata: nil, thumbnailColors: nil) })
            continuation.finish()
        }
    }

    private nonisolated static func createMockArt(name: String) -> ArtObject {
        ArtObject(
            uid: UUID().uuidString,
            name: name,
            year: 2025,
            description: "A beautiful art installation",
            artist: "Unknown Artist",
            gpsLatitude: 40.7864,
            gpsLongitude: -119.2065
        )
    }
}

// Legacy favorites store is no longer used by SwiftUI lists.
