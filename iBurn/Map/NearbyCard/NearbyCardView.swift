//
//  NearbyCardView.swift
//  iBurn
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The on-map "nearby card": a compact, swipeable card pinned near the bottom of
//  the main map showing what's within ~100m of the user. Events come first, then
//  art + camps by distance. Tapping a card opens its detail view; a minimize
//  button collapses the card into a badged FAB with a Liquid Glass morph (iOS 26),
//  falling back to a material card + matched-geometry morph on earlier OSes.
//

import SwiftUI
import PlayaDB

struct NearbyCardView: View {
    @ObservedObject var viewModel: NearbyCardViewModel
    let onSelect: (DetailSubject) -> Void

    private let audioPlayer: any AudioPlayerProtocol
    @Namespace private var glassNS
    @Environment(\.themeColors) private var themeColors

    private let glassID = "nearbyCard"
    private let cardCornerRadius: CGFloat = 22

    /// A stable, device-appropriate card width. Fixed (not content-driven) so the card
    /// doesn't jitter as you swipe between items with different text lengths, and capped
    /// to the screen so it never overflows on small devices. Combined with the hosting
    /// controller's intrinsic-content sizing, this keeps the touch area to just the card.
    private var cardWidth: CGFloat {
        min(380, UIScreen.main.bounds.width - 32)
    }

    init(
        viewModel: NearbyCardViewModel,
        onSelect: @escaping (DetailSubject) -> Void = { _ in },
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.audioPlayer = audioPlayer
    }

    var body: some View {
        glassContainer {
            Group {
                if viewModel.items.isEmpty {
                    // Collapses to zero intrinsic size so the host view doesn't block the map.
                    Color.clear.frame(width: 0, height: 0)
                } else if viewModel.isMinimized {
                    fab
                } else {
                    card
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: viewModel.isMinimized)
        .animation(.easeInOut(duration: 0.25), value: viewModel.items.isEmpty)
    }

    // MARK: - Expanded card

    private var card: some View {
        VStack(spacing: 6) {
            TabView(selection: $viewModel.selectedID) {
                ForEach(viewModel.items) { item in
                    NearbyCardContentView(
                        item: item,
                        now: viewModel.now,
                        isFavorite: item.isFavorite,
                        audioPlayer: audioPlayer,
                        onFavoriteTap: { Task { await viewModel.toggleFavorite(item) } },
                        onTap: { onSelect(item.detailSubject) }
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .tag(item.id as String?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 84)

            if viewModel.count > 1 {
                pageDots
                    .padding(.bottom, 8)
            }
        }
        .frame(width: cardWidth)
        .overlay(alignment: .topTrailing) { minimizeButton }
        .modifier(GlassSurface(namespace: glassNS, glassID: glassID, shape: .roundedRect(cardCornerRadius)))
    }

    private var minimizeButton: some View {
        Button {
            viewModel.isMinimized = true
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeColors.secondaryColor)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .accessibilityLabel("Minimize nearby card")
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.items) { item in
                Circle()
                    .fill(item.id == viewModel.selectedID
                          ? themeColors.primaryColor
                          : themeColors.detailColor.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Minimized FAB

    private var fab: some View {
        Button {
            viewModel.isMinimized = false
        } label: {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(themeColors.primaryColor)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { countBadge }
        .modifier(GlassSurface(namespace: glassNS, glassID: glassID, shape: .circle))
        .accessibilityLabel("Show \(viewModel.count) nearby")
    }

    private var countBadge: some View {
        Text("\(viewModel.count)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, 3)
            .background(Circle().fill(Color.red))
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .offset(x: 6, y: -4)
    }

    // MARK: - Glass container

    @ViewBuilder
    private func glassContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            GlassEffectContainer { content() }
        } else {
            content()
        }
        #else
        content()
        #endif
    }
}

// MARK: - Glass surface modifier

/// Applies the Liquid Glass surface on iOS 26 (with a shared `glassEffectID` so the
/// card<->FAB transition morphs), and a `.ultraThinMaterial` + `matchedGeometryEffect`
/// fallback on earlier OSes / SDKs.
private struct GlassSurface: ViewModifier {
    enum SurfaceShape {
        case roundedRect(CGFloat)
        case circle
    }

    let namespace: Namespace.ID
    let glassID: String
    let shape: SurfaceShape

    @ViewBuilder
    func body(content: Content) -> some View {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch shape {
            case .roundedRect(let radius):
                content
                    .glassEffect(.regular.interactive(),
                                 in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .glassEffectID(glassID, in: namespace)
            case .circle:
                content
                    .glassEffect(.regular.interactive(), in: Circle())
                    .glassEffectID(glassID, in: namespace)
            }
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    @ViewBuilder
    private func fallback(_ content: Content) -> some View {
        switch shape {
        case .roundedRect(let radius):
            let s = RoundedRectangle(cornerRadius: radius, style: .continuous)
            content
                .background(.ultraThinMaterial, in: s)
                .overlay(s.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .matchedGeometryEffect(id: glassID, in: namespace)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        case .circle:
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .matchedGeometryEffect(id: glassID, in: namespace)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Single card content

private struct NearbyCardContentView: View {
    let item: NearbyItem
    let now: Date
    let isFavorite: Bool
    let audioPlayer: any AudioPlayerProtocol
    let onFavoriteTap: () -> Void
    let onTap: () -> Void

    @StateObject private var assets: RowAssetsLoader
    @Environment(\.themeColors) private var themeColors

    init(
        item: NearbyItem,
        now: Date,
        isFavorite: Bool,
        audioPlayer: any AudioPlayerProtocol,
        onFavoriteTap: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.item = item
        self.now = now
        self.isFavorite = isFavorite
        self.audioPlayer = audioPlayer
        self.onFavoriteTap = onFavoriteTap
        self.onTap = onTap
        _assets = StateObject(wrappedValue: RowAssetsLoader(objectID: item.thumbnailObjectID))
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColors.primaryColor)
                    .lineLimit(1)

                if let description = item.detailDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(themeColors.secondaryColor)
                        .lineLimit(1)
                }

                if let timeText = item.eventTimeText(now: now) {
                    Text(timeText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(themeColors.detailColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            VStack(spacing: 10) {
                favoriteIcon
                if let track = audioTrack {
                    AudioTourButton(track: track, audioPlayer: audioPlayer)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            shape.fill(Color.black.opacity(0.06))
            if let image = assets.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.placeholderSymbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    /// Uses `Image + onTapGesture` (not `Button`) so it doesn't swallow the card tap.
    private var favoriteIcon: some View {
        Image(systemName: isFavorite ? "heart.fill" : "heart")
            .foregroundStyle(isFavorite ? Color.pink : themeColors.detailColor)
            .imageScale(.medium)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .onTapGesture { onFavoriteTap() }
    }

    /// Audio tours exist for art only, and only when the file is present on disk.
    private var audioTrack: BRCAudioTourTrack? {
        guard let art = item.artForAudio, let audioURL = assets.audioURL else { return nil }
        return BRCAudioTourTrack(
            uid: art.uid,
            title: art.name,
            artist: art.artist,
            audioURL: audioURL,
            artworkURL: BRCMediaDownloader.localMediaURL("\(art.uid).jpg")
        )
    }
}

// MARK: - NearbyItem display helpers

private extension NearbyItem {
    /// Object id used for thumbnail/audio lookup (events fall back to host camp/art).
    var thumbnailObjectID: String {
        switch self {
        case .art(let r): r.object.thumbnailObjectID
        case .camp(let r): r.object.thumbnailObjectID
        case .event(let r): r.object.thumbnailObjectID
        }
    }

    var detailDescription: String? {
        switch self {
        case .art(let r): r.object.description
        case .camp(let r): r.object.description
        case .event(let r): r.object.description
        }
    }

    /// Live event timing line (events only).
    func eventTimeText(now: Date) -> String? {
        if case .event(let r) = self { return r.object.timeDescription(now: now) }
        return nil
    }

    /// Underlying art object, for building an audio-tour track (art only).
    var artForAudio: ArtObject? {
        if case .art(let r) = self { return r.object }
        return nil
    }

    var placeholderSymbol: String {
        switch self {
        case .art: "photo"
        case .camp: "tent"
        case .event: "calendar"
        }
    }
}
