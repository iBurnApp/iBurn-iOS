import SwiftUI
import UIKit
import PlayaDB

/// What a single rail slot draws.
enum SearchIndexGlyph: Equatable {
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

/// One stop on the search results index rail.
struct SearchIndexEntry: Equatable, Identifiable {
    /// Slot position in the rendered rail. Stable across redraws of the same result set.
    let id: Int
    let glyph: SearchIndexGlyph
    /// What the scrub bubble says — "Camps — B", "Events — Mon 9a", "Art". Composed, so
    /// the bubble still reads as a place even when the rail drew a bullet or an icon.
    let bubbleLabel: String
    /// `id` of the first row at this stop — what `ScrollViewReader` scrolls to.
    let anchorID: String

    var isBullet: Bool { glyph == .bullet }
}

/// Builds the search results index rail.
///
/// This is the Yap-era global-search index ported forward. `BRCDatabaseManager`'s
/// `registerSearchObjectsView` grouped searchable objects two different ways —
/// non-events by uppercased first letter of the title (anything non-alphabetic bucketed
/// into `#`), events by `"yyyy-MM-dd HH"` in Black Rock City time — and
/// `GroupTransformers.searchGroup` rendered those event groups as a day initial followed
/// by a 12-hour clock hour ("M6" = Monday 6 o'clock). Those group names *were* the
/// `sectionIndexTitles`, which is why the rail reads as letters for camps/art/vehicles and
/// numbers for events.
///
/// What global search adds over the Yap version is a type marker at the head of each
/// section, because these results interleave four types and the letters restart at every
/// one of them.
///
/// Everything here is pure so the rail's contents can be tested without SwiftUI.
enum SearchResultIndex {
    /// Below this many rows the whole list is a couple of flicks away, so a rail is noise.
    static let minimumRowCount = 12

    // MARK: - Index Titles

    /// The index title a single result sorts under.
    static func indexTitle(for item: SearchResultItem, calendar: Calendar = brcCalendar) -> String {
        switch item {
        case .event(let occurrence):
            return eventTitle(for: occurrence.startDate, calendar: calendar)
        case .art(let object):
            return letterTitle(for: object.name)
        case .camp(let object):
            return letterTitle(for: object.name)
        case .mutantVehicle(let object):
            return letterTitle(for: object.name)
        }
    }

    /// Uppercased first letter; digits, punctuation and emoji all bucket into "#" — the
    /// same rule the Yap grouping block used.
    static func letterTitle(for name: String) -> String {
        guard let first = name.first else { return "#" }
        let upper = String(first).uppercased()
        guard let scalar = upper.unicodeScalars.first,
              CharacterSet.letters.contains(scalar) else { return "#" }
        return upper
    }

    /// Day initial + 12-hour clock hour, e.g. "M6" for Monday 6:00. The day initial is
    /// what keeps a multi-day result set from showing the same digits over and over.
    static func eventTitle(for date: Date, calendar: Calendar = brcCalendar) -> String {
        let dayInitial = dayOfWeekFormatter.string(from: date).first.map(String.init) ?? ""
        return "\(dayInitial)\(clockHour(for: date, calendar: calendar))"
    }

    /// The rail's two characters spelled out for the scrub bubble: "Mon 9a", "Tue 12p".
    static func spelledEventTitle(for date: Date, calendar: Calendar = brcCalendar) -> String {
        let day = dayAbbreviationFormatter.string(from: date)
        let meridiem = calendar.component(.hour, from: date) < 12 ? "a" : "p"
        return "\(day) \(clockHour(for: date, calendar: calendar))\(meridiem)"
    }

    private static func clockHour(for date: Date, calendar: Calendar) -> Int {
        let hour24 = calendar.component(.hour, from: date)
        return hour24 % 12 == 0 ? 12 : hour24 % 12
    }

    /// Spoken form of an item's stop, without the section name.
    static func spelledTitle(for item: SearchResultItem, calendar: Calendar = brcCalendar) -> String {
        switch item {
        case .event(let occurrence):
            return spelledEventTitle(for: occurrence.startDate, calendar: calendar)
        default:
            return indexTitle(for: item, calendar: calendar)
        }
    }

