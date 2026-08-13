import SwiftUI
import UIKit

/// What a single rail slot draws.
enum IndexRailGlyph: Equatable {
    /// A letter ("A", "#") or an event stop ("M6").
    case text(String)
    /// A label dropped for want of vertical room. Still a jump target.
    case bullet
    /// A type marker at the head of a section. Asset-catalog image, matching the tab bar
    /// and More screen icons.
    case assetIcon(String)
    /// A type marker with no asset-catalog icon of its own.
    case symbolIcon(String)
}

/// One stop on an index rail.
struct IndexRailEntry: Equatable, Identifiable {
    /// Slot position in the rendered rail. Stable across redraws of the same result set.
    let id: Int
    let glyph: IndexRailGlyph
    /// What the scrub bubble says — "Camps — B", "Events — Mon 9a", "Art". Composed, so
    /// the bubble still reads as a place even when the rail drew a bullet or an icon.
    let bubbleLabel: String
    /// `id` of the first row at this stop — what `ScrollViewReader` scrolls to.
    let anchorID: String

    var isBullet: Bool { glyph == .bullet }
}

/// Right-edge quick-scrub index rail shared by the browse lists and global search.
///
/// The gesture machinery started life in `EventHourIndexView`: labels measured with a
/// `PreferenceKey` inside a named coordinate space, a zero-distance `DragGesture` that
/// snaps to the nearest label, a haptic tick per stop, and a floating bubble naming the
/// target. What differs per list is only what the stops *are* — see `SearchResultIndex`
/// (global search) and `AlphabetIndex` (camps/art/vehicles).
struct IndexRailView: View {
    let entries: [IndexRailEntry]
    /// Vertical room one stop occupies. Callers scale this for Dynamic Type and must feed
    /// the same value to their `maxEntries(forHeight:slotHeight:)` call so the rail never
    /// asks for more slots than it can draw.
    var slotHeight: CGFloat = IndexRailView.defaultSlotHeight
    /// Spoken name for the rail as a whole. Assistive tech and UI automation find it by this.
    var accessibilityLabel: String = "Index"
    /// Receives the row id to scroll to when the user taps or scrubs onto a stop.
    let onScrollTo: (String) -> Void

    @Environment(\.themeColors) private var themeColors
    @State private var activeSlot: Int?
    @State private var lastActiveEntry: IndexRailEntry?
    @State private var labelFrames: [Int: CGRect] = [:]
    @State private var fingerY: CGFloat = 0
    @State private var stripWidth: CGFloat = 30

    /// Slot height at the default content size.
    static let defaultSlotHeight: CGFloat = 14

    private static let bubbleSize = CGSize(width: 176, height: 42)
    private static let horizontalGap: CGFloat = 8
    private static let verticalGap: CGFloat = 48
    private static let bubbleOpacity: CGFloat = 0.9
    private static let stripActiveOpacity: CGFloat = 0.7
    private static let labelWidth: CGFloat = 22
    /// Invisible leading-edge extension. Individual stops have to be small for an A–Z rail
    /// to fit at all (this is true of the system index too), so the comfortable target is
    /// the rail as a whole: this padding brings its grabbable width to ~44pt.
    private static let hiddenTapPadding: CGFloat = 22

    private var isScrubbing: Bool { activeSlot != nil }

    /// Glyphs track the slot height so a Dynamic Type bump grows the rail's text with it.
    private var glyphFontSize: CGFloat {
        (slotHeight / Self.defaultSlotHeight * 10).rounded()
    }

    private var iconSize: CGFloat {
        (slotHeight / Self.defaultSlotHeight * 12).rounded()
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                glyphView(entry.glyph)
                    .frame(width: max(Self.labelWidth, glyphFontSize + 12), height: slotHeight)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SlotFramePreferenceKey.self,
                                value: [entry.id: geo.frame(in: .named("indexRailStrip"))]
                            )
                        }
                    )
            }
        }
        .padding(.vertical, isScrubbing ? 6 : 0)
        .padding(.leading, isScrubbing ? 8 : 0)
        .padding(.trailing, isScrubbing ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(isScrubbing ? Self.stripActiveOpacity : 0)
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: StripWidthPreferenceKey.self, value: geo.size.width)
            }
        )
        .coordinateSpace(name: "indexRailStrip")
        .onPreferenceChange(SlotFramePreferenceKey.self) { labelFrames = $0 }
        .onPreferenceChange(StripWidthPreferenceKey.self) { stripWidth = $0 }
        .padding(.leading, Self.hiddenTapPadding)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    fingerY = value.location.y
                    handleDrag(at: value.location.y)
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.18)) {
                        activeSlot = nil
                    }
                }
        )
        .animation(.easeInOut(duration: 0.15), value: activeSlot)
        // Declared before the bubble overlay so the accessibility element's frame is the
        // rail's own touch area. Applied after, it would grow to enclose the bubble —
        // which floats well to the left — and point assistive tech (and UI automation) at
        // empty space over the results.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .overlay(alignment: .topTrailing) {
            scrubberBubble
                .offset(
                    x: -(stripWidth + Self.horizontalGap),
                    y: fingerY - Self.bubbleSize.height - Self.verticalGap
                )
                .opacity(isScrubbing ? Self.bubbleOpacity : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func glyphView(_ glyph: IndexRailGlyph) -> some View {
        switch glyph {
        case .text(let title):
            Text(title)
                .font(.system(size: glyphFontSize, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .bullet:
            Text("•")
                .font(.system(size: glyphFontSize * 0.9, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
        case .assetIcon(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(themeColors.primaryColor)
        case .symbolIcon(let name):
            Image(systemName: name)
                .font(.system(size: glyphFontSize * 0.9, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
        }
    }

    /// The bubble names the stop, even when the rail drew a bullet or an icon — while
    /// scrubbing it is the only thing telling you where you have landed.
    private var scrubberBubble: some View {
        Text(lastActiveEntry?.bubbleLabel ?? "")
            .font(.system(size: 19, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 10)
            .foregroundColor(themeColors.primaryColor)
            .frame(width: Self.bubbleSize.width, height: Self.bubbleSize.height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
    }

    /// Snap to the slot whose center is closest to the touch Y. Touches in the rail's
    /// padding fall outside every measured rect, so a strict-contains test would drop them
    /// once `.contentShape(Rectangle())` widens the hit area.
    private func handleDrag(at y: CGFloat) {
        guard !labelFrames.isEmpty else { return }
        let closest = labelFrames.min { lhs, rhs in
            abs(y - lhs.value.midY) < abs(y - rhs.value.midY)
        }
        guard let hit = closest?.key, hit != activeSlot else { return }
        activeSlot = hit
        lastActiveEntry = entries.first { $0.id == hit }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let anchorID = lastActiveEntry?.anchorID {
            onScrollTo(anchorID)
        }
    }
}

private struct SlotFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
