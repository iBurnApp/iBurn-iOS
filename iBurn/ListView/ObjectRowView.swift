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
    let subtitle: AttributedString?
    let rightSubtitle: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    @ViewBuilder let actions: () -> Actions
    @Environment(\.themeColors) var themeColors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(object.name)
                        .font(.headline)
                        .foregroundColor(themeColors.primaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    actions()
                }

                if let description = object.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(3)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(themeColors.detailColor)
                    } else {
                        Text("🚶🏽 ? min   🚴🏽 ? min")
                            .font(.subheadline)
                            .foregroundColor(themeColors.detailColor)
                    }

                    Spacer(minLength: 0)

                    if let rightSubtitle, !rightSubtitle.isEmpty {
                        Text(rightSubtitle)
                            .font(.subheadline)
                            .foregroundColor(themeColors.detailColor)
                            .lineLimit(1)
                    }
                }
            }

            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .pink : themeColors.detailColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

// Previews disabled - would require mock ArtObject instance
// #Preview("Art Object") {
//     List {
//         // Preview content here
//     }
// }
