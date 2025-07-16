//
//  FeatureFlagsView.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

#if DEBUG

import SwiftUI

/// Debug view for toggling feature flags at runtime
struct FeatureFlagsView: View {
    @PreferenceProperty(Preferences.FeatureFlags.useSwiftUIDetailView) 
    private var useSwiftUIDetail
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $useSwiftUIDetail) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Use SwiftUI Detail View")
                            .font(.body)
                        if let description = Preferences.FeatureFlags.useSwiftUIDetailView.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } header: {
                Text("Detail View")
            } footer: {
                Text("SwiftUI implementation provides modern UI with improved animations and interactions")
                    .font(.caption)
            }
            
            // Add more feature flag sections here as needed
            
            Section {
                Text("Feature flags are only available in DEBUG builds and control experimental features during development.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Feature Flags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

struct FeatureFlagsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FeatureFlagsView()
        }
    }
}

#endif