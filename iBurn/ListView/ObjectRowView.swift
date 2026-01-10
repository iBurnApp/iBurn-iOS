//
//  ObjectRowView.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB
import CoreLocation

/// Generic row view for displaying data objects in list views
///
/// This component provides a consistent row layout while allowing customization
/// via the `actions` ViewBuilder for type-specific controls (audio button, etc.)
///
/// Usage:
/// ```swift
/// ObjectRowView(
///     object: artObject,
///     distance: "0.5 mi",
///     isFavorite: true,
///     onFavoriteTap: { ... }
/// ) {
///     // Type-specific actions
///     Button(action: { playAudio() }) {
///         Image(systemName: "play.circle.fill")
///     }
/// }
/// ```
struct ObjectRowView<Object: DisplayableObject, Actions: View>: View {
    let object: Object
    let distance: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    @ViewBuilder let actions: () -> Actions
    @Environment(\.themeColors) var themeColors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Main content
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(object.name)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)

                // Description (if available)
                if let description = object.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(2)
                }

                // Distance (if available)
                if let distance = distance {
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(themeColors.detailColor)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Type-specific actions (audio button, etc.)
                actions()

                // Favorite button
                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(isFavorite ? .pink : themeColors.detailColor)
                        .imageScale(.large)
                }
                .buttonStyle(.plain) // Prevent List row selection on tap
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

// Previews disabled - would require mock ArtObject instance
// #Preview("Art Object") {
//     List {
//         // Preview content here
//     }
// }
