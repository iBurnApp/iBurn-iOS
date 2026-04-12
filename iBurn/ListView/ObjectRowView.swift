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

/// Universal row view for displaying any data object in list views.
///
/// Handles thumbnail + color loading via `RowAssetsLoader`, using the object's
/// `thumbnailObjectID` property (defaults to `uid`, overridden for events to use host camp/art).
///
/// Usage:
/// ```swift
/// ObjectRowView(
///     object: artObject,
///     subtitle: distance,
///     rightSubtitle: artObject.artist,
///     isFavorite: true,
///     onFavoriteTap: { ... }
/// ) { assets in
///     AudioTourButton(...)
/// }
/// ```
struct ObjectRowView<Object: DisplayableObject, Actions: View>: View {
    let object: Object
    let subtitle: AttributedString?
    let rightSubtitle: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    @ViewBuilder let actions: (RowAssetsLoader) -> Actions
    @StateObject private var assets: RowAssetsLoader
    @Environment(\.themeColors) var themeColors

    private let thumbnailSize: CGFloat = 100

    init(
        object: Object,
        subtitle: AttributedString? = nil,
        rightSubtitle: String? = nil,
        isFavorite: Bool,
        onFavoriteTap: @escaping () -> Void,
        @ViewBuilder actions: @escaping (RowAssetsLoader) -> Actions = { _ in EmptyView() }
    ) {
        self.object = object
        self.subtitle = subtitle
        self.rightSubtitle = rightSubtitle
        self.isFavorite = isFavorite
        self.onFavoriteTap = onFavoriteTap
        self.actions = actions
        _assets = StateObject(wrappedValue: RowAssetsLoader(
            objectID: object.thumbnailObjectID
        ))
    }

    var body: some View {
        let colors = assets.colors.map(ImageColors.init) ?? themeColors

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(object.name)
                        .font(.headline)
                        .foregroundColor(colors.primaryColor)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    actions(assets)
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
        .onAppear { assets.startIfNeeded() }
    }

    private var listRowBackground: some View {
        ZStack {
            themeColors.backgroundColor
            if let override = assets.colors {
                Color(override.backgroundColor)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: assets.colors != nil)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            shape.fill(Color.black.opacity(0.06))

            if let thumbnail = assets.thumbnail {
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
        .animation(.easeInOut(duration: 0.22), value: assets.thumbnail != nil)
    }
}
