import SwiftUI
import UIKit
import PlayaDB

/// Vertical hour quick-scroll strip overlay for the SwiftUI Events list.
/// Mirrors the legacy `UITableView.sectionIndexTitles` strip used in `EventListViewController`:
/// bare hour digits (`12, 1, 2, …`) where `12` appears at midnight + noon. Supports tap and
/// continuous drag-scrub with light haptic feedback on hour transitions.
struct EventHourIndexView: View {
    let sections: [EventHourSection]
    /// Receives the section's hour (0...23) when the user taps or scrubs onto it.
    let onScrollTo: (Int) -> Void

    @Environment(\.themeColors) private var themeColors
    @State private var activeHour: Int?
    @State private var labelFrames: [Int: CGRect] = [:]

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
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .coordinateSpace(name: "eventHourStrip")
        .onPreferenceChange(HourFramePreferenceKey.self) { labelFrames = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in handleDrag(at: value.location.y) }
                .onEnded { _ in activeHour = nil }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Event hour index")
    }

    private func handleDrag(at y: CGFloat) {
        guard let hit = labelFrames.first(where: { $0.value.minY <= y && y <= $0.value.maxY })?.key
        else { return }
        if hit != activeHour {
            activeHour = hit
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
}

private struct HourFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
