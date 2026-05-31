import SwiftUI
import UIKit
import PlayaDB

/// Vertical hour quick-scroll strip overlay for the SwiftUI Events list.
/// Mirrors the legacy `UITableView.sectionIndexTitles` strip used in `EventListViewController`:
/// bare hour digits (`12, 1, 2, …`) where `12` appears at midnight + noon. Supports tap and
/// continuous drag-scrub with light haptic feedback on hour transitions, plus a floating
/// scrubber bubble that fades in during a drag and tracks the finger above the touch point.
struct EventHourIndexView: View {
    let sections: [EventHourSection]
    /// Receives the section's hour (0...23) when the user taps or scrubs onto it.
    let onScrollTo: (Int) -> Void

    @Environment(\.themeColors) private var themeColors
    @State private var activeHour: Int?
    @State private var lastActiveHour: Int?
    @State private var labelFrames: [Int: CGRect] = [:]
    @State private var fingerY: CGFloat = 0
    @State private var stripWidth: CGFloat = 30

    private static let bubbleSize = CGSize(width: 64, height: 40)
    private static let horizontalGap: CGFloat = 8
    private static let verticalGap: CGFloat = 48
    private static let bubbleOpacity: CGFloat = 0.85
    private static let stripActiveOpacity: CGFloat = 0.7
    /// Invisible leading-edge tap area extension so the collapsed strip is comfortably
    /// tappable without expanding its visible footprint. Must stay ≤ EventListView's
    /// browseRowTrailingInset minus the strip's idle visual width to avoid overlapping
    /// row content's tap zone.
    private static let hiddenTapPadding: CGFloat = 16

    private var isScrubbing: Bool { activeHour != nil }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(sections, id: \.hour) { section in
                Text(Self.stripLabel(for: section.hour))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeColors.primaryColor)
                    .frame(width: 18, height: 14)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: HourFramePreferenceKey.self,
                                value: [section.hour: geo.frame(in: .named("eventHourStrip"))]
                            )
                        }
                    )
            }
        }
        .padding(.vertical, isScrubbing ? 10 : 0)
        .padding(.leading, isScrubbing ? 8 : 0)
        .padding(.trailing, isScrubbing ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(isScrubbing ? Self.stripActiveOpacity : 0)
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: StripWidthPreferenceKey.self,
                    value: geo.size.width
                )
            }
        )
        .coordinateSpace(name: "eventHourStrip")
        .onPreferenceChange(HourFramePreferenceKey.self) { labelFrames = $0 }
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
                        activeHour = nil
                    }
                }
        )
        .animation(.easeInOut(duration: 0.15), value: activeHour)
        .overlay(alignment: .topTrailing) {
            scrubberBubble
                .offset(
                    x: -(stripWidth + Self.horizontalGap),
                    y: fingerY - Self.bubbleSize.height - Self.verticalGap
                )
                .opacity(isScrubbing ? Self.bubbleOpacity : 0)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Event hour index")
    }

    private var scrubberBubble: some View {
        Text(lastActiveHour.map(Self.scrubberLabel) ?? "")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(themeColors.primaryColor)
            .frame(width: Self.bubbleSize.width, height: Self.bubbleSize.height)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
    }

    /// Snap to the digit whose center is closest to the touch Y. Touches inside the
    /// strip's padding or in spacing gaps between digits don't fall into any
    /// `labelFrames` rect, so a strict-contains test would silently miss them once
    /// `.contentShape(Rectangle())` widens the gesture's hit area.
    private func handleDrag(at y: CGFloat) {
        guard !labelFrames.isEmpty else { return }
        let closest = labelFrames.min { lhs, rhs in
            abs(y - lhs.value.midY) < abs(y - rhs.value.midY)
        }
        guard let hit = closest?.key else { return }
        if hit != activeHour {
            activeHour = hit
            lastActiveHour = hit
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onScrollTo(hit)
        }
    }

    /// `12, 1, 2, …, 11, 12, 1, …` — matches the legacy UIKit transform at
    /// `EventListViewController.swift:112-123` (`hour % 12`, with 0 → 12).
    private static func stripLabel(for hour: Int) -> String {
        let display = hour % 12 == 0 ? 12 : hour % 12
        return "\(display)"
    }

    private static func scrubberLabel(for hour: Int) -> String {
        let display = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour >= 12 ? "PM" : "AM"
        return "\(display) \(ampm)"
    }
}

private struct HourFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Published by `EventHourIndexView` so a parent (e.g. `EventListView`) can
/// auto-size row trailing insets to the strip's actual measured frame.
struct StripWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
