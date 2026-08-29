//
//  PerOccurrenceFavoriteAppTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@testable import iBurn
import PlayaDB

/// App-side behaviour of per-occurrence event favorites: what Detail's heart means for an
/// occurrence versus for a bare event, and when the "favorite the whole series?" offer is
/// allowed to appear.
@MainActor
final class PerOccurrenceFavoriteAppTests: XCTestCase {

    private static let eventUID = "recurring-yoga-uid"

    private var playaDB: PlayaDB!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try createInMemoryPlayaDB()
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Fixtures

    private func occurrences() async throws -> [EventObjectOccurrence] {
        try await playaDB.fetchOccurrences(forEventUID: Self.eventUID)
            .sorted { $0.startDate < $1.startDate }
    }

    private func makeViewModel(subject: DetailSubject) -> DetailViewModel {
        DetailViewModel(
            subject: subject,
            playaDB: playaDB,
            locationService: MockLocationService(),
            coordinator: MockTestDetailActionCoordinator()
        )
    }

    // MARK: - Detail scope

    func testDetailOccurrenceToggleAffectsOnlyThatOccurrence() async throws {
        let all = try await occurrences()
        XCTAssertGreaterThan(all.count, 1)
        let target = try XCTUnwrap(all.first)
        let sibling = try XCTUnwrap(all.dropFirst().first)

        let viewModel = makeViewModel(subject: .eventOccurrence(target))
        await viewModel.toggleFavorite()

        XCTAssertTrue(viewModel.isFavorite)
        let targetFavorited = try await playaDB.isFavorite(target)
        let siblingFavorited = try await playaDB.isFavorite(sibling)
        XCTAssertTrue(targetFavorited)
        XCTAssertFalse(siblingFavorited, "Detail opened on one showing must not favorite the rest")
    }

    func testDetailBareEventToggleAffectsTheWholeSeries() async throws {
        let all = try await occurrences()
        let fetched = try await playaDB.fetchEvent(uid: Self.eventUID)
        let event = try XCTUnwrap(fetched)

        let viewModel = makeViewModel(subject: .event(event))
        await viewModel.toggleFavorite()

        XCTAssertTrue(viewModel.isFavorite)
        for occurrence in all {
            let favorited = try await playaDB.isFavorite(occurrence)
            XCTAssertTrue(favorited, "A bare event names no showing, so its heart means all of them")
        }
    }

    func testDetailOccurrenceUnfavoriteLeavesSiblingsFavorited() async throws {
        let all = try await occurrences()
        _ = try await playaDB.setFavorite(true, forEventSeries: Self.eventUID)
        let target = try XCTUnwrap(all.first)

        let viewModel = makeViewModel(subject: .eventOccurrence(target))
        await viewModel.toggleFavorite()

        XCTAssertFalse(viewModel.isFavorite)
        for sibling in all.dropFirst() {
            let favorited = try await playaDB.isFavorite(sibling)
            XCTAssertTrue(favorited)
        }
    }

    // MARK: - Toast eligibility

    func testToastOnlyOffersAfterAddingAnOccurrenceFavorite() {
        let identity = EventFavoriteKey.objectID(
            eventUID: Self.eventUID, occurrenceKey: "2025-08-26T14:00:00Z")

        XCTAssertEqual(
            FavoriteSeriesToastEligibility.candidateEventUID(
                objectType: "event", uid: identity, isFavorite: true),
            Self.eventUID
        )
        XCTAssertNil(
            FavoriteSeriesToastEligibility.candidateEventUID(
                objectType: "event", uid: identity, isFavorite: false),
            "Unfavoriting never raises an offer"
        )
        XCTAssertNil(
            FavoriteSeriesToastEligibility.candidateEventUID(
                objectType: "event", uid: Self.eventUID, isFavorite: true),
            "A bare event heart already means the series"
        )
        XCTAssertNil(
            FavoriteSeriesToastEligibility.candidateEventUID(
                objectType: "camp", uid: "camp-1", isFavorite: true)
        )
    }

    func testToastRequiresMoreThanOneOccurrence() {
        let identity = EventFavoriteKey.objectID(
            eventUID: Self.eventUID, occurrenceKey: "2025-08-26T14:00:00Z")

        XCTAssertNil(
            FavoriteSeriesToastEligibility.toast(
                eventUID: Self.eventUID, favoritedIdentity: identity,
                eventName: "Sunrise Yoga", occurrenceCount: 1),
            "A one-off has no series to offer"
        )
        XCTAssertNil(
            FavoriteSeriesToastEligibility.toast(
                eventUID: Self.eventUID, favoritedIdentity: identity,
                eventName: "Sunrise Yoga", occurrenceCount: 0)
        )

        let toast = FavoriteSeriesToastEligibility.toast(
            eventUID: Self.eventUID, favoritedIdentity: identity,
            eventName: "Sunrise Yoga", occurrenceCount: 3)
        XCTAssertEqual(toast?.remainingCount, 2)
        XCTAssertEqual(toast?.actionTitle, "Favorite all 3")
    }

    func testToastCopyIsSingularForASingleRemainingOccurrence() {
        let identity = EventFavoriteKey.objectID(
            eventUID: Self.eventUID, occurrenceKey: "2025-08-26T14:00:00Z")
        let toast = FavoriteSeriesToastEligibility.toast(
            eventUID: Self.eventUID, favoritedIdentity: identity,
            eventName: "Sunrise Yoga", occurrenceCount: 2)

        XCTAssertEqual(toast?.remainingCount, 1)
        XCTAssertEqual(toast?.actionTitle, "Favorite the other one")
    }

    // MARK: - Fixture data

    private static let artJSON = Data("[]".utf8)
    private static let campJSON = Data("[]".utf8)
    private static let eventJSON = Data("""
    [{"uid":"recurring-yoga-uid","title":"Sunrise Yoga","event_id":90001,"description":"Every morning.","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"recurring-yoga-uid-sunrise-yoga","hosted_by_camp":null,"located_at_art":null,"other_location":"Center Camp Plaza","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T07:00:00-07:00","end_time":"2026-08-31T08:00:00-07:00"},{"start_time":"2026-09-01T07:00:00-07:00","end_time":"2026-09-01T08:00:00-07:00"},{"start_time":"2026-09-02T07:00:00-07:00","end_time":"2026-09-02T08:00:00-07:00"}]}]
    """.utf8)
}