    /// Type marker glyph, matching the tab bar / More screen iconography.
    static func markerGlyph(for type: DataObjectType) -> SearchIndexGlyph {
        switch type {
        case .art: .assetIcon("BRCArtIcon")
        case .camp: .assetIcon("BRCCampIcon")
        case .event: .assetIcon("BRCEventIcon")
        // No asset-catalog icon for mutant vehicles; this is the symbol the More screen
        // already uses for them.
        case .mutantVehicle: .symbolIcon("car.fill")
        }
    }

    // MARK: - Stops

    /// A candidate rail stop before it is fitted to the available slots.
    struct Stop: Equatable {
        let anchorID: String
        let glyph: SearchIndexGlyph
        let bubbleLabel: String
        /// Type markers are never dropped when the rail has to shed stops — without them
        /// a restarting A–Z run is unreadable.
        let isSectionMarker: Bool
    }

    /// Every stop in list order: a type marker at the head of each section, then one stop
    /// per consecutive run of rows sharing an index title.
    ///
    /// Runs are consecutive on purpose: the rail mirrors the list as it is actually
    /// ordered, so a stop always scrolls forward from the one above it.
    static func stops(
        for sections: [SearchResultSection],
        calendar: Calendar = brcCalendar
    ) -> [Stop] {
        var stops: [Stop] = []
        for section in sections {
            guard let first = section.items.first else { continue }
            stops.append(Stop(
                anchorID: first.id,
                glyph: markerGlyph(for: section.id),
                bubbleLabel: section.title,
                isSectionMarker: true
            ))

            var lastTitle: String?
            for item in section.items {
                let title = indexTitle(for: item, calendar: calendar)
                guard title != lastTitle else { continue }
                lastTitle = title
                stops.append(Stop(
                    anchorID: item.id,
                    glyph: .text(title),
                    bubbleLabel: "\(section.title) — \(spelledTitle(for: item, calendar: calendar))",
                    isSectionMarker: false
                ))
            }
        }
        return stops
    }

    // MARK: - Rendered Entries

    /// Stops fitted to `maxCount` rail slots.
    ///
    /// When they all fit, every slot is a labelled stop. When they don't, the type markers
    /// are kept whole and the letter/number stops between them are sampled evenly, with
    /// every other survivor drawn as a bullet — the rail still spans the whole list, and
    /// the labels that remain stay readable instead of shrinking into illegibility. This
    /// is what `UITableView` does to a crowded `sectionIndexTitles`.
    static func entries(
        for sections: [SearchResultSection],
        maxCount: Int,
        calendar: Calendar = brcCalendar
    ) -> [SearchIndexEntry] {
        let stops = stops(for: sections, calendar: calendar)
        guard isEnabled(for: sections, calendar: calendar), maxCount >= 2 else { return [] }

        let kept = fitted(stops: stops, maxCount: maxCount)
        guard kept.count >= 2 else { return [] }

        let collapses = kept.count < stops.count
        var textIndex = -1
        return kept.enumerated().map { slot, stop in
            var glyph = stop.glyph
            if !stop.isSectionMarker {
                textIndex += 1
                if collapses && textIndex % 2 == 1 && slot != kept.count - 1 {
                    glyph = .bullet
                }
            }
            return SearchIndexEntry(
                id: slot,
                glyph: glyph,
                bubbleLabel: stop.bubbleLabel,
                anchorID: stop.anchorID
            )
        }
    }

    /// Trim `stops` to at most `maxCount`, sampling the letter/number stops evenly and
    /// never dropping a type marker.
    private static func fitted(stops: [Stop], maxCount: Int) -> [Stop] {
        guard stops.count > maxCount else { return stops }

        let markerIndices = stops.indices.filter { stops[$0].isSectionMarker }
        // Pathological case: more sections than slots. Markers alone already say where
        // each type starts, which is the more useful half of the rail.
        guard markerIndices.count < maxCount else {
            return markerIndices.prefix(maxCount).map { stops[$0] }
        }

        let textIndices = stops.indices.filter { !stops[$0].isSectionMarker }
        let budget = maxCount - markerIndices.count
        var keep = Set(markerIndices)
        if budget == 1 {
            keep.insert(textIndices[0])
        } else {
            for slot in 0..<budget {
                let position = Double(slot) * Double(textIndices.count - 1) / Double(budget - 1)
                keep.insert(textIndices[Int(position.rounded())])
            }
        }
        return stops.indices.filter { keep.contains($0) }.map { stops[$0] }
    }

