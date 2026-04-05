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

    private let thumbnailSize: CGFloat = 100

    var body: some View {
        let colors = colorsOverride.map(ImageColors.init) ?? themeColors

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(object.name)
                        .font(.headline)
                        .foregroundColor(colors.primaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    actions()
                }

                HStack(alignment: .top, spacing: 8) {
                    thumbnailView
                        .frame(width: thumbnailSize, height: thumbnailSize)

                    Text(object.description ?? "")
                        .font(.subheadline)
                        .foregroundColor(colors.detailColor)
                        .lineLimit(nil)
                        .truncationMode(.tail)
                        .frame(height: thumbnailSize, alignment: .topLeading)
                }
                .padding(.top, 4)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    } else {
                        Text("🚶🏽 ? min   🚴🏽 ? min")
                            .font(.subheadline)
                            .foregroundColor(colors.secondaryColor)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 0)

                    if let rightSubtitle, !rightSubtitle.isEmpty {
                        Text(rightSubtitle)
                            .font(.subheadline)
                            .foregroundColor(colors.secondaryColor)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 8)
            }

            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .pink : colors.detailColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 0)
        .listRowBackground(listRowBackground)
    }

    private var listRowBackground: some View {
        ZStack {
            themeColors.backgroundColor
            if let override = colorsOverride {
                Color(override.backgroundColor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: colorsOverride != nil)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            shape.fill(Color.black.opacity(0.06))

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipped()
                    .transition(.opacity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black.opacity(0.25))
                    .frame(width: thumbnailSize, height: thumbnailSize)
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        .overlay(shape.stroke(Color.black.opacity(0.08), lineWidth: 1))
        .clipped()
        .animation(.easeInOut(duration: 0.22), value: thumbnail != nil)
    }
}

// MARK: - Preview

// Previews disabled - would require mock ArtObject instance
// #Preview("Art Object") {
//     List {
//         // Preview content here
//     }
// }
