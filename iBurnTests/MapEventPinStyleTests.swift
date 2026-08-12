//
//  MapEventPinStyleTests.swift
//  iBurnTests
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  How a favourited event's pin is drawn: which status colour it gets, and the fact that it
//  carries no name text of its own. Both were bugs on the real map — a generic purple
//  teardrop with a truncated event name floating below it.
//

import Foundation
import UIKit
import XCTest
import PlayaDB
@testable import iBurn

final class MapEventPinStyleTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_786_000_000)

    private func status(startsIn: TimeInterval, lasting duration: TimeInterval) -> EventPinStatus {
        let start = now.addingTimeInterval(startsIn)
        return EventPinStatus.status(startDate: start,
                                     endDate: start.addingTimeInterval(duration),
                                     now: now)
    }

    // MARK: - Status colours (same chain as the legacy BRCDataObject+EmojiMarker path)

    func testAnEventHoursAwayHasNoStatusColour() {
        let status = status(startsIn: 4 * 60 * 60, lasting: 60 * 60)
        XCTAssertEqual(status, .notStarted)
        XCTAssertNil(status.statusDotColor)
    }

    func testAnEventStartingWithinHalfAnHourIsGreen() {
        let status = status(startsIn: 20 * 60, lasting: 60 * 60)
        XCTAssertEqual(status, .startingSoon)
        XCTAssertEqual(status.statusDotColor, .systemGreen)
    }

    func testAnEventUnderwayIsGreen() {
        let status = status(startsIn: -30 * 60, lasting: 3 * 60 * 60)
        XCTAssertEqual(status, .happeningNow)
        XCTAssertEqual(status.statusDotColor, .systemGreen)
    }

    func testAnEventWithMinutesLeftIsOrange() {
        let status = status(startsIn: -50 * 60, lasting: 60 * 60)
        XCTAssertEqual(status, .endingSoon)
        XCTAssertEqual(status.statusDotColor, .systemOrange)
    }

    func testAFinishedEventIsRed() {
        let status = status(startsIn: -3 * 60 * 60, lasting: 60 * 60)
        XCTAssertEqual(status, .ended)
        XCTAssertEqual(status.statusDotColor, .systemRed)
    }

    /// Boundaries: exactly at a threshold counts as inside it, and the instant an
    /// occurrence's end passes it is over rather than "ending soon".
    func testThresholdBoundaries() {
        XCTAssertEqual(status(startsIn: EventPinStatus.startingSoonThreshold, lasting: 60 * 60),
                       .startingSoon)
        XCTAssertEqual(status(startsIn: EventPinStatus.startingSoonThreshold + 1, lasting: 60 * 60),
                       .notStarted)
        XCTAssertEqual(status(startsIn: -60 * 60, lasting: 60 * 60 + EventPinStatus.endingSoonThreshold),
                       .endingSoon)
        XCTAssertEqual(status(startsIn: -60 * 60, lasting: 60 * 60), .ended)
    }

    // MARK: - The pin's own name label

    /// The reported jank: "Vietnamese Iced C…" hanging below a favourited event's pin, over
    /// whatever camp it was standing on.
    func testAFavouritedEventPinDrawsNoLabel() {
        XCTAssertFalse(PinLabelVisibility.pinDrawsOwnLabel(objectType: .event, isFavorite: true))
    }

    /// Scoped to favourites: the active-events layer's pins are unchanged.
    func testANonFavouriteEventPinKeepsItsLabel() {
        XCTAssertTrue(PinLabelVisibility.pinDrawsOwnLabel(objectType: .event, isFavorite: false))
    }

    /// Art and camps still name themselves — a favourited art piece has nothing else naming
    /// it, and camp labels are handled by the separate style-layer rule.
    func testFavouritedArtAndCampsKeepTheirLabels() {
        XCTAssertTrue(PinLabelVisibility.pinDrawsOwnLabel(objectType: .art, isFavorite: true))
        XCTAssertTrue(PinLabelVisibility.pinDrawsOwnLabel(objectType: .camp, isFavorite: true))
    }

    /// User map points and the dropped person have no object type at all.
    func testPinsWithoutAnObjectTypeKeepTheirLabels() {
        XCTAssertTrue(PinLabelVisibility.pinDrawsOwnLabel(objectType: nil, isFavorite: true))
        XCTAssertTrue(PinLabelVisibility.pinDrawsOwnLabel(objectType: nil, isFavorite: false))
    }
}
