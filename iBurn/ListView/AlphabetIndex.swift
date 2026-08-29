import Foundation
import SwiftUI

/// A row as the alphabetical rail sees it: something with a stable scroll id and a name.
struct AlphabetIndexRow: Equatable {
    /// Matches the `ForEach` id the list uses, so `ScrollViewReader.scrollTo` can find it.
    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

/// Builds the A–Z quick-scroll rail for the flat browse lists (camps, art, mutant vehicles).
///
/// This is the UIKit `sectionIndexTitles` behaviour ported forward. Those tables grouped
/// rows by uppercased first letter with everything non-alphabetic bucketed into `#`, drew
/// the full alphabet down the trailing edge, and — for a letter no row started with —
/// scrolled to the nearest section that did exist.
///
/// The lists themselves are flat and already ordered by the database, so the rail resolves
/// each letter against the rows *as ordered*, taking the first row whose name sorts under
/// it. That keeps the rail honest even where the database's byte-wise `name ASC` ordering
/// isn't strictly alphabetical (lowercase-initial names sort after `Z`); the letter still
/// lands on the first, and by far the largest, run for that letter.
///
/// Everything here is pure so it can be tested without SwiftUI.
enum AlphabetIndex {
    /// Below this many rows the whole list is a couple of flicks away, so a rail is noise.
    static let minimumRowCount = 20

    /// Trailing room a row must leave for the rail.
    static let railRowInset: CGFloat = 26

    /// Everything non-alphabetic — digits, punctuation, emoji, non-Latin scripts.
    static let symbolTitle = "#"

    /// "A" ... "Z".
    static let letterTitles: [String] = (UInt8(ascii: "A")...UInt8(ascii: "Z"))
        .map { String(UnicodeScalar($0)) }

    /// Rail order: the symbol bucket, then the alphabet — the UIKit convention.
    static let allTitles: [String] = [symbolTitle] + letterTitles

    // MARK: - Titles

    /// The rail title a name sorts under: its first letter, folded to plain uppercase
    /// A–Z. Case and diacritics are folded ("élan" → "E", "ÅSA" → "A"); digits,
    /// punctuation, emoji and letters outside A–Z all bucket into "#", so every possible
    /// name maps to a slot the rail actually draws.
    static func letterTitle(for name: String) -> String {
        guard let first = name.first else { return symbolTitle }
        let folded = String(first)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
        guard let scalar = folded.unicodeScalars.first,
              scalar.isASCII,
              CharacterSet.uppercaseLetters.contains(scalar) else { return symbolTitle }
        return String(Character(scalar))
    }

    // MARK: - Anchors

    /// First row id under each title, in list order. Titles no row falls under are absent.
    static func anchorsByTitle(for rows: [AlphabetIndexRow]) -> [String: String] {
        var anchors: [String: String] = [:]
        for row in rows {
            let title = letterTitle(for: row.name)
            if anchors[title] == nil {
                anchors[title] = row.id
            }
        }
        return anchors
    }

    /// Whether these rows warrant a rail at all. Checked separately from `entries` so a
    /// list can reserve its trailing inset in the same layout pass that draws the rows,
    /// instead of discovering the rail afterwards and running row text underneath it.
    static func isEnabled(rowCount: Int) -> Bool {
        rowCount >= minimumRowCount
    }

    // MARK: - Entries

