//
//  AlphabetIndexTests.swift
//  iBurnTests
//
//  Letter → row mapping behind the A–Z quick-scroll rail on the camps, art and
//  mutant vehicle lists.
//

import XCTest
@testable import iBurn

final class AlphabetIndexTests: XCTestCase {

    // MARK: - Helpers

    /// `count` rows named `A0, B1, C2, …` cycling the alphabet — enough to clear the
    /// rail's minimum row count without spelling out fixtures.
    private func filler(count: Int) -> [AlphabetIndexRow] {
        (0..<count).map { index in
            let letter = AlphabetIndex.letterTitles[index % AlphabetIndex.letterTitles.count]
            return AlphabetIndexRow(id: "filler-\(index)", name: "\(letter)\(index)")
        }
    }

    private func rows(_ names: [String]) -> [AlphabetIndexRow] {
        names.enumerated().map { AlphabetIndexRow(id: "row-\($0.offset)", name: $0.element) }
    }

    private func anchor(
        for title: String,
        in entries: [IndexRailEntry],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let entry = try XCTUnwrap(
            entries.first { $0.glyph == .text(title) },
            "No rail entry for \"\(title)\"",
            file: file,
            line: line
        )
        return entry.anchorID
    }

    // MARK: - letterTitle

    func testLetterTitleUppercasesFirstLetter() {
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "Anonymous Village"), "A")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "Zoo"), "Z")
    }

    func testLetterTitleFoldsCase() {
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "astro cats"), "A")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "tiny camp"), "T")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "rEVOLUTION"), "R")
    }

    func testLetterTitleFoldsDiacritics() {
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "Élan Vital"), "E")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "ñandú"), "N")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "Ålesund"), "A")
    }

    func testLetterTitleBucketsNonLetters() {
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "7 Sirens Cove"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "...cats"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "#MUXALOVE"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "¡AXOLOLT! The Earth Guardian"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "🔥 Camp"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: ""), "#")
    }

    /// Letters outside A–Z have no slot on the rail, so they must fall into "#" rather
    /// than producing an entry the rail never draws.
    func testLetterTitleBucketsNonLatinLetters() {
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "Живопись"), "#")
        XCTAssertEqual(AlphabetIndex.letterTitle(for: "東京キャンプ"), "#")
    }

    // MARK: - anchorsByTitle

    func testAnchorsTakeFirstRowInListOrder() {
        let anchors = AlphabetIndex.anchorsByTitle(for: rows([
            "Abraxas", "Astro Cats", "Blue Camp", "9 Lives"
        ]))
        XCTAssertEqual(anchors["A"], "row-0")
        XCTAssertEqual(anchors["B"], "row-2")
        XCTAssertEqual(anchors["#"], "row-3")
        XCTAssertNil(anchors["C"])
    }

    func testAnchorsForEmptyRows() {
        XCTAssertTrue(AlphabetIndex.anchorsByTitle(for: []).isEmpty)
    }

    // MARK: - resolvedAnchor

    func testResolvedAnchorPrefersExactMatch() {
        let anchors = ["A": "a-row", "C": "c-row"]
        XCTAssertEqual(AlphabetIndex.resolvedAnchor(for: "A", anchors: anchors), "a-row")
    }

    func testResolvedAnchorSnapsForwardForMissingLetter() {
        let anchors = ["A": "a-row", "D": "d-row"]
        XCTAssertEqual(AlphabetIndex.resolvedAnchor(for: "B", anchors: anchors), "d-row")
        XCTAssertEqual(AlphabetIndex.resolvedAnchor(for: "C", anchors: anchors), "d-row")
    }

    /// Nothing follows "Z" but "Y", so the tail of the alphabet snaps backward.
    func testResolvedAnchorSnapsBackwardWhenNothingFollows() {
        let anchors = ["A": "a-row", "M": "m-row"]
        XCTAssertEqual(AlphabetIndex.resolvedAnchor(for: "Z", anchors: anchors), "m-row")
        XCTAssertEqual(AlphabetIndex.resolvedAnchor(for: "Q", anchors: anchors), "m-row")
    }

    func testResolvedAnchorWithNoAnchors() {
        XCTAssertNil(AlphabetIndex.resolvedAnchor(for: "A", anchors: [:]))
    }

    // MARK: - entries

    func testEntriesEmptyForEmptyRows() {
        XCTAssertTrue(AlphabetIndex.entries(for: []).isEmpty)
    }

    func testEntriesEmptyBelowMinimumRowCount() {
        let short = filler(count: AlphabetIndex.minimumRowCount - 1)
        XCTAssertTrue(AlphabetIndex.entries(for: short).isEmpty)

        let long = filler(count: AlphabetIndex.minimumRowCount)
        XCTAssertFalse(AlphabetIndex.entries(for: long).isEmpty)
    }

    /// The rail draws the whole alphabet regardless of which letters are represented,
    /// exactly like `UITableView`'s section index — otherwise its stops move around as
    /// the list is filtered.
    func testEntriesSpanTheAlphabet() {
        let entries = AlphabetIndex.entries(for: filler(count: 40))
        XCTAssertEqual(entries.map(\.glyph), AlphabetIndex.letterTitles.map { IndexRailGlyph.text($0) })
        XCTAssertEqual(entries.map(\.id), Array(0..<entries.count))
    }

    /// "#" heads the rail only when something sorts under it.
    func testEntriesIncludeSymbolBucketOnlyWhenPresent() throws {
        let withoutSymbols = AlphabetIndex.entries(for: filler(count: 40))
        XCTAssertFalse(withoutSymbols.contains { $0.glyph == .text("#") })

        var withSymbols = filler(count: 40)
        withSymbols.insert(AlphabetIndexRow(id: "sym", name: "7 Sirens Cove"), at: 0)
        let entries = AlphabetIndex.entries(for: withSymbols)
        XCTAssertEqual(entries.first?.glyph, .text("#"))
        XCTAssertEqual(try anchor(for: "#", in: entries), "sym")
    }

    func testEntriesAnchorLettersAtTheirFirstRow() throws {
        var indexRows = rows(["Abraxas", "Bumblebee", "Cthulhu"])
        indexRows.append(contentsOf: filler(count: 30))
        let entries = AlphabetIndex.entries(for: indexRows)

        XCTAssertEqual(try anchor(for: "A", in: entries), "row-0")
        XCTAssertEqual(try anchor(for: "B", in: entries), "row-1")
        XCTAssertEqual(try anchor(for: "C", in: entries), "row-2")
    }

    /// A letter no row starts with still has a slot, and that slot goes somewhere useful.
    func testEntriesForMissingLettersSnapToNearestPresentLetter() throws {
        let names = (0..<25).map { "Aardvark \($0)" } + (0..<25).map { "Zebra \($0)" }
        let indexRows = rows(names)
        let entries = AlphabetIndex.entries(for: indexRows)

        let firstZebraID = try XCTUnwrap(indexRows.first { $0.name.hasPrefix("Zebra") }?.id)
        XCTAssertEqual(try anchor(for: "A", in: entries), "row-0")
        // Everything between snaps forward to Z, the next letter that exists.
        XCTAssertEqual(try anchor(for: "M", in: entries), firstZebraID)
        XCTAssertEqual(try anchor(for: "Y", in: entries), firstZebraID)
        XCTAssertEqual(try anchor(for: "Z", in: entries), firstZebraID)
    }

    /// Every letter resolves somewhere, so no rail slot is a dead tap.
    func testEveryEntryHasAnAnchor() {
        let entries = AlphabetIndex.entries(for: rows((0..<30).map { "Mudskipper \($0)" }))
        XCTAssertEqual(entries.count, AlphabetIndex.letterTitles.count)
        XCTAssertFalse(entries.contains { $0.anchorID.isEmpty })
        XCTAssertEqual(Set(entries.map(\.anchorID)).count, 1, "One letter present means one destination")
    }

    // MARK: - Fitting

    func testFittedKeepsBothEndsWhenSampling() throws {
        let fitted = AlphabetIndex.fitted(titles: AlphabetIndex.letterTitles, maxCount: 8)
        XCTAssertEqual(fitted.count, 8)
        XCTAssertEqual(fitted.first, "A")
        XCTAssertEqual(fitted.last, "Z")
        XCTAssertEqual(fitted, fitted.sorted(), "Sampling must preserve alphabet order")
    }

    func testFittedPassesThroughWhenEverythingFits() {
        XCTAssertEqual(
            AlphabetIndex.fitted(titles: AlphabetIndex.letterTitles, maxCount: 100),
            AlphabetIndex.letterTitles
        )
    }

    func testEntriesShedLettersWhenTheRailIsShort() {
        let entries = AlphabetIndex.entries(for: filler(count: 40), maxCount: 10)
        XCTAssertEqual(entries.count, 10)
        XCTAssertEqual(entries.first?.glyph, .text("A"))
        XCTAssertEqual(entries.last?.glyph, .text("Z"))
    }

    func testEntriesEmptyWhenThereIsNoRoomForARail() {
        XCTAssertTrue(AlphabetIndex.entries(for: filler(count: 40), maxCount: 1).isEmpty)
        XCTAssertTrue(AlphabetIndex.entries(for: filler(count: 40), maxCount: 0).isEmpty)
    }

    func testMaxEntriesForHeight() {
        XCTAssertEqual(AlphabetIndex.maxEntries(forHeight: 140, slotHeight: 14), 10)
        XCTAssertEqual(AlphabetIndex.maxEntries(forHeight: 0, slotHeight: 14), 0)
        XCTAssertEqual(AlphabetIndex.maxEntries(forHeight: -50, slotHeight: 14), 0)
        XCTAssertEqual(AlphabetIndex.maxEntries(forHeight: 140, slotHeight: 0), 0)
    }

    // MARK: - Enablement

    func testIsEnabledThreshold() {
        XCTAssertFalse(AlphabetIndex.isEnabled(rowCount: 0))
        XCTAssertFalse(AlphabetIndex.isEnabled(rowCount: AlphabetIndex.minimumRowCount - 1))
        XCTAssertTrue(AlphabetIndex.isEnabled(rowCount: AlphabetIndex.minimumRowCount))
    }
}
