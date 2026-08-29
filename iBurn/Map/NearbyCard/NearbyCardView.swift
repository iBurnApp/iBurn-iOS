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

    /// The one inset every edge uses: the thumbnail's leading and top edge, and the
    /// favorite button's top and trailing edge. Sharing a single number is what keeps the
    /// heart from looking like it hugs the corner tighter than the row does.
    private static let contentInset: CGFloat = 10

    /// The row's text can't clear the favorite button, so it stops short of it: the heart
    /// is 24pt wide at `contentInset` from the trailing edge, plus 4pt of breathing room.
    private static let rowTrailingInset: CGFloat = contentInset + 24 + 4

    /// Gap between the bottom of the tallest row and the footer. Small but non-zero so a
    /// descender on the last line never touches the footer's controls.
    private static let rowFooterGap: CGFloat = 2

    /// The thumbnail's edge, and the floor under every row: no text stack the card allows is
    /// taller than this at default Dynamic Type, so this is what actually sets the height.
    private static let thumbnailSize: CGFloat = 60

    /// The tallest text stack a row can produce at default Dynamic Type: name (20) +
    /// accessory (16) + description (16), plus the `VStack`'s two 2pt gaps — 56. The
    /// accessory-less shape is shorter (20 + 2 + 32 = 54), which is why the description gets
    /// its second line back exactly when the accessory line isn't there.
    private static let baseTextStackHeight: CGFloat = 56

    /// The height the text stack is allowed to grow to before the card stops following
    /// Dynamic Type: its size at `extraExtraExtraLarge`, the largest non-accessibility
    /// setting. Accessibility sizes then overlap the footer instead of turning the card into
    /// a panel that covers the map — the same tradeoff the previously fixed height made,
    /// just moved four steps further up the scale.
    private static let maximumTextStackHeight: CGFloat = UIFontMetrics(forTextStyle: .subheadline)
        .scaledValue(for: baseTextStackHeight,
                     compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge))

    /// `baseTextStackHeight` at the reader's type size. Declared as a `@ScaledMetric` rather
    /// than measured so the page height is still a constant per size class — a
    /// content-measured page would resize as you swipe between rows.
    @ScaledMetric(relativeTo: .subheadline) private var textStackHeight = baseTextStackHeight

    /// The thumbnail governs the row until the text outgrows it, which at default Dynamic
    /// Type it never does — that's the dead space this height used to carry.
    private var rowHeight: CGFloat {
        max(Self.thumbnailSize, min(textStackHeight, Self.maximumTextStackHeight))
    }

    /// The row, under the card's `contentInset` top inset and above `rowFooterGap`.
    /// 10 + 60 + 2 = 72 at default Dynamic Type.
    private var pageHeight: CGFloat { Self.contentInset + rowHeight + Self.rowFooterGap }
    /// Exactly the height of the footer's 28pt controls — the dots and labels are small
    /// enough that any more than that is empty card.
    static let footerHeight: CGFloat = 28

    // MARK: - Dropped-pin header

    /// The header line's own height at default Dynamic Type — one line of `caption2`.
    static let baseHeaderLineHeight: CGFloat = 18

    /// Space above the header line. Smaller than `contentInset` because the row below
    /// already carries that inset, and two full insets stacked read as a gap.
    static let headerTopInset: CGFloat = 6

    /// Same cap the row's text stack uses, for the same reason: past `extraExtraExtraLarge`
    /// the card would start covering the map instead of floating over it.
    private static let maximumHeaderLineHeight: CGFloat = UIFontMetrics(forTextStyle: .caption2)
        .scaledValue(for: baseHeaderLineHeight,
                     compatibleWith: UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge))

    @ScaledMetric(relativeTo: .caption2) private var headerLineHeight = baseHeaderLineHeight

    /// What the header costs the card when it is present: the line plus its top inset.
    private var headerHeight: CGFloat {
        min(headerLineHeight, Self.maximumHeaderLineHeight) + Self.headerTopInset
    }

    /// Only while the person is standing somewhere — the card has no header when it is
    /// sourcing from the device, which is the overwhelmingly common case.
    private var headerLine: String? { viewModel.headerText }

    /// Page plus footer: 100 at default Dynamic Type, plus the header when a dropped pin is
    /// driving the card (24 more at default Dynamic Type). Fixed per type size for the same
    /// reason the width is fixed. Pure arithmetic, exposed for unit testing.
    static func cardHeight(pageHeight: CGFloat, headerHeight: CGFloat?) -> CGFloat {
        pageHeight + footerHeight + (headerHeight ?? 0)
    }

    private var cardHeight: CGFloat {
        Self.cardHeight(pageHeight: pageHeight, headerHeight: headerLine == nil ? nil : headerHeight)
    }

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
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(surfaceShape)
            .modifier(GlassSurface(cornerRadius: cardCornerRadius))
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            if let headerLine {
                header(headerLine)
            }

            TabView(selection: $viewModel.selectedID) {
                ForEach(viewModel.items) { item in
                    NearbyCardContentView(
                        item: item,
                        now: viewModel.now,
                        audioPlayer: audioPlayer,
                        onTap: { onSelect(item.detailSubject) }
                    )
                    .padding(.leading, Self.contentInset)
                    // Wider on the trailing edge so the row's text and audio button clear
                    // the favorite button sitting in the corner above them.
                    .padding(.trailing, Self.rowTrailingInset)
                    .padding(.top, Self.contentInset)
                    // The row now fills the page, so it needs its own gap above the footer.
                    .padding(.bottom, Self.rowFooterGap)
                    .tag(item.id as String?)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Rebuilt whenever the number of pages changes, rather than mutated in place.
            // The paged `TabView` is a `UICollectionView` underneath, and shrinking its
            // data while a selection-driven scroll is still pending crashed it in
            // `layoutSubviews` — "scroll to out-of-bounds item (3) when there are only 3
            // items" (Crashlytics fe741015e1cc320abea6275cd5f79a02): the pending scroll
            // still carried the selected card's *old* index after the nearby feed lost an
            // item under it. A new identity tears the collection view down instead, so the
            // fresh one only ever sees the new count and the reconciled selection. Keyed on
            // the count alone so the far more common case — the same cards re-sorted or
            // their distances refreshed — still animates normally.
            .id(viewModel.count)
            .frame(height: pageHeight)

            footer
        }
        // Outside the `TabView` so it stays put while pages swipe under it — a control
        // inside the pager competes with the page gesture and can't be dragged past.
        .overlay(alignment: .topTrailing) { favoriteButton }
    }

    /// Says where the card is looking from while the dropped person is standing somewhere:
    /// "Nearby G & 4:47". Absent — and costing the card no height at all — when the card is
    /// sourcing from the device, which needs no explanation.
    ///
    /// Trailing inset clears the favorite button in the corner above the row, exactly as the
    /// row's own text does.
    private func header(_ text: String) -> some View {
        HStack(spacing: 4) {
            // The same eye that is standing on the map, in the card's own secondary color.
            Image(systemName: DroppedPersonMarker.glyphSymbolName)
                .resizable()
                .scaledToFit()
                .frame(height: 11)
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(themeColors.secondaryColor)
        .padding(.leading, Self.contentInset)
        .padding(.trailing, Self.rowTrailingInset)
        // Pinned to exactly what `headerHeight` charged the card for, so the page and
        // footer below it land where their own fixed frames expect.
        .frame(height: min(headerLineHeight, Self.maximumHeaderLineHeight))
        .padding(.top, Self.headerTopInset)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
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
        // 4 here plus the buttons' own 6pt label inset puts "Hide" and "See all" on the
        // same `contentInset` line as the thumbnail and the favorite button above them.
        .padding(.horizontal, Self.contentInset - 6)
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
    ///
    /// While a person is standing on the map the same button is scoped to that drop and says
    /// so — it retires the pin and leaves the card's own setting alone (see
    /// `NearbyCardVisibility.hideAction`). Relabelling is what keeps that from being a
    /// surprise: "Hide" that doesn't hide would be one.
    private var hideButton: some View {
        let isDropped = viewModel.isSourceOverridden
        return Button(action: onHide) {
            Text(isDropped
                 ? NSLocalizedString("Clear pin", comment: "nearby card button retiring the dropped pin")
                 : NSLocalizedString("Hide", comment: "nearby card button hiding the card"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(themeColors.secondaryColor)
                .padding(.horizontal, 6)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDropped ? "Clear dropped pin" : "Hide nearby card")
        .accessibilityHint(isDropped
                           ? "Puts the card back on your own location"
                           : "Turn it back on in Map Filter")
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
            // Same inset the thumbnail uses on the opposite corner, so the card's padding
            // reads as uniform all the way round.
            .padding(.top, Self.contentInset)
            .padding(.trailing, Self.contentInset)
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

            textStack

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

    /// Name, then when/where, then what it is.
    ///
    /// The accessory line collapses the two pieces of hard metadata — an event's timing and
    /// the playa address — into one secondary line, so the description no longer has to be
    /// traded away for the address the moment the embargo lifts.
    @ViewBuilder
    private var textStack: some View {
        // Nil for a locked camp or art piece: `NearbyItem.address` withholds the address
        // until that object's tier opens, and only an unhosted event's free-text location
        // survives. When the line is absent the description takes its space.
        let accessory = item.accessoryLine(now: now)
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeColors.primaryColor)
                .lineLimit(1)

            if let accessory {
                Text(accessory)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(themeColors.secondaryColor)
                    .lineLimit(1)
            }

            if let description = item.detailDescription, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(themeColors.detailColor)
                    // Two lines only when there's no accessory line above to pay for: the
                    // page is sized to a single 3-line stack, and a compact card showing
                    // both facts beats a taller one showing more blurb.
                    .lineLimit(accessory == nil ? 2 : 1)
            }
        }
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
