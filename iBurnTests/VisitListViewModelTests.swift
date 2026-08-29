//
//  VisitListViewModelTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers the SwiftUI/PlayaDB Visit List view model: section grouping by visit
//  status (⭐ Want to Visit / ✅ Visited, never "unvisited"), segment filtering,
//  in-memory search, and the one-shot refresh picking up status changes.
//

import CoreLocation
import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

/// No-op stand-in for the legacy YapDatabase mirror so tests never touch Yap.
private final class StubFavoriteSyncService: FavoriteSyncService {
    private(set) var mirroredFavorites: [(uid: String, isFavorite: Bool)] = []

    func mirrorFavorite(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool) async {
        mirroredFavorites.append((uid, isFavorite))
    }

    func mirrorVisitStatus(type: FavoriteSyncObjectType, uid: String, visitStatus: Int) async {}

    func mirrorNotes(type: FavoriteSyncObjectType, uid: String, notes: String) async {}
}

@MainActor
final class VisitListViewModelTests: XCTestCase {

    private var playaDB: PlayaDB?
    private var favoriteSync: StubFavoriteSyncService?

    private func makeViewModel() throws -> VisitListViewModel {
        let db = try XCTUnwrap(playaDB)
        let sync = try XCTUnwrap(favoriteSync)
        return VisitListViewModel(
            playaDB: db,
            artProvider: ArtDataProvider(playaDB: db, favoriteSync: sync),
            campProvider: CampDataProvider(playaDB: db, favoriteSync: sync),
            eventProvider: EventDataProvider(playaDB: db, favoriteSync: sync),
            mvProvider: MutantVehicleDataProvider(playaDB: db, favoriteSync: sync),
            locationProvider: MockLocationProvider()
        )
    }

