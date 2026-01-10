//
//  ArtFilterSheet.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// Filter sheet for configuring art list display options
///
/// Allows users to toggle:
/// - Only show art with events
/// - Only show favorites
struct ArtFilterSheet: View {
    @Binding var filter: ArtFilter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColors) var themeColors

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Only show art with events", isOn: $filter.onlyWithEvents)
                } footer: {
                    Text("When enabled, only art installations that host events will be shown in the list.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Toggle("Only show favorites", isOn: $filter.onlyFavorites)
                } footer: {
                    Text("When enabled, only art installations you've marked as favorite will be shown.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filter Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Art Filter Sheet") {
    ArtFilterSheet(filter: .constant(ArtFilter()))
}

#Preview("Art Filter Sheet - With Filters Active") {
    ArtFilterSheet(filter: .constant(ArtFilter(onlyWithEvents: true, onlyFavorites: true)))
}
