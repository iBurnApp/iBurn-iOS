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
    
    var body: some View {
        List {
            // Add debug-only feature flags here as needed
            
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