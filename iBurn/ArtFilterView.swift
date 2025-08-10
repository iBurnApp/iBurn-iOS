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
    
    init() {
        self.showOnlyArtWithEvents = UserSettings.showOnlyArtWithEvents
    }
    
    func saveSettings() {
        UserSettings.showOnlyArtWithEvents = showOnlyArtWithEvents
        onFilterChanged?()
    }
}

struct ArtFilterView: View {
    @ObservedObject var viewModel: ArtFilterViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Only show art with events", isOn: $viewModel.showOnlyArtWithEvents)
                        .onChange(of: viewModel.showOnlyArtWithEvents) { _ in
                            viewModel.saveSettings()
                        }
                } footer: {
                    Text("When enabled, only art installations that host events will be shown in the list.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filter Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}