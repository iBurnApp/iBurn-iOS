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
    @Published var visitStatusFilter: Set<BRCVisitStatus>
    
    private let onFilterChanged: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init(onFilterChanged: (() -> Void)? = nil) {
        self.onFilterChanged = onFilterChanged
        // Initialize from UserSettings
        self.showExpiredEvents = UserSettings.showExpiredEventsInFavorites
        self.showTodayOnly = UserSettings.showTodayOnlyInFavorites
        self.visitStatusFilter = UserSettings.visitStatusFilterForLists
    }
    
    func saveSettings() {
        // Save to UserSettings
        UserSettings.showExpiredEventsInFavorites = showExpiredEvents
        UserSettings.showTodayOnlyInFavorites = showTodayOnly
        UserSettings.visitStatusFilterForLists = visitStatusFilter
        
        // Notify of changes
        onFilterChanged?()
    }
    
    func toggleVisitStatus(_ status: BRCVisitStatus) {
        if visitStatusFilter.contains(status) {
            visitStatusFilter.remove(status)
        } else {
            visitStatusFilter.insert(status)
        }
    }
    
    func isVisitStatusSelected(_ status: BRCVisitStatus) -> Bool {
        visitStatusFilter.contains(status)
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
                Toggle("Today's Events Only", isOn: $viewModel.showTodayOnly)
            } footer: {
                Group {
                    if viewModel.showTodayOnly {
                        if viewModel.showExpiredEvents {
                            Text("Showing all of today's favorited events")
                        } else {
                            Text("Showing today's favorited events (hiding expired)")
                        }
                    } else if viewModel.showExpiredEvents {
                        Text("Showing all favorited events including expired ones")
                    } else {
                        Text("Hiding expired events")
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            // TODO: Visit status filtering is temporarily disabled - needs proper implementation
            // Visit Status Section
            /*
            Section(header: Text("Visit Status"), footer: Text("Filter favorites by visit status")
                .font(.footnote)
                .foregroundColor(.secondary)) {
                ForEach(BRCVisitStatus.allCases, id: \.self) { status in
                    HStack {
                        Image(systemName: status.iconName)
                            .foregroundColor(status.color)
                        Text("Show \(status.displayString)")
                        Spacer()
                        if viewModel.isVisitStatusSelected(status) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleVisitStatus(status)
                    }
                }
            }
            */
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