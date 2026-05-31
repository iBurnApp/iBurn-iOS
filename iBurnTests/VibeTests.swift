//
//  VibeTests.swift
//  iBurnTests
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn

final class VibeTests: XCTestCase {

    func testSurpriseChipHasSurpriseLean() throws {
        let surprise = try XCTUnwrap(SuggestionChip.all.first { $0.id == "surprise" })
        XCTAssertEqual(surprise.lean, .surprise)
        XCTAssertTrue(surprise.vibe.isEmpty)
    }

    func testTopicChipsUseBalancedLean() {
        for chip in SuggestionChip.all where chip.id != "surprise" {
            XCTAssertEqual(chip.lean, .balanced, "\(chip.id) should use a balanced lean")
        }
    }

    func testChipIdsAreUnique() {
        let ids = SuggestionChip.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "chip ids must be unique")
    }

    func testCoffeeVibeMapsToFoodAndBeverages() throws {
        let codes = try XCTUnwrap(eventTypeCodes(forVibe: "coffee"))
        XCTAssertTrue(codes.contains("tea"))
        XCTAssertTrue(codes.contains("food"))
    }

    func testLiveMusicVibeMapsToLive() throws {
        let codes = try XCTUnwrap(eventTypeCodes(forVibe: "live music"))
        XCTAssertTrue(codes.contains("live"))
    }

    func testWorkshopVibeMapsToWork() throws {
        let codes = try XCTUnwrap(eventTypeCodes(forVibe: "workshop"))
        XCTAssertTrue(codes.contains("work"))
    }

    func testEmptyVibeMapsToNil() {
        XCTAssertNil(eventTypeCodes(forVibe: ""))
    }

    func testUnknownVibeMapsToNil() {
        XCTAssertNil(eventTypeCodes(forVibe: "xyzzy qwerty"))
    }
}
