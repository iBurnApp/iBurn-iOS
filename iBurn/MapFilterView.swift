//
//  MapFilterView.swift
//  iBurn
//
//  Created by Claude on 2025-08-10.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

// MARK: - View Model

class MapFilterViewModel: ObservableObject {
    @Published var showArt: Bool
    @Published var showCamps: Bool
    @Published var showActiveEvents: Bool
    @Published var showFavorites: Bool
    @Published var showTodaysFavoritesOnly: Bool
    
    private let onFilterChanged: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        // Initialize from UserSettings
        self.showArt = UserSettings.showArtOnMap
        self.showCamps = UserSettings.showCampsOnMap
        self.showActiveEvents = UserSettings.showActiveEventsOnMap
        self.showFavorites = UserSettings.showFavoritesOnMap
        self.showTodaysFavoritesOnly = UserSettings.showTodaysFavoritesOnlyOnMap
    }
    
    func saveSettings() {
        // Save to UserSettings
        UserSettings.showArtOnMap = showArt
        UserSettings.showCampsOnMap = showCamps
        UserSettings.showActiveEventsOnMap = showActiveEvents
        UserSettings.showFavoritesOnMap = showFavorites
        UserSettings.showTodaysFavoritesOnlyOnMap = showTodaysFavoritesOnly
        
        // Notify of changes
        onFilterChanged?()
    }
    
    func dismiss() {
        onDismiss?()
    }
}

// MARK: - SwiftUI View

struct MapFilterView: View {
    @ObservedObject var viewModel: MapFilterViewModel
    
    var body: some View {
        Form {
            // Data Types Section
            Section(header: Text("Show on Map")) {
                Toggle("Art", isOn: $viewModel.showArt)
                Toggle("Camps", isOn: $viewModel.showCamps)
                Toggle("Active Events", isOn: $viewModel.showActiveEvents)
            }
            
            // Favorites Section
            Section(header: Text("Favorites"), footer:
                Group {
                    if viewModel.showFavorites {
                        if viewModel.showTodaysFavoritesOnly {
                            Text("Showing only today's favorited events on the map")
                        } else {
                            Text("Showing all favorited items on the map")
                        }
                    } else {
                        Text("Favorites are hidden from the map")
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            ) {
                Toggle("Show Favorites", isOn: $viewModel.showFavorites)
                Toggle("Today's Favorites Only", isOn: $viewModel.showTodaysFavoritesOnly)
                    .disabled(!viewModel.showFavorites)
            }
        }
        .navigationTitle("Map Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    viewModel.saveSettings()
                    viewModel.dismiss()
                }
            }
        }
    }
}

// MARK: - UIKit Wrapper

class MapFilterViewController: UIHostingController<MapFilterView> {
    private let viewModel: MapFilterViewModel
    private let onFilterChanged: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        self.viewModel = MapFilterViewModel(
            onFilterChanged: onFilterChanged
        )
        super.init(rootView: MapFilterView(viewModel: viewModel))
        viewModel.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}