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

    init(viewModel: ArtListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Main list content
            List {
                ForEach(viewModel.filteredItems, id: \.uid) { art in
                    NavigationLink(destination: detailView(for: art)) {
                        ObjectRowView(
                            object: art,
                            distance: viewModel.distanceString(for: art),
                            isFavorite: false, // TODO: Fetch metadata to determine favorite status
                            onFavoriteTap: {
                                Task { await viewModel.toggleFavorite(art) }
                            }
                        ) {
                            // TODO: Add audio button when audio data is migrated to PlayaDB
                            EmptyView()
                        }
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

    /// Navigate to detail view for an art object
    /// - Parameter art: The art object to show
    /// - Returns: Detail view
    private func detailView(for art: ArtObject) -> some View {
        // TODO: Integrate with existing DetailView
        // For now, return a placeholder
        Text("Detail for \(art.name)")
            .navigationTitle(art.name)
    }

    /// Show the map view with current art items
    private func showMap() {
        // TODO: Navigate to map view with art items
        // This will need to integrate with existing MapListViewController
        // For now, this is a placeholder
        print("Show map with \(viewModel.filteredItems.count) art items")
    }

}


// MARK: - Preview

#Preview("Art List") {
    NavigationView {
        ArtListView(
            viewModel: ArtListViewModel(
                dataProvider: PreviewArtDataProvider(),
                locationProvider: MockLocationProvider(),
                initialFilter: .all
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
                initialFilter: ArtFilter(onlyWithEvents: true)
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

    override func observeObjects(filter: ArtFilter) -> AsyncStream<[ArtObject]> {
        AsyncStream { continuation in
            // Provide mock data for preview
            continuation.yield([
                Self.createMockArt(name: "Temple of Transition"),
                Self.createMockArt(name: "The Man"),
                Self.createMockArt(name: "Galaxy Portal")
            ])
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
