import SwiftUI
import UIKit
import PlayaDB

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
    /// same rule the Yap grouping block used. Shared with the browse lists' A–Z rail.
    static func letterTitle(for name: String) -> String {
        AlphabetIndex.letterTitle(for: name)
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
    static func markerGlyph(for type: DataObjectType) -> IndexRailGlyph {
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
        let glyph: IndexRailGlyph
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
    ) -> [IndexRailEntry] {
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
            return IndexRailEntry(
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
        return max(0, Int(height / IndexRailView.defaultSlotHeight))
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
