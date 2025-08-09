//
//  FavoritesFilterView.swift
//  iBurn
//
//  Created by Claude on 2025-08-09.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

// MARK: - View Model

class FavoritesFilterViewModel: ObservableObject {
    @Published var showExpiredEvents: Bool
    @Published var showTodayOnly: Bool
    
    private let onFilterChanged: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        // Initialize from UserSettings
        self.showExpiredEvents = UserSettings.showExpiredEventsInFavorites
        self.showTodayOnly = UserSettings.showTodayOnlyInFavorites
    }
    
    func saveSettings() {
        // Save to UserSettings
        UserSettings.showExpiredEventsInFavorites = showExpiredEvents
        UserSettings.showTodayOnlyInFavorites = showTodayOnly
        
        // Notify of changes
        onFilterChanged?()
    }
    
    func dismiss() {
        onDismiss?()
    }
}

// MARK: - SwiftUI View

struct FavoritesFilterView: View {
    @ObservedObject var viewModel: FavoritesFilterViewModel
    
    var body: some View {
        Form {
            // Filter Section
            Section {
                Toggle("Show Expired Events", isOn: $viewModel.showExpiredEvents)
                    .disabled(viewModel.showTodayOnly)
                Toggle("Today's Events Only", isOn: $viewModel.showTodayOnly)
            } footer: {
                Text("Filter your favorites to show only today's events or hide expired events")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Filter")
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

class FavoritesFilterViewController: UIHostingController<FavoritesFilterView> {
    private let viewModel: FavoritesFilterViewModel
    private let onFilterChanged: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        self.viewModel = FavoritesFilterViewModel(
            onFilterChanged: onFilterChanged
        )
        super.init(rootView: FavoritesFilterView(viewModel: viewModel))
        viewModel.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}