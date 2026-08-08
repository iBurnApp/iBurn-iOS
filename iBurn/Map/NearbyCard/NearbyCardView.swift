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
    let onShowNearbyList: () -> Void

    private let audioPlayer: any AudioPlayerProtocol
    @Environment(\.themeColors) private var themeColors

    private let cardCornerRadius: CGFloat = 22

    /// A stable, device-appropriate card width. Fixed (not content-driven) so the card
    /// doesn't jitter as you swipe between items with different text lengths, and capped
    /// to the screen so it never overflows on small devices.
    private var cardWidth: CGFloat {
        min(380, UIScreen.main.bounds.width - 32)
    }

    private static let pageHeight: CGFloat = 86
    private static let footerHeight: CGFloat = 30
    /// Page plus footer. Fixed for the same reason the width is.
    private static let cardHeight: CGFloat = pageHeight + footerHeight
    /// Not private: `NearbyCardTouchContainer` needs it to size the collapsed touch area.
    static let fabDiameter: CGFloat = 56

    init(
        viewModel: NearbyCardViewModel,
        onSelect: @escaping (DetailSubject) -> Void = { _ in },
        onShowNearbyList: @escaping () -> Void = { },
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onShowNearbyList = onShowNearbyList
        self.audioPlayer = audioPlayer
    }

    private var isMinimized: Bool { viewModel.isMinimized }

    /// Radius that turns the card's rounded rect into the FAB's circle at 56pt.
    private var surfaceCornerRadius: CGFloat {
        isMinimized ? Self.fabDiameter / 2 : cardCornerRadius
    }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: surfaceCornerRadius, style: .continuous)
    }

    var body: some View {
        // Collapsing is one surface changing size, not two views swapping places.
        //
        // The swap is what broke the morph. Two things fought it: the hosting controller
        // resizes itself to the SwiftUI content, so collapsing snapped the host to 56pt in
        // a single Auto Layout pass; and a paged `TabView` is a UIKit page controller that
        // doesn't animate on its way out. Either alone is enough to cut the transition —
        // measured at 60fps, the old version went card to circle with no frames between.
        //
        // Now the card and the pin both stay in the hierarchy and cross-fade while the
        // shared surface interpolates its frame and corner radius. Nothing is inserted or
        // removed, so there's nothing for SwiftUI to skip.
        // The box stays card-sized whatever state the surface is in, so the collapse always
        // has room to animate. That leaves empty space around the collapsed pin, which the
        // map still needs to be draggable through — `NearbyCardTouchContainer` handles that
        // in UIKit rather than leaving it to hosting-view hit-testing behaviour.
        glassContainer {
            surface
                .frame(
                    width: viewModel.items.isEmpty ? 0 : cardWidth,
                    height: viewModel.items.isEmpty ? 0 : Self.cardHeight
                )
                .opacity(viewModel.items.isEmpty ? 0 : 1)
        }
    }

    private func setMinimized(_ minimized: Bool) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            viewModel.isMinimized = minimized
        }
    }

    // MARK: - Morphing surface

    private var surface: some View {
        ZStack {
            card
                .frame(width: cardWidth, height: Self.cardHeight)
                .opacity(isMinimized ? 0 : 1)
                // The card is still in the hierarchy when collapsed; without these its
                // buttons keep catching taps inside the pin and VoiceOver keeps offering
                // "Minimize nearby card" on a card that isn't on screen.
                .allowsHitTesting(!isMinimized)
                .accessibilityHidden(isMinimized)

            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(themeColors.primaryColor)
                .opacity(isMinimized ? 1 : 0)
        }
        .frame(
            width: isMinimized ? Self.fabDiameter : cardWidth,
            height: isMinimized ? Self.fabDiameter : Self.cardHeight
        )
        .clipShape(surfaceShape)
        .modifier(GlassSurface(cornerRadius: surfaceCornerRadius))
        .overlay(alignment: .topTrailing) {
            // Faded rather than removed so it animates with the surface; hidden from
            // VoiceOver too, or the expanded card announces a stray count.
            countBadge
                .opacity(isMinimized ? 1 : 0)
                .accessibilityHidden(!isMinimized)
        }
        .contentShape(surfaceShape)
        .onTapGesture {
            if isMinimized { setMinimized(false) }
        }
        .modifier(CollapsedAccessibility(isMinimized: isMinimized, count: viewModel.count))
    }

    // MARK: - Expanded card

    private var card: some View {
        VStack(spacing: 0) {
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
                    .padding(.top, 12)
                    .tag(item.id as String?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.pageHeight)

            footer
        }
    }

    /// Collapse on the left, "See all" on the right, page dots centered between them.
    /// The dots used to sit alone in a row of their own, which left the whole bottom of
    /// the card empty; putting the two controls on that line reclaims it and gets the
    /// collapse chevron out from where it floated over the item's title.
    private var footer: some View {
        ZStack {
            if viewModel.count > 1 {
                pageDots
            }
            HStack {
                minimizeButton
                Spacer(minLength: 0)
                seeAllButton
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Self.footerHeight)
    }

    private var seeAllButton: some View {
        Button(action: onShowNearbyList) {
            HStack(spacing: 2) {
                Text("See all")
                    .font(.caption2.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(themeColors.secondaryColor)
            .padding(.horizontal, 6)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See all nearby")
    }

    private var minimizeButton: some View {
        Button {
            setMinimized(true)
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(themeColors.secondaryColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(themeColors.detailColor.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
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

/// Applies the Liquid Glass surface on iOS 26, with a `.ultraThinMaterial` fallback on
/// earlier OSes / SDKs.
///
/// The radius is a parameter rather than a fixed shape because it animates: at 56pt a
/// 28pt radius is a circle, so card and pin are the same shape at different values and
/// SwiftUI can interpolate between them. There's no `glassEffectID` any more — that pairs
/// two *different* views, and this is one view changing size.
private struct GlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            fallback(content, shape: shape)
        }
        #else
        fallback(content, shape: shape)
        #endif
    }

    private func fallback(_ content: Content, shape: RoundedRectangle) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

/// Gives the collapsed pin a single button-shaped accessibility element. The expanded card
/// is left alone so its rows, favorite toggle and footer controls stay individually
/// reachable.
private struct CollapsedAccessibility: ViewModifier {
    let isMinimized: Bool
    let count: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if isMinimized {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Show \(count) nearby")
        } else {
            content
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

            // Name, then when (events only), then where. The blurb used to take the
            // second line, which is the least useful thing to know about something 100m
            // away — it only appears now if there's nothing concrete to show.
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColors.primaryColor)
                    .lineLimit(1)

                if let timeText = item.eventTimeText(now: now) {
                    Text(timeText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(themeColors.secondaryColor)
                        .lineLimit(1)
                }

                if let address = item.address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(themeColors.detailColor)
                        .lineLimit(1)
                } else if let description = item.detailDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
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