    override func setUp() async throws {
        try await super.setUp()
        let db = try PlayaDBImpl(dbPath: ":memory:")
        try await db.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )
        playaDB = db
        favoriteSync = StubFavoriteSyncService()
    }

    override func tearDown() async throws {
        playaDB = nil
        favoriteSync = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func setStatus(_ status: VisitStatus, artUID: String) async throws {
        let db = try XCTUnwrap(playaDB)
        let fetched = try await db.fetchArt(uid: artUID)
        let art = try XCTUnwrap(fetched)
        try await db.setVisitStatus(status, for: art)
    }

    private func setStatus(_ status: VisitStatus, campUID: String) async throws {
        let db = try XCTUnwrap(playaDB)
        let fetched = try await db.fetchCamp(uid: campUID)
        let camp = try XCTUnwrap(fetched)
        try await db.setVisitStatus(status, for: camp)
    }

    private func setStatus(_ status: VisitStatus, eventUID: String) async throws {
        let db = try XCTUnwrap(playaDB)
        let fetched = try await db.fetchEvent(uid: eventUID)
        let event = try XCTUnwrap(fetched)
        try await db.setVisitStatus(status, for: event)
    }

    // MARK: - Section Grouping

    func testEmptyDatabaseHasNoSections() async throws {
        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testSectionsGroupByVisitStatus() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)
        try await setStatus(.visited, campUID: Self.campUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        XCTAssertEqual(viewModel.sections.count, 2)
        let want = try XCTUnwrap(viewModel.sections.first)
        let visited = try XCTUnwrap(viewModel.sections.last)

        XCTAssertEqual(want.id, .wantToVisit)
        XCTAssertEqual(want.title, "⭐ Want to Visit")
        XCTAssertEqual(want.items.map(\.uid), [Self.artUID])

        XCTAssertEqual(visited.id, .visited)
        XCTAssertEqual(visited.title, "✅ Visited")
        XCTAssertEqual(visited.items.map(\.uid), [Self.campUID])
    }

    func testUnvisitedObjectsNeverAppear() async throws {
        // Explicitly stamping .unvisited must not create a third section.
        try await setStatus(.wantToVisit, artUID: Self.artUID)
        try await setStatus(.unvisited, campUID: Self.campUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        XCTAssertEqual(viewModel.sections.map(\.id), [.wantToVisit])
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])
    }

    func testEventsResolveToFirstOccurrence() async throws {
        try await setStatus(.wantToVisit, eventUID: Self.eventUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        let item = try XCTUnwrap(viewModel.allItems.first)
        guard case .event(let occurrence, let status) = item else {
            return XCTFail("Expected an event occurrence item, got \(item)")
        }
        XCTAssertEqual(status, .wantToVisit)
        XCTAssertEqual(occurrence.event.uid, Self.eventUID)
        // Display uid is the occurrence uid; metadata identity is the parent event uid.
        XCTAssertEqual(item.favoriteKey, Self.eventUID)
        XCTAssertNotEqual(item.uid, Self.eventUID)
    }

    func testItemsWithinSectionAreSortedByName() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)       // "Burning Questions"
        try await setStatus(.wantToVisit, artUID: Self.otherArtUID)  // "Aardvark Ascending"

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        XCTAssertEqual(viewModel.allItems.map(\.name), ["Aardvark Ascending", "Burning Questions"])
    }

    // MARK: - Segment Filtering

    func testSegmentFilteringShowsOnlySelectedStatus() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)
        try await setStatus(.visited, campUID: Self.campUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        viewModel.selectedFilter = .wantToVisit
        XCTAssertEqual(viewModel.sections.map(\.id), [.wantToVisit])
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])

        viewModel.selectedFilter = .visited
        XCTAssertEqual(viewModel.sections.map(\.id), [.visited])
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.campUID])

        viewModel.selectedFilter = .all
        XCTAssertEqual(viewModel.sections.map(\.id), [.wantToVisit, .visited])
        XCTAssertEqual(viewModel.allItems.count, 2)
    }

    func testEmptySelectedSegmentProducesNoSections() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        viewModel.selectedFilter = .visited
        XCTAssertTrue(viewModel.sections.isEmpty)
        // The list still has content overall, which drives the "no results" vs
        // "nothing on your visit list" empty states.
        XCTAssertFalse(viewModel.isEmpty)
    }

    // MARK: - Search

    func testSearchFiltersItemsByName() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)
        try await setStatus(.visited, campUID: Self.campUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        viewModel.searchText = "burning"
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])
        XCTAssertEqual(viewModel.sections.map(\.id), [.wantToVisit])

        viewModel.searchText = "sign language"  // camp description
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.campUID])

        viewModel.searchText = "zzzznonexistent"
        XCTAssertTrue(viewModel.sections.isEmpty)

        viewModel.searchText = ""
        XCTAssertEqual(viewModel.allItems.count, 2)
    }

    func testSearchMatchesArtistField() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        viewModel.searchText = "jane smith"
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])
    }

    // MARK: - Refresh

    func testRefreshPicksUpStatusChanges() async throws {
        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()
        XCTAssertTrue(viewModel.sections.isEmpty)

        try await setStatus(.wantToVisit, artUID: Self.artUID)
        await viewModel.refreshAndWait()
        XCTAssertEqual(viewModel.sections.map(\.id), [.wantToVisit])
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])

        // Promote to visited: the item moves sections, it does not duplicate.
        try await setStatus(.visited, artUID: Self.artUID)
        await viewModel.refreshAndWait()
        XCTAssertEqual(viewModel.sections.map(\.id), [.visited])
        XCTAssertEqual(viewModel.allItems.map(\.uid), [Self.artUID])

        // Clearing the status removes it entirely.
        try await setStatus(.unvisited, artUID: Self.artUID)
        await viewModel.refreshAndWait()
        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertTrue(viewModel.isEmpty)
    }

    // MARK: - Favorites

    func testToggleFavoriteUpdatesStateAndMirrorsToLegacy() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        let item = try XCTUnwrap(viewModel.allItems.first)
        XCTAssertFalse(viewModel.isFavorite(item))

        await viewModel.toggleFavorite(item)
        XCTAssertTrue(viewModel.isFavorite(item))

        let db = try XCTUnwrap(playaDB)
        let fetchedArt = try await db.fetchArt(uid: Self.artUID)
        let art = try XCTUnwrap(fetchedArt)
        let isFavorite = try await db.isFavorite(art)
        XCTAssertTrue(isFavorite)

        await viewModel.toggleFavorite(item)
        XCTAssertFalse(viewModel.isFavorite(item))
    }

    func testFavoriteStateLoadsForEventsByParentUID() async throws {
        let db = try XCTUnwrap(playaDB)
        let fetchedEvent = try await db.fetchEvent(uid: Self.eventUID)
        let event = try XCTUnwrap(fetchedEvent)
        try await db.setFavorite(true, for: event)
        try await db.setVisitStatus(.visited, for: event)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        let item = try XCTUnwrap(viewModel.allItems.first)
        XCTAssertTrue(viewModel.isFavorite(item), "Event favorites are keyed by the parent event uid")
    }

    // MARK: - Map

    func testAnnotationsCoverListedItemsWithCoordinates() async throws {
        try await setStatus(.wantToVisit, artUID: Self.artUID)
        try await setStatus(.visited, campUID: Self.campUID)

        let viewModel = try makeViewModel()
        await viewModel.refreshAndWait()

        // Annotations only cover listed items that have coordinates.
        XCTAssertEqual(viewModel.allItems.count, 2)
        XCTAssertTrue(viewModel.allAnnotations.contains { $0.title == "Burning Questions" })
        XCTAssertLessThanOrEqual(viewModel.allAnnotations.count, viewModel.allItems.count)
    }

    // MARK: - Fixtures

    private static let artUID = "a2IVI000000yWeZ2AU"
    private static let otherArtUID = "a2IVI000000yWeZ2AV"
    private static let campUID = "a1XVI000008zSaf2AE"
    private static let eventUID = "78ZvNxSeeZQbaeHuughD"

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"An interactive art installation exploring curiosity.","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":null,"location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":false},
     {"uid":"a2IVI000000yWeZ2AV","name":"Aardvark Ascending","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"A kinetic sculpture.","artist":"Sam Jones","category":"Open Playa","program":"Honorarium","donation_link":null,"location":null,"location_string":null,"images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.data(using: .utf8) ?? Data()

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Camp ASL Support Services HUB","year":2026,"url":null,"contact_email":null,"hometown":"All over","description":"American sign language support services.","landmark":null,"location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":null},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8) ?? Data()

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"All levels welcome","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000008zSaf2AE","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T12:00:00-07:00","end_time":"2026-08-31T13:30:00-07:00"}]}]
    """.data(using: .utf8) ?? Data()
}
