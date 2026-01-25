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
import UIKit

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
    let thumbnail: UIImage?
    let colorsOverride: BRCImageColors?
    let subtitle: AttributedString?
    let rightSubtitle: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    @ViewBuilder let actions: () -> Actions
    @Environment(\.themeColors) var themeColors

    var body: some View {
        let colors = colorsOverride.map(ImageColors.init) ?? themeColors

        HStack(alignment: .top, spacing: 12) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(object.name)
                        .font(.headline)
                        .foregroundColor(colors.primaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    actions()
                }

                if let description = object.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(colors.secondaryColor)
                        .lineLimit(3)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(colors.detailColor)
                    } else {
                        Text("🚶🏽 ? min   🚴🏽 ? min")
                            .font(.subheadline)
                            .foregroundColor(colors.detailColor)
                    }

                    Spacer(minLength: 0)

                    if let rightSubtitle, !rightSubtitle.isEmpty {
                        Text(rightSubtitle)
                            .font(.subheadline)
                            .foregroundColor(colors.detailColor)
                            .lineLimit(1)
                    }
                }
            }

            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .pink : colors.detailColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .listRowBackground(colors.backgroundColor)
    }
}

// MARK: - Preview

// Previews disabled - would require mock ArtObject instance
// #Preview("Art Object") {
//     List {
//         // Preview content here
//     }
// }