    /// Rail stops for `rows`, fitted to at most `maxCount` slots.
    ///
    /// The rail always spans the alphabet rather than only the letters present, matching
    /// UIKit (and Contacts): a letter with no rows of its own resolves to the nearest
    /// letter that has some — forward first, since that is where the missing letter's rows
    /// *would* have been, then backward when nothing follows. `#` is drawn only when
    /// something actually sorts under it, because it heads the rail and would otherwise
    /// read as a row that isn't there.
    ///
    /// When the alphabet doesn't fit in `maxCount` slots (a short rail — landscape, or a
    /// large Dynamic Type size) the titles are sampled evenly. Single characters stay
    /// legible at any spacing, so sampled rails drop stops rather than shrinking them.
    static func entries(for rows: [AlphabetIndexRow], maxCount: Int = .max) -> [IndexRailEntry] {
        guard isEnabled(rowCount: rows.count), maxCount >= 2 else { return [] }

        let anchors = anchorsByTitle(for: rows)
        guard !anchors.isEmpty else { return [] }

        var titles = allTitles
        if anchors[symbolTitle] == nil {
            titles.removeFirst()
        }
        let fittedTitles = fitted(titles: titles, maxCount: maxCount)
        guard fittedTitles.count >= 2 else { return [] }

        return fittedTitles.enumerated().compactMap { slot, title in
            guard let anchorID = resolvedAnchor(for: title, anchors: anchors) else { return nil }
            return IndexRailEntry(
                id: slot,
                glyph: .text(title),
                bubbleLabel: title,
                anchorID: anchorID
            )
        }
    }

    /// The row a rail title scrolls to: its own first row, else the nearest title that has
    /// one — searching forward through the alphabet first, then backward.
    static func resolvedAnchor(for title: String, anchors: [String: String]) -> String? {
        if let exact = anchors[title] { return exact }
        guard let position = allTitles.firstIndex(of: title) else { return nil }

        for index in allTitles.indices where index > position {
            if let anchor = anchors[allTitles[index]] { return anchor }
        }
        for index in stride(from: position - 1, through: 0, by: -1) {
            if let anchor = anchors[allTitles[index]] { return anchor }
        }
        return nil
    }

    /// Trim `titles` to at most `maxCount`, sampled evenly and always keeping the ends.
    static func fitted(titles: [String], maxCount: Int) -> [String] {
        guard titles.count > maxCount, maxCount >= 2 else { return titles }

        var keep = Set<Int>()
        for slot in 0..<maxCount {
            let position = Double(slot) * Double(titles.count - 1) / Double(maxCount - 1)
            keep.insert(Int(position.rounded()))
        }
        return titles.indices.filter { keep.contains($0) }.map { titles[$0] }
    }

    /// How many slots fit in `height` points of rail.
    static func maxEntries(forHeight height: CGFloat, slotHeight: CGFloat) -> Int {
        guard height > 0, slotHeight > 0 else { return 0 }
        return max(0, Int(height / slotHeight))
    }
}

// MARK: - View Attachment

extension View {
    /// Overlays the A–Z quick-scroll rail on a flat, name-ordered list.
    ///
    /// Wraps the list in a `ScrollViewReader` so a tapped letter can scroll to its first
    /// row. `rows` must be the rows the list is *currently* showing — filtered and
    /// searched — with ids matching the list's `ForEach` id, so the rail follows the
    /// visible content and disappears once a filter shortens it past the threshold.
    func alphabetIndexRail(
        rows: [AlphabetIndexRow],
        accessibilityLabel: String
    ) -> some View {
        modifier(AlphabetIndexRailModifier(rows: rows, accessibilityLabel: accessibilityLabel))
    }
}

private struct AlphabetIndexRailModifier: ViewModifier {
    let rows: [AlphabetIndexRow]
    let accessibilityLabel: String

    /// Grows the rail with the user's text size, within what the trailing edge can hold;
    /// `entries` sheds letters when the scaled rail no longer fits the alphabet.
    @ScaledMetric(relativeTo: .caption2) private var slotHeight: CGFloat = IndexRailView.defaultSlotHeight

    /// Breathing room top and bottom so the rail doesn't butt against the list's edges.
    private static let verticalInset: CGFloat = 24

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.overlay(alignment: .trailing) {
                GeometryReader { geo in
                    let entries = AlphabetIndex.entries(
                        for: rows,
                        maxCount: AlphabetIndex.maxEntries(
                            forHeight: geo.size.height - Self.verticalInset,
                            slotHeight: slotHeight
                        )
                    )
                    if !entries.isEmpty {
                        IndexRailView(
                            entries: entries,
                            slotHeight: slotHeight,
                            accessibilityLabel: accessibilityLabel
                        ) { anchorID in
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(anchorID, anchor: .top)
                            }
                        }
                        .padding(.trailing, 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}
