//
//  TravelTimeFormatterTests.swift
//  iBurnTests
//
//  Pins the walk/bike estimate that used to come from the FormatterKit
//  `TTTLocationFormatter+iBurn` category, so the Swift port renders the same text.
//

import UIKit
import XCTest
@testable import iBurn

final class TravelTimeFormatterTests: XCTestCase {

    // MARK: - Time estimates

    func testWalkSecondsIncludeFaff() {
        XCTAssertEqual(TravelTimeFormatter.walkSeconds(forDistance: 0), 120, accuracy: 0.0001)
        XCTAssertEqual(TravelTimeFormatter.walkSeconds(forDistance: 300), 540, accuracy: 0.0001)
        XCTAssertEqual(TravelTimeFormatter.walkSeconds(forDistance: 1000), 1520, accuracy: 0.0001)
    }

    func testBikeSecondsIncludeFaff() {
        XCTAssertEqual(TravelTimeFormatter.bikeSeconds(forDistance: 0), 120, accuracy: 0.0001)
        XCTAssertEqual(TravelTimeFormatter.bikeSeconds(forDistance: 1000), 552.258065, accuracy: 0.0001)
    }

    // MARK: - Effort thresholds

    func testEffortThresholds() {
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 0), .easy)
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 20 * 60 - 1), .easy)
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 20 * 60), .moderate)
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 35 * 60 - 1), .moderate)
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 35 * 60), .hard)
        XCTAssertEqual(TravelTimeFormatter.effort(forTimeInterval: 10 * 60 * 60), .hard)
    }

    func testEffortColors() {
        XCTAssertEqual(TravelTimeFormatter.Effort.easy.color, UIColor.brc_green)
        XCTAssertEqual(TravelTimeFormatter.Effort.moderate.color, UIColor.brc_orange)
        XCTAssertEqual(TravelTimeFormatter.Effort.hard.color, UIColor.brc_red)
    }

    // MARK: - String shape

    /// The exact strings the FormatterKit category produced (en locale, abbreviated
    /// `DateComponentsFormatter`, minutes truncated).
    func testStringsMatchLegacyOutput() {
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 0), "🚶🏽 2m   🚴🏽 2m")
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 100), "🚶🏽 4m   🚴🏽 2m")
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 300), "🚶🏽 9m   🚴🏽 4m")
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 1000), "🚶🏽 25m   🚴🏽 9m")
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 2000), "🚶🏽 48m   🚴🏽 16m")
    }

    /// Past an hour the text comes straight from `DateFormatters.stringForTimeInterval`.
    func testLongTripUsesSharedIntervalFormatter() throws {
        let walk = try XCTUnwrap(DateFormatters.stringForTimeInterval(7120))
        let bike = try XCTUnwrap(DateFormatters.stringForTimeInterval(2281.290325))
        XCTAssertEqual(TravelTimeFormatter.string(forDistance: 5000), "🚶🏽 \(walk)   🚴🏽 \(bike)")
    }

    func testAttributedStringTextMatchesPlainString() throws {
        let attributed = try XCTUnwrap(TravelTimeFormatter.attributedString(forDistance: 1000))
        XCTAssertEqual(attributed.string, TravelTimeFormatter.string(forDistance: 1000))
    }

    // MARK: - Colors

    /// 1000 m: 25m walk (orange), 9m bike (green).
    func testTimesAreColoredByEffort() throws {
        let attributed = try XCTUnwrap(TravelTimeFormatter.attributedString(forDistance: 1000))
        let text = attributed.string as NSString

        let walkRange = text.range(of: "25m")
        let bikeRange = text.range(of: "9m")
        XCTAssertEqual(color(in: attributed, at: walkRange.location), UIColor.brc_orange)
        XCTAssertEqual(color(in: attributed, at: bikeRange.location), UIColor.brc_green)
        XCTAssertNil(color(in: attributed, at: 0), "the walking emoji stays uncolored")
    }

    /// 2000 m: 48m walk (red), 16m bike (green).
    func testLongWalkIsRed() throws {
        let attributed = try XCTUnwrap(TravelTimeFormatter.attributedString(forDistance: 2000))
        let text = attributed.string as NSString
        XCTAssertEqual(color(in: attributed, at: text.range(of: "48m").location), UIColor.brc_red)
        XCTAssertEqual(color(in: attributed, at: text.range(of: "16m").location), UIColor.brc_green)
    }

    /// At 0 m both times read "2m". The old category found the bike range by searching,
    /// which landed on the walking text; the port colors each time in place.
    func testIdenticalTimesAreBothColored() throws {
        let attributed = try XCTUnwrap(TravelTimeFormatter.attributedString(forDistance: 0))
        let text = attributed.string as NSString
        let first = text.range(of: "2m")
        let last = text.range(of: "2m", options: .backwards)
        XCTAssertNotEqual(first.location, last.location)
        XCTAssertEqual(color(in: attributed, at: first.location), UIColor.brc_green)
        XCTAssertEqual(color(in: attributed, at: last.location), UIColor.brc_green)
    }

    private func color(in string: NSAttributedString, at location: Int) -> UIColor? {
        string.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor
    }
}
