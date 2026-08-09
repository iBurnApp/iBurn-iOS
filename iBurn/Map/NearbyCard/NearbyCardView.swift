//
//  NearbyCardView.swift
//  iBurn
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  The on-map "nearby card": a compact, swipeable card pinned near the top of the
//  main map showing what's within ~100m of the user. Events come first, then art +
//  camps by distance. Tapping a card opens its detail view; the footer's "Hide"
//  button turns the card off until it is re-enabled from the map filter screen.
//  Liquid Glass on iOS 26, `.ultraThinMaterial` on earlier OSes.
//

import SwiftUI
import PlayaDB

struct NearbyCardView: View {
    @ObservedObject var viewModel: NearbyCardViewModel
    let onSelect: (DetailSubject) -> Void
    let onShowNearbyList: () -> Void
    let onHide: () -> Void

    private let audioPlayer: any AudioPlayerProtocol
    @Environment(\.themeColors) private var themeColors

    private let cardCornerRadius: CGFloat = 22

    /// A stable, device-appropriate card width. Fixed (not content-driven) so the card
    /// doesn't jitter as you swipe between items with different text lengths, and capped
    /// to the screen so it never overflows on small devices.
    private var cardWidth: CGFloat {
        min(380, UIScreen.main.bounds.width - 32)
    }

    /// Sized for the tallest row we can produce: an event with a name, a time line and a
    /// two-line address — 20 + 3 + 16 + 3 + 32 = 74pt of text under the row's 12pt top
    /// inset. 100 leaves that its bottom breathing room instead of clipping into the footer.
    private static let pageHeight: CGFloat = 100
    private static let footerHeight: CGFloat = 30
    /// Page plus footer. Fixed for the same reason the width is.
    private static let cardHeight: CGFloat = pageHeight + footerHeight

    init(
        viewModel: NearbyCardViewModel,
        onSelect: @escaping (DetailSubject) -> Void = { _ in },
        onShowNearbyList: @escaping () -> Void = { },
        onHide: @escaping () -> Void = { },
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance
    ) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onShowNearbyList = onShowNearbyList
        self.onHide = onHide
        self.audioPlayer = audioPlayer
    }

    /// Nothing nearby, or the card is switched off — either way the view model has
    /// emptied `items` and the card collapses to nothing.
    private var isHidden: Bool { viewModel.items.isEmpty }

    private var surfaceShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
    }

    /// The item the pager is currently showing. The favorite button lives outside the
    /// `TabView` (so it can't eat a swipe), so it has to look up the paged item itself.
    private var selectedItem: NearbyItem? {
        guard let selectedID = viewModel.selectedID else { return viewModel.items.first }
        return viewModel.items.first { $0.id == selectedID } ?? viewModel.items.first
    }

    var body: some View {
        // The card is removed from the hierarchy rather than collapsed to a zero frame:
        // a `.glassEffect` surface that is merely sized to zero and faded to `opacity(0)`
        // keeps compositing its last glass render, which left an empty card ghost stuck
        // over the map (and drew on top of the "card hidden" tooltip). Removing the view
        // is the only thing that reliably takes the glass off screen.
        //
        // The hosting controller sizes itself to this content, so an absent card is what
        // takes it off the map. `NearbyCardTouchContainer` still gates touches, so an
        // in-flight fade never steals a drag from the map.
        Group {
            if isHidden {
                Color.clear.frame(width: 0, height: 0)
            } else {
                glassContainer { surface }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isHidden)
    }

    // MARK: - Surface

    private var surface: some View {
        card
            .frame(width: cardWidth, height: Self.cardHeight)
            .clipShape(surfaceShape)
            .modifier(GlassSurface(cornerRadius: cardCornerRadius))
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.selectedID) {
                ForEach(viewModel.items) { item in
                    NearbyCardContentView(
                        item: item,
                        now: viewModel.now,
                        audioPlayer: audioPlayer,
                        onTap: { onSelect(item.detailSubject) }
                    )
                    .padding(.leading, 14)
                    // Wider on the trailing edge so the row's text and audio button clear
                    // the favorite button sitting in the corner above them.
                    .padding(.trailing, 34)
                    .padding(.top, 12)
                    // The row now fills the page, so it needs its own gap above the footer.
                    .padding(.bottom, 6)
                    .tag(item.id as String?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.pageHeight)

            footer
        }
        // Outside the `TabView` so it stays put while pages swipe under it — a control
        // inside the pager competes with the page gesture and can't be dragged past.
        .overlay(alignment: .topTrailing) { favoriteButton }
    }

    /// "Hide" leading, page dots centered, "See all" trailing. The dots used to sit alone
    /// in a row of their own, which left the whole bottom of the card empty.
    private var footer: some View {
        ZStack {
            if viewModel.count > 1 {
                pageDots
            }
            HStack {
                hideButton
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

    /// Turns the card off. Replaces the corner "✕": a labelled control in the footer reads
    /// as an action with a consequence, where a close glyph reads as "dismiss for now".
    private var hideButton: some View {
        Button(action: onHide) {
            Text("Hide")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(themeColors.secondaryColor)
                .padding(.horizontal, 6)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hide nearby card")
        .accessibilityHint("Turn it back on in Map Filter")
    }

    /// Favoriting the item the pager is showing. Sits in the card's corner rather than in
    /// the row so it keeps a fixed position while pages swipe underneath it.
    @ViewBuilder
    private var favoriteButton: some View {
        if let item = selectedItem {
            let isFavorite = item.isFavorite
            Button {
                Task { await viewModel.toggleFavorite(item) }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isFavorite ? Color.pink : themeColors.secondaryColor)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(themeColors.detailColor.opacity(0.15)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 6)
            .accessibilityLabel(isFavorite ? "Unfavorite \(item.name)" : "Favorite \(item.name)")
        }
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
/// earlier OSes / SDKs. Both branches have to stay behind the `canImport` check as well
/// as the availability check: the fallback is what compiles against pre-26 SDKs.
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

// MARK: - Single card content

private struct NearbyCardContentView: View {
    let item: NearbyItem
    let now: Date
    let audioPlayer: any AudioPlayerProtocol
    let onTap: () -> Void

    @StateObject private var assets: RowAssetsLoader
    @Environment(\.themeColors) private var themeColors

    init(
        item: NearbyItem,
        now: Date,
        audioPlayer: any AudioPlayerProtocol,
        onTap: @escaping () -> Void
    ) {
        self.item = item
        self.now = now
        self.audioPlayer = audioPlayer
        self.onTap = onTap
        _assets = StateObject(wrappedValue: RowAssetsLoader(objectID: item.thumbnailObjectID))
    }

    var body: some View {
        // Top-aligned: the name reads as the row's heading, level with the thumbnail's top
        // edge, and the row grows downwards as the address wraps instead of drifting.
        HStack(alignment: .top, spacing: 12) {
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

                // `NearbyItem.address` is nil while the object's embargo tier still hides
                // its location (art until gates open, camps until the ToS window, events
                // per their host), so this line simply doesn't render then.
                if let address = item.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(themeColors.detailColor)
                        .lineLimit(2)
                } else if let description = item.detailDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(themeColors.detailColor)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            // Art-only, and only when the audio file is on disk. Held at the bottom of the
            // page against the stack's `.top` alignment, so it clears the favorite button
            // in the card's corner above it.
            if let track = audioTrack {
                AudioTourButton(track: track, audioPlayer: audioPlayer)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        // Fills the page and anchors to its top so every row's name starts at the same
        // height — without this, rows shorter than the page would center themselves and
        // the title would jump as you swipe.
        .frame(maxHeight: .infinity, alignment: .top)
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