    /// How many slots fit in `height` points of rail.
    static func maxEntries(forHeight height: CGFloat) -> Int {
        guard height > 0 else { return 0 }
        return max(0, Int(height / SearchResultIndexView.slotHeight))
    }

    /// Whether these results warrant a rail at all, independent of how much vertical room
    /// there turns out to be. Lets the list reserve its trailing inset in the same pass
    /// that lays the rows out, instead of discovering the rail after the fact and running
    /// row text underneath it.
    /// Counted by distinct destinations, not by stops: a single section whose rows all
    /// share one letter produces a marker and a letter that both scroll to the same row,
    /// which is a rail that cannot take you anywhere.
    static func isEnabled(for sections: [SearchResultSection], calendar: Calendar = brcCalendar) -> Bool {
        let totalRows = sections.reduce(0) { $0 + $1.items.count }
        guard totalRows >= minimumRowCount else { return false }
        return Set(stops(for: sections, calendar: calendar).map(\.anchorID)).count >= 2
    }

    /// Trailing room a row must leave for the rail.
    static let railRowInset: CGFloat = 26

    // MARK: - Calendar

    /// Black Rock City local time, matching the Yap grouping formatter.
    static let brcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .burningManTimeZone
        return calendar
    }()

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = .burningManTimeZone
        return formatter
    }()

    private static let dayAbbreviationFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.timeZone = .burningManTimeZone
        return formatter
    }()
}

/// Right-edge quick-scrub index for the global search results list.
///
/// The gesture machinery is `EventHourIndexView`'s: labels measured with a `PreferenceKey`
/// inside a named coordinate space, a zero-distance `DragGesture` that snaps to the
/// nearest label, a haptic tick per stop, and a floating bubble naming the target. What
/// differs is what the stops *are* — see `SearchResultIndex`.
struct SearchResultIndexView: View {
    let entries: [SearchIndexEntry]
    /// Receives the row id to scroll to when the user taps or scrubs onto a stop.
    let onScrollTo: (String) -> Void

    @Environment(\.themeColors) private var themeColors
    @State private var activeSlot: Int?
    @State private var lastActiveEntry: SearchIndexEntry?
    @State private var labelFrames: [Int: CGRect] = [:]
    @State private var fingerY: CGFloat = 0
    @State private var stripWidth: CGFloat = 30

    /// Vertical room one stop occupies. Drives `SearchResultIndex.maxEntries(forHeight:)`,
    /// so the rail never asks for more slots than it can draw.
    static let slotHeight: CGFloat = 14

    private static let bubbleSize = CGSize(width: 176, height: 42)
    private static let horizontalGap: CGFloat = 8
    private static let verticalGap: CGFloat = 48
    private static let bubbleOpacity: CGFloat = 0.9
    private static let stripActiveOpacity: CGFloat = 0.7
    private static let labelWidth: CGFloat = 22
    private static let iconSize: CGFloat = 12
    /// Invisible leading-edge extension. Individual stops have to be small for an A–Z rail
    /// to fit at all (this is true of the system index too), so the comfortable target is
    /// the rail as a whole: this padding brings its grabbable width to ~44pt.
    private static let hiddenTapPadding: CGFloat = 22

    private var isScrubbing: Bool { activeSlot != nil }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                glyphView(entry.glyph)
                    .frame(width: Self.labelWidth, height: Self.slotHeight)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: SlotFramePreferenceKey.self,
                                value: [entry.id: geo.frame(in: .named("searchResultIndexStrip"))]
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
        .coordinateSpace(name: "searchResultIndexStrip")
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
        .accessibilityLabel("Search result index")
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
    private func glyphView(_ glyph: SearchIndexGlyph) -> some View {
        switch glyph {
        case .text(let title):
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        case .bullet:
            Text("•")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
        case .assetIcon(let name):
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .foregroundColor(themeColors.primaryColor)
        case .symbolIcon(let name):
            Image(systemName: name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(themeColors.primaryColor)
        }
    }

    /// The bubble names the section and the stop, even when the rail drew a bullet or an
    /// icon — while scrubbing it is the only thing telling you where you have landed.
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
