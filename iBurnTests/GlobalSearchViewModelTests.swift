import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

/// No-op stand-in for the legacy YapDatabase mirror so tests never touch Yap.
private final class StubFavoriteSyncService: FavoriteSyncService, @unchecked Sendable {
    private(set) var mirroredFavorites: [(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool)] = []

    func mirrorFavorite(type: FavoriteSyncObjectType, uid: String, isFavorite: Bool) async {
        mirroredFavorites.append((type, uid, isFavorite))
    }

    func mirrorVisitStatus(type: FavoriteSyncObjectType, uid: String, visitStatus: Int) async {}

    func mirrorNotes(type: FavoriteSyncObjectType, uid: String, notes: String) async {}
}

@MainActor
final class GlobalSearchViewModelTests: XCTestCase {

    private var playaDB: PlayaDB!
    private var favoriteSync: StubFavoriteSyncService!
    private var viewModel: GlobalSearchViewModel!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )
        favoriteSync = StubFavoriteSyncService()
        // nil storage key keeps the filter out of UserDefaults, so tests don't leak
        // filter state into each other or into the simulator's defaults.
        viewModel = GlobalSearchViewModel(
            playaDB: playaDB,
            favoriteSync: favoriteSync,
            filterStorageKey: nil
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        favoriteSync = nil
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Inline Test Data (copied from PlayaAPITestHelpers.MockAPIData)

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2025,"url":"https://www.burningquestions.com/","contact_email":"artist@burningquestions.com","hometown":"San Francisco, CA","description":"An interactive art installation exploring curiosity and wonder.","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":"https://crowdfundr.com/burningquestions","location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[{"thumbnail_url":"https://example.com/art-image.jpeg","gallery_ref":"gallery-123"}],"guided_tours":false,"self_guided_tour_map":true}]
    """.data(using: .utf8)!

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Camp ASL Support Services HUB","year":2025,"url":null,"contact_email":"ddhplanb@gmail.com","hometown":"All over, north, and, South America","description":"American sign language Support services. Centralized services for the Deaf.","landmark":"American sign language support services sign","location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":"Mid-block facing 10:00"},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8)!

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"First time picking up cards? A professional reader? All levels welcome","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2025,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000009t6XR2AY","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2025-08-28T12:00:00-07:00","end_time":"2025-08-28T13:30:00-07:00"}]}]
    """.data(using: .utf8)!

    // MARK: - Helpers

    private func eventually(
        timeoutSeconds: TimeInterval = 3.0,
        pollNanoseconds: UInt64 = 50_000_000,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let timeoutNanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }

    /// `eventually` for conditions that have to hit the database.
    private func eventuallyAsync(
        timeoutSeconds: TimeInterval = 3.0,
        pollNanoseconds: UInt64 = 50_000_000,
        _ condition: @MainActor () async -> Bool
    ) async -> Bool {
        let timeoutNanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return await condition()
    }

    // MARK: - Tests

    func testInitialStateIsEmpty() {
        XCTAssertTrue(viewModel.sections.isEmpty)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertFalse(viewModel.isSearching)
    }

    func testShortQueryDoesNotSearch() async {
        viewModel.searchText = "a"
        // Wait a bit to confirm nothing happens
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(viewModel.sections.isEmpty, "Single character should not trigger search")
        XCTAssertFalse(viewModel.isSearching)
    }

    func testSearchReturnsGroupedResults() async {
        viewModel.searchText = "Burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults, "Should have results for 'Curiosity'")

        // Results should be grouped by type
        for section in viewModel.sections {
            XCTAssertFalse(section.items.isEmpty, "Section \(section.title) should have items")
            XCTAssertFalse(section.title.isEmpty, "Section should have a title")
        }
    }

    func testSearchNoResults() async {
        viewModel.searchText = "zzzznonexistent"

        let doneSearching = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(doneSearching, "Should finish searching with no results")
    }

    func testClearSearchClearsResults() async {
        // First search
        viewModel.searchText = "Burning"
        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults)

        // Clear
        viewModel.searchText = ""
        let cleared = await eventually { self.viewModel.sections.isEmpty }
        XCTAssertTrue(cleared, "Clearing search text should clear results")
    }

    func testSearchResultItemsHaveUIDs() async {
        viewModel.searchText = "Burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults)

        for section in viewModel.sections {
            for item in section.items {
                XCTAssertFalse(item.uid.isEmpty, "Each result should have a non-empty UID")
                XCTAssertFalse(item.name.isEmpty, "Each result should have a non-empty name")
            }
        }
    }

    // MARK: - Scope

    func testInitialScopeIsAll() {
        XCTAssertEqual(viewModel.scope, .all)
        XCTAssertTrue(viewModel.filter.isDefault)
    }

    func testScopedSearchReturnsOnlyThatType() async {
        viewModel.scope = .art
        viewModel.searchText = "Burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults)
        XCTAssertEqual(viewModel.sections.map(\.id), [.art])
    }

    func testScopeExcludesOtherTypes() async {
        // "Services" is camp-only test data.
        viewModel.searchText = "Services"
        let foundCamp = await eventually { self.viewModel.sections.contains { $0.id == .camp } }
        XCTAssertTrue(foundCamp, "Unscoped search should find the camp")

        viewModel.scope = .art
        let scopedOut = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(scopedOut, "Art scope should skip camps entirely")
    }

    func testChangingScopeReRunsSearchWithoutRetyping() async {
        viewModel.scope = .camps
        viewModel.searchText = "Burning"
        let campScopeEmpty = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(campScopeEmpty)

        viewModel.scope = .art
        let artScopeHasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(artScopeHasResults, "Scope change alone should re-run the query")
    }

    // MARK: - Search Semantics

    func testMultiWordOutOfOrderQueryMatches() async {
        // AND-of-tokens, not phrase matching: the old quoted-phrase search missed this.
        viewModel.searchText = "questions burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults, "All tokens present in any order should match")
        XCTAssertTrue(viewModel.sections.contains { $0.id == .art })
    }

    func testEventResultsHaveOneRowPerEvent() async throws {
        viewModel.scope = .events
        viewModel.searchText = "Tarot"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults)

        let eventSection = try XCTUnwrap(viewModel.sections.first { $0.id == .event })
        let uids = eventSection.items.map(\.uid)
        XCTAssertEqual(uids.count, Set(uids).count, "Each event should appear once")
    }

    // MARK: - Filter

    func testOnlyFavoritesFiltersResults() async throws {
        viewModel.filter.onlyFavorites = true
        viewModel.searchText = "Services"

        let noFavorites = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(noFavorites, "Nothing is favorited yet")

        let camps = try await playaDB.fetchCamps()
        let camp = try XCTUnwrap(camps.first)
        try await playaDB.setFavorite(true, for: camp)

        // Re-assigning the same text re-runs the query against the new favorite state.
        viewModel.searchText = "Services"
        let foundFavorite = await eventually {
            self.viewModel.sections.contains { $0.id == .camp }
        }
        XCTAssertTrue(foundFavorite, "Favorited camp should pass the filter")
    }

    func testHappeningNowFiltersEventsByOccurrenceTime() async {
        viewModel.scope = .events
        viewModel.searchText = "Tarot"

        let hasEvent = await eventually { self.viewModel.sections.contains { $0.id == .event } }
        XCTAssertTrue(hasEvent)

        // The only fixture occurrence is in 2025, so nothing can be running now.
        viewModel.filter.happeningNow = true
        let filteredOut = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(filteredOut, "Happening Now should drop the past occurrence")
    }

    func testHappeningNowDoesNotAffectNonEventScopes() async {
        viewModel.scope = .art
        viewModel.filter.happeningNow = true
        viewModel.searchText = "Burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults, "Event-only knob should be inert for art")
        XCTAssertEqual(viewModel.sections.map(\.id), [.art])
    }

    // MARK: - Favorites

    /// Search a term and return the first item of the section of the given type.
    private func firstItem(ofType type: DataObjectType, query: String) async throws -> SearchResultItem {
        viewModel.searchText = query
        let hasResults = await eventually { self.viewModel.sections.contains { $0.id == type } }
        XCTAssertTrue(hasResults, "Expected \(type) results for \u{201C}\(query)\u{201D}")
        let section = try XCTUnwrap(viewModel.sections.first { $0.id == type })
        return try XCTUnwrap(section.items.first)
    }

    func testResultsStartUnfavorited() async throws {
        let camp = try await firstItem(ofType: .camp, query: "Services")
        XCTAssertFalse(viewModel.isFavorite(camp))
        XCTAssertTrue(viewModel.favoriteIdentifiers.isEmpty)
    }

    func testTogglingCampFavoriteFlipsRowStateImmediately() async throws {
        let camp = try await firstItem(ofType: .camp, query: "Services")

        viewModel.toggleFavorite(camp)
        XCTAssertTrue(viewModel.isFavorite(camp), "Heart should fill without waiting on the write")

        let persisted = await eventuallyAsync {
            (try? await self.playaDB.isFavorite(camp.dataObject)) == true
        }
        XCTAssertTrue(persisted, "Toggle should reach the database")
    }

    func testUnfavoritingFromSearchClearsBothRowAndDatabase() async throws {
        let camp = try await firstItem(ofType: .camp, query: "Services")
        try await playaDB.setFavorite(true, for: camp.dataObject)

        // Re-running the search re-reads favorite state from the database.
        viewModel.searchText = "Services"
        let showsFavorite = await eventually { self.viewModel.isFavorite(camp) }
        XCTAssertTrue(showsFavorite, "Favorites set elsewhere should show up on the next search")

        viewModel.toggleFavorite(camp)
        XCTAssertFalse(viewModel.isFavorite(camp))

        let cleared = await eventuallyAsync {
            (try? await self.playaDB.isFavorite(camp.dataObject)) == false
        }
        XCTAssertTrue(cleared)
    }

    func testEventFavoriteIsKeyedByTheDisplayedOccurrence() async throws {
        viewModel.scope = .events
        let event = try await firstItem(ofType: .event, query: "Tarot")
        guard case .event(let occurrence) = event else {
            return XCTFail("Expected an event occurrence")
        }
        XCTAssertNotEqual(occurrence.uid, occurrence.favoriteIdentity,
                          "Occurrence uid is a synthesized rowid composite; the favorite key is start-time based")
        XCTAssertEqual(event.favoriteIdentity, occurrence.favoriteIdentity)

        viewModel.toggleFavorite(event)
        XCTAssertTrue(viewModel.favoriteIdentifiers.contains(occurrence.favoriteIdentity))

        let wroteOccurrenceRow = await eventuallyAsync {
            let events = try? await self.playaDB.fetchEvents()
            guard let match = events?.first(where: { $0.favoriteIdentity == occurrence.favoriteIdentity }) else {
                return false
            }
            return (try? await self.playaDB.isFavorite(match)) == true
        }
        XCTAssertTrue(wroteOccurrenceRow, "Favorite should land on the occurrence's own metadata row")
    }

    /// A search row stands in for one showing, so its heart is that showing's state —
    /// a different showing of the same event favorited elsewhere leaves this row empty.
    func testEventFavoriteDoesNotFillSiblingOccurrences() async throws {
        viewModel.scope = .events
        let event = try await firstItem(ofType: .event, query: "Tarot")
        guard case .event(let occurrence) = event else {
            return XCTFail("Expected an event occurrence")
        }
        viewModel.toggleFavorite(event)

        let sibling = EventObjectOccurrence(
            event: occurrence.event,
            occurrence: EventOccurrence(
                id: (occurrence.occurrence.id ?? 0) + 999,
                eventId: occurrence.event.uid,
                startTime: occurrence.startDate.addingTimeInterval(86400),
                endTime: occurrence.endDate.addingTimeInterval(86400)
            )
        )
        XCTAssertNotEqual(sibling.favoriteIdentity, occurrence.favoriteIdentity)
        XCTAssertFalse(viewModel.isFavorite(.event(sibling)))
    }

    func testFavoriteTogglesMirrorIntoLegacyDatabase() async throws {
        let camp = try await firstItem(ofType: .camp, query: "Services")
        viewModel.toggleFavorite(camp)

        let mirrored = await eventually { !self.favoriteSync.mirroredFavorites.isEmpty }
        XCTAssertTrue(mirrored, "Legacy Yap mirror should be invoked, as on the list screens")
        let entry = try XCTUnwrap(favoriteSync.mirroredFavorites.first)
        XCTAssertEqual(entry.uid, camp.uid)
        XCTAssertTrue(entry.isFavorite)
    }

    func testEventMirrorUsesTheOccurrenceCompositeKey() async throws {
        viewModel.scope = .events
        let event = try await firstItem(ofType: .event, query: "Tarot")
        guard case .event(let occurrence) = event else {
            return XCTFail("Expected an event occurrence")
        }
        viewModel.toggleFavorite(event)

        let mirrored = await eventually { !self.favoriteSync.mirroredFavorites.isEmpty }
        XCTAssertTrue(mirrored)
        let entry = try XCTUnwrap(favoriteSync.mirroredFavorites.first)
        XCTAssertEqual(entry.uid, occurrence.favoriteIdentity,
                       "The mirror matches the one Yap occurrence starting at that instant")
        XCTAssertEqual(EventFavoriteKey.eventUID(from: entry.uid), occurrence.event.uid)
    }

    func testClearingSearchClearsFavoriteState() async throws {
        let camp = try await firstItem(ofType: .camp, query: "Services")
        viewModel.toggleFavorite(camp)
        XCTAssertFalse(viewModel.favoriteIdentifiers.isEmpty)

        viewModel.searchText = ""
        let cleared = await eventually { self.viewModel.favoriteIdentifiers.isEmpty }
        XCTAssertTrue(cleared)
    }

    // MARK: - Event Day / Time Filters

    func testDayFilterKeepsMatchingDay() async throws {
        // The fixture occurrence starts 2025-08-28 12:00 -0700.
        let day = try XCTUnwrap(ISO8601DateFormatter().date(from: "2025-08-28T12:00:00-07:00"))
        viewModel.scope = .events
        viewModel.filter.day = day
        viewModel.searchText = "Tarot"

        let found = await eventually { self.viewModel.sections.contains { $0.id == .event } }
        XCTAssertTrue(found, "The event's only occurrence is on the selected day")
    }

    func testDayFilterExcludesOtherDays() async {
        let otherDay = Date(timeIntervalSince1970: 0)
        viewModel.scope = .events
        viewModel.filter.day = otherDay
        viewModel.searchText = "Tarot"

        let empty = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(empty, "A day with no occurrences should return nothing")
    }

    func testTimeOfDayFilterExcludesNonMatchingOccurrences() async {
        viewModel.scope = .events
        viewModel.searchText = "Tarot"
        let hasEvent = await eventually { self.viewModel.sections.contains { $0.id == .event } }
        XCTAssertTrue(hasEvent)

        // The fixture occurrence starts at noon — afternoon, not late night.
        viewModel.filter.timeOfDay = .lateNight
        let filteredOut = await eventually {
            !self.viewModel.isSearching && self.viewModel.sections.isEmpty
        }
        XCTAssertTrue(filteredOut)

        viewModel.filter.timeOfDay = .afternoon
        let backAgain = await eventually { self.viewModel.sections.contains { $0.id == .event } }
        XCTAssertTrue(backAgain)
    }

    func testDayAndTimeFiltersAreInertForNonEventScopes() async {
        viewModel.scope = .art
        viewModel.filter.day = Date(timeIntervalSince1970: 0)
        viewModel.filter.timeOfDay = .lateNight
        viewModel.searchText = "Burning"

        let hasResults = await eventually { !self.viewModel.sections.isEmpty }
        XCTAssertTrue(hasResults, "Event-only knobs should not touch art")
        XCTAssertEqual(viewModel.sections.map(\.id), [.art])
    }

    func testDayOrTimeFilterMarksFilterActive() {
        XCTAssertTrue(viewModel.filter.isDefault)
        viewModel.filter.timeOfDay = .evening
        XCTAssertFalse(viewModel.filter.isDefault, "Filter button should read as active")
    }

    // MARK: - AI Search Integration Tests

    func testInitialStateHasNoAISuggestions() {
        XCTAssertTrue(viewModel.aiSuggestedUIDs.isEmpty)
        XCTAssertFalse(viewModel.isAISearching)
    }

    func testAISearchNotAvailableWithoutService() {
        // Default viewModel has no AI service
        XCTAssertFalse(viewModel.isAISearchAvailable)
    }

    func testViewModelWithMockAIService() async {
        let mockAI = MockAISearchService(results: [
            AISearchResult(uid: "ai-uid-1", reason: "semantically relevant")
        ])
        let vm = GlobalSearchViewModel(playaDB: playaDB, aiSearchService: mockAI, filterStorageKey: nil, isAISearchFlagEnabled: true)

        XCTAssertTrue(vm.isAISearchAvailable)

        // Search should trigger FTS5 + AI
        vm.searchText = "Burning"

        // FTS5 results should appear
        let hasResults = await eventually { !vm.sections.isEmpty }
        XCTAssertTrue(hasResults, "Should have FTS5 results")

        // AI search runs but the mock UID won't resolve to a real object,
        // so aiSuggestedUIDs should be populated but no extra items merged
        let aiDone = await eventually { !vm.isAISearching }
        XCTAssertTrue(aiDone, "AI search should complete")
    }

    func testClearSearchClearsAISuggestions() async {
        let mockAI = MockAISearchService(results: [
            AISearchResult(uid: "ai-uid-1", reason: "test")
        ])
        let vm = GlobalSearchViewModel(playaDB: playaDB, aiSearchService: mockAI, filterStorageKey: nil, isAISearchFlagEnabled: true)

        vm.searchText = "Burning"
        let hasResults = await eventually { !vm.sections.isEmpty }
        XCTAssertTrue(hasResults)

        vm.searchText = ""
        let cleared = await eventually { vm.aiSuggestedUIDs.isEmpty }
        XCTAssertTrue(cleared, "Clearing search should clear AI suggestions")
    }

    func testOnlyFavoritesDisablesAISearch() {
        let mockAI = MockAISearchService(results: [])
        let vm = GlobalSearchViewModel(playaDB: playaDB, aiSearchService: mockAI, filterStorageKey: nil, isAISearchFlagEnabled: true)

        XCTAssertTrue(vm.isAISearchEnabled)

        // The model can't see local favorite state, so it can't answer this query.
        vm.filter.onlyFavorites = true
        XCTAssertFalse(vm.isAISearchEnabled)
    }

    /// The shipping default: an available service still yields no AI pass, which is what
    /// keeps the "Finding more with AI…" row and the sparkles badges off screen.
    func testFeatureFlagOffDisablesAISearchEvenWithAService() {
        let mockAI = MockAISearchService(results: [
            AISearchResult(uid: "ai-uid-1", reason: "would have merged")
        ])
        let vm = GlobalSearchViewModel(playaDB: playaDB, aiSearchService: mockAI, filterStorageKey: nil, isAISearchFlagEnabled: false)

        XCTAssertFalse(vm.isAISearchAvailable)
        XCTAssertFalse(vm.isAISearchEnabled)
    }

    func testFeatureFlagOffLeavesResultsFreeOfAISuggestions() async {
        let mockAI = MockAISearchService(results: [
            AISearchResult(uid: "ai-uid-1", reason: "would have merged")
        ])
        let vm = GlobalSearchViewModel(playaDB: playaDB, aiSearchService: mockAI, filterStorageKey: nil, isAISearchFlagEnabled: false)

        vm.searchText = "Burning"
        let hasResults = await eventually { !vm.sections.isEmpty }
        XCTAssertTrue(hasResults, "FTS5 results should still arrive")

        XCTAssertFalse(vm.isAISearching, "No spinner row without the flag")
        XCTAssertTrue(vm.aiSuggestedUIDs.isEmpty, "No sparkles badges without the flag")
    }
}

// MARK: - Mock AI Search Service

private final class MockAISearchService: AISearchService, @unchecked Sendable {
    let results: [AISearchResult]
    var isAvailable: Bool = true

    init(results: [AISearchResult]) {
        self.results = results
    }

    func search(_ query: String) async throws -> [AISearchResult] {
        // Small delay to simulate model inference
        try? await Task.sleep(nanoseconds: 100_000_000)
        return results
    }
}
