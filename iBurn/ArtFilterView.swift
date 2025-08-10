//
//  ArtFilterView.swift
//  iBurn
//
//  Created by Claude on 8/10/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI

class ArtFilterViewModel: ObservableObject {
    @Published var showOnlyArtWithEvents: Bool
    
    var onFilterChanged: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    init() {
        self.showOnlyArtWithEvents = UserSettings.showOnlyArtWithEvents
    }
    
    func saveSettings() {
        UserSettings.showOnlyArtWithEvents = showOnlyArtWithEvents
        onFilterChanged?()
    }
    
    func dismiss() {
        onDismiss?()
    }
}

struct ArtFilterView: View {
    @ObservedObject var viewModel: ArtFilterViewModel
    
    var body: some View {
        Form {
            Section {
                Toggle("Only show art with events", isOn: $viewModel.showOnlyArtWithEvents)
            } footer: {
                Text("When enabled, only art installations that host events will be shown in the list.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Filter Art")
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

// MARK: - UIKit Integration

class ArtFilterViewController: UIHostingController<ArtFilterView> {
    
    private let viewModel = ArtFilterViewModel()
    
    init(onFilterChanged: @escaping () -> Void) {
        super.init(rootView: ArtFilterView(viewModel: viewModel))
        viewModel.onFilterChanged = onFilterChanged
        viewModel.onDismiss = { [weak self] in
            self?.dismiss(animated: true)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}