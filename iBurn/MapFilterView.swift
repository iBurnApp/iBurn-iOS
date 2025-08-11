//
//  MapFilterView.swift
//  iBurn
//
//  Created by Claude on 2025-08-10.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

// MARK: - Models

struct MapEventTypeContainer: Identifiable {
    let id = UUID()
    let type: BRCEventType
    let title: String
    var isSelected: Bool
}

// MARK: - View Model

class MapFilterViewModel: ObservableObject {
    @Published var showArt: Bool
    @Published var showCamps: Bool
    @Published var showActiveEvents: Bool
    @Published var showFavorites: Bool
    @Published var showTodaysFavoritesOnly: Bool
    @Published var eventTypes: [MapEventTypeContainer]
    
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
        
        // Initialize event types
        let storedTypes = UserSettings.selectedEventTypesForMap
        self.eventTypes = BRCEventObject.allVisibleEventTypes.compactMap { number -> MapEventTypeContainer? in
            guard let type = BRCEventType(rawValue: number.uintValue) else { return nil }
            return MapEventTypeContainer(
                type: type,
                title: BRCEventObject.stringForEventType(type),
                isSelected: storedTypes.contains(type)
            )
        }
    }
    
    func selectAllEventTypes() {
        eventTypes.indices.forEach { eventTypes[$0].isSelected = true }
    }
    
    func selectNoneEventTypes() {
        eventTypes.indices.forEach { eventTypes[$0].isSelected = false }
    }
    
    func saveSettings() {
        // Save to UserSettings
        UserSettings.showArtOnMap = showArt
        UserSettings.showCampsOnMap = showCamps
        UserSettings.showActiveEventsOnMap = showActiveEvents
        UserSettings.showFavoritesOnMap = showFavorites
        UserSettings.showTodaysFavoritesOnlyOnMap = showTodaysFavoritesOnly
        
        // Save selected event types
        let selectedTypes = eventTypes
            .filter { $0.isSelected }
            .map { $0.type }
        UserSettings.selectedEventTypesForMap = selectedTypes
        
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
                Toggle("Events", isOn: $viewModel.showActiveEvents)
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
            
            // Event Types Section - only show when events are enabled
            if viewModel.showActiveEvents {
                Section {
                    Button("Select All") {
                        viewModel.selectAllEventTypes()
                    }
                    Button("Select None") {
                        viewModel.selectNoneEventTypes()
                    }
                }
                
                Section(header: Text("Event Types")) {
                    ForEach($viewModel.eventTypes) { $type in
                        Toggle(type.title, isOn: $type.isSelected)
                            .foregroundColor(Color(BRCImageColors.colors(for: type.type).secondaryColor))
                    }
                }
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