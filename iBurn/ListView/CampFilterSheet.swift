//
//  CampFilterSheet.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// Filter sheet for configuring camp list display options
struct CampFilterSheet: View {
    @Binding var filter: CampFilter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColors) var themeColors

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle("Only show favorites", isOn: $filter.onlyFavorites)
                } footer: {
                    Text("When enabled, only camps you've marked as favorite will be shown.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filter Camps")
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

#Preview("Camp Filter Sheet") {
    CampFilterSheet(filter: .constant(CampFilter()))
}
