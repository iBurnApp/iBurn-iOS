//
//  MediaObjectRowView.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import SwiftUI

/// Row wrapper that loads locally cached thumbnails (and optional image-derived theming)
/// without depending on YapDatabase objects.
struct MediaObjectRowView<Object: DisplayableObject, Actions: View>: View {
    let object: Object
    let subtitle: AttributedString?
    let rightSubtitle: String?
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    @ViewBuilder let actions: () -> Actions

    @StateObject private var assets: RowAssetsLoader

    init(
        object: Object,
        subtitle: AttributedString?,
        rightSubtitle: String?,
        isFavorite: Bool,
        onFavoriteTap: @escaping () -> Void,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.object = object
        self.subtitle = subtitle
        self.rightSubtitle = rightSubtitle
        self.isFavorite = isFavorite
        self.onFavoriteTap = onFavoriteTap
        self.actions = actions
        _assets = StateObject(wrappedValue: RowAssetsLoader(objectID: object.uid))
    }

    var body: some View {
        ObjectRowView(
            object: object,
            thumbnail: assets.thumbnail,
            colorsOverride: assets.colors,
            subtitle: subtitle,
            rightSubtitle: rightSubtitle,
            isFavorite: isFavorite,
            onFavoriteTap: onFavoriteTap,
            actions: actions
        )
        .onAppear { assets.startIfNeeded() }
    }
}

