import CoreLocation
import Foundation
import PlayaDB

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    // MARK: - Published

    @Published var searchText: String = "" {
        didSet { runSearch(debounced: true) }
    }

    /// Data-type scope. Session-only: a scope narrow enough to hide most of the city
    /// shouldn't outlive the search it was chosen for.
    @Published var scope: GlobalSearchScope = .all {
        didSet {
            guard oldValue != scope else { return }
            runSearch(debounced: false)
        }
    }

    @Published var filter: GlobalSearchFilter {
        didSet {
            guard oldValue != filter else { return }
            saveFilter()
            runSearch(debounced: false)
        }
    }

    /// Whether the filter sheet is up. Lives on the view model because the control that
    /// opens it isn't always in the SwiftUI view — the search tab puts it on its
    /// navigation bar, where the app's other list screens keep their filter buttons.
    @Published var isShowingFilters: Bool = false

    @Published var sections: [SearchResultSection] = []
    @Published var isSearching: Bool = false

    /// Favorite state for the rows currently on screen, keyed by
    /// `SearchResultItem.favoriteIdentity` (an `EventFavoriteKey` composite for event
    /// occurrences, since event favorites are per showing).
    ///
    /// Kept beside `sections` rather than baked into the items: results are plain objects
    /// from one-shot fetches, and a set is what both the DB lookup and the optimistic
    /// toggle write to.
    @Published private(set) var favoriteIdentifiers: Set<String> = []

    /// UIDs of results that came from AI semantic search (not FTS5)
    @Published var aiSuggestedUIDs: Set<String> = []

    /// Whether AI search is currently running (FTS5 results already shown)
    @Published var isAISearching: Bool = false

    /// Latest user fix, so search rows can carry the same walk/bike estimate the list
    /// screens do. Without it every result rendered a distance-less row, which read as a
    /// different (and worse) answer to the same question the Camps list had just answered.
    @Published var currentLocation: CLLocation?

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let aiSearchService: AISearchService?
    private let favoriteSync: FavoriteSyncService
    /// `nil` in the contexts that have no location plumbing (previews, most tests); rows
    /// then simply carry no distance.
    private let locationProvider: LocationProvider?
    /// `nil` opts out of persistence entirely (previews, tests).
    private let filterStorageKey: String?
    /// Snapshot of `Preferences.FeatureFlags.useAISearch`, taken once so a screen can't
    /// change its mind mid-session — and injectable so the AI tests can exercise the merge
    /// without writing to the shared defaults the app reads.
    private let isAISearchFlagEnabled: Bool

    // MARK: - Tasks

    private var searchTask: Task<Void, Never>?
    private var favoriteTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?

    // MARK: - Init

    init(
        playaDB: PlayaDB,
        aiSearchService: AISearchService? = nil,
        favoriteSync: FavoriteSyncService = FavoriteSyncServiceFactory.shared,
        locationProvider: LocationProvider? = nil,
        filterStorageKey: String? = "globalSearchFilter",
        isAISearchFlagEnabled: Bool = PreferenceServiceFactory.shared.getValue(Preferences.FeatureFlags.useAISearch)
    ) {
        self.playaDB = playaDB
        self.aiSearchService = aiSearchService
        self.favoriteSync = favoriteSync
        self.locationProvider = locationProvider
        self.filterStorageKey = filterStorageKey
        self.isAISearchFlagEnabled = isAISearchFlagEnabled
        self.filter = filterStorageKey.flatMap(Self.loadFilter(key:)) ?? GlobalSearchFilter()
        self.currentLocation = locationProvider?.currentLocation
        startLocationUpdates()
    }

    deinit {
        searchTask?.cancel()
        favoriteTask?.cancel()
        locationTask?.cancel()
    }

    // MARK: - Location

    private func startLocationUpdates() {
        guard locationProvider != nil else { return }
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self, let stream = self.locationProvider?.locationStream else { return }
            for await location in stream {
                await MainActor.run {
                    self.currentLocation = location
                }
            }
        }
    }

    /// Walk/bike estimate for a result row, matching the list screens exactly.
    ///
    /// `nil` — no distance fragment at all — whenever there is no fix, no placement, or the
    /// item's embargo tier still hides its coordinates. See `PlayaDistanceString`.
    func distanceAttributedString(for item: SearchResultItem) -> AttributedString? {
        PlayaDistanceString.make(
            from: currentLocation,
            to: item.location,
            canShowLocation: item.canShowLocation
        )
    }

    /// Whether AI-enhanced search is available on this device.
    ///
    /// Gated on `Preferences.FeatureFlags.useAISearch`, which ships off — the merge doesn't
    /// return useful results yet, and checking the flag here (rather than at the call site)
    /// is what keeps the fetch, the "Finding more with AI…" row, and the per-row sparkles
    /// badge all off together: with the flag down `runAISearch` never runs, so
    /// `isAISearching` stays false and `aiSuggestedUIDs` stays empty.
    var isAISearchAvailable: Bool {
        isAISearchFlagEnabled && aiSearchService?.isAvailable == true
    }

    /// AI results are ranked by the model, which has no view of local favorite state,
    /// so a favorites-only search can only be answered from the database.
    var isAISearchEnabled: Bool {
        isAISearchAvailable && !filter.onlyFavorites
    }

    /// Event rows carry an occurrence-scoped uid (`event.uid_occurrenceId`) while AI
    /// results are keyed by the parent event uid, so the badge has to check both.
    func isAISuggested(_ item: SearchResultItem) -> Bool {
        switch item {
        case .event(let occurrence):
            aiSuggestedUIDs.contains(occurrence.event.uid) || aiSuggestedUIDs.contains(occurrence.uid)
        default:
            aiSuggestedUIDs.contains(item.uid)
        }
    }

    // MARK: - Search

    /// - Parameter debounced: typing debounces; flipping scope or a filter re-runs at once.
    private func runSearch(debounced: Bool) {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= 2 else {
            sections = []
            favoriteIdentifiers = []
            aiSuggestedUIDs = []
            isSearching = false
            isAISearching = false
            return
        }

        isSearching = true
        aiSuggestedUIDs = []

        let scope = self.scope
        let filter = self.filter
        let runAI = isAISearchEnabled

        searchTask = Task { [weak self] in
            if debounced {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
            }

            guard let self else { return }

            do {
                let results = try await self.fetchResults(query: query, scope: scope, filter: filter)
                guard !Task.isCancelled else { return }

                self.sections = results.sections
                self.isSearching = false
                await self.refreshFavorites()
                guard !Task.isCancelled else { return }

                if runAI {
                    await self.runAISearch(
                        query: query,
                        ftsUIDs: results.matchedUIDs,
                        scope: scope,
                        filter: filter
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.sections = []
                self.favoriteIdentifiers = []
                self.isSearching = false
                print("Search error: \(error)")
            }
        }
    }

    /// Per-type filtered fetches, skipping any table the scope excludes.
    ///
    /// `matchedUIDs` is keyed by *object* uid (the parent event uid for events) because
    /// that's the identifier the AI service returns.
    private func fetchResults(
        query: String,
        scope: GlobalSearchScope,
        filter: GlobalSearchFilter
    ) async throws -> (sections: [SearchResultSection], matchedUIDs: Set<String>) {
        var sections: [SearchResultSection] = []
        var matchedUIDs: Set<String> = []

        if scope.allows(.art) {
            let art = try await playaDB.fetchArt(
                filter: ArtFilter(searchText: query, onlyFavorites: filter.onlyFavorites)
            )
            matchedUIDs.formUnion(art.map(\.uid))
            if !art.isEmpty {
                sections.append(SearchResultSection(
                    id: .art,
                    title: "Art",
                    items: Self.sortedByName(art.map(SearchResultItem.art))
                ))
            }
        }

        if scope.allows(.camp) {
            let camps = try await playaDB.fetchCamps(
                filter: CampFilter(searchText: query, onlyFavorites: filter.onlyFavorites)
            )
            matchedUIDs.formUnion(camps.map(\.uid))
            if !camps.isEmpty {
                sections.append(SearchResultSection(
                    id: .camp,
                    title: "Camps",
                    items: Self.sortedByName(camps.map(SearchResultItem.camp))
                ))
            }
        }

        if scope.allows(.event) {
            let occurrences = try await playaDB.fetchEvents(
                filter: Self.eventFilter(query: query, filter: filter)
            )
            let deduped = Self.dedupedOccurrences(occurrences, filter: filter)
            matchedUIDs.formUnion(deduped.map(\.event.uid))
            if !deduped.isEmpty {
                sections.append(
                    SearchResultSection(id: .event, title: "Events", items: deduped.map(SearchResultItem.event))
                )
            }
        }

        if scope.allows(.mutantVehicle) {
            let vehicles = try await playaDB.fetchMutantVehicles(
                filter: MutantVehicleFilter(searchText: query, onlyFavorites: filter.onlyFavorites)
            )
            matchedUIDs.formUnion(vehicles.map(\.uid))
            if !vehicles.isEmpty {
                sections.append(
                    SearchResultSection(
                        id: .mutantVehicle,
                        title: "Vehicles",
                        items: Self.sortedByName(vehicles.map(SearchResultItem.mutantVehicle))
                    )
                )
            }
        }

        return (sections, matchedUIDs)
    }

    /// Case- and diacritic-insensitive, numeric-aware name order.
    ///
    /// PlayaDB already returns art / camps / vehicles `orderedByName()`, but that is
    /// SQLite's binary collation: "Zoo" sorts before "aardvark", and a lowercase or
    /// accented initial would put a second "A" run below "Z". The results index rail reads
    /// as a monotonic A→Z only if the rows underneath it actually are, so the order is
    /// normalized here rather than trusted from SQL.
    nonisolated static func sortedByName(_ items: [SearchResultItem]) -> [SearchResultItem] {
        items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Event Filtering

    /// SQL-level event filter for the current query and knobs. The day picker narrows
    /// here (`startDate`/`endDate` bound the occurrence's *start*, i.e. calendar-day
    /// bucketing, same as `EventFilter.forDay(_:)`); the time-of-day band does not,
    /// because it is an hour-of-day predicate that no single date range can express once
    /// "any day" is selected.
    nonisolated static func eventFilter(query: String, filter: GlobalSearchFilter) -> EventFilter {
        let bounds = filter.dayBounds
        return EventFilter(
            searchText: query,
            onlyFavorites: filter.onlyFavorites,
            includeExpired: true,
            happeningNow: filter.happeningNow,
            startDate: bounds?.start,
            endDate: bounds?.end
        )
    }

    /// One row per event, matching the previous `EventObject` → first-occurrence display.
    ///
    /// The time-of-day band is applied to the occurrences *before* collapsing, so an event
    /// that runs daily at both 9am and 11pm is represented by its 11pm occurrence under
    /// "Late night" rather than being dropped because its earliest occurrence is a morning
    /// one. The fetch is ordered by start time, so "first seen" is the earliest occurrence
    /// that matches.
    nonisolated static func dedupedOccurrences(
        _ occurrences: [EventObjectOccurrence],
        filter: GlobalSearchFilter,
        calendar: Calendar = .current
    ) -> [EventObjectOccurrence] {
        var seenEventUIDs: Set<String> = []
        return occurrences
            .filter { filter.timeOfDay.contains($0.startDate, calendar: calendar) }
            .filter { seenEventUIDs.insert($0.event.uid).inserted }
    }

    // MARK: - Favorites

    /// Whether this row's object is favorited — for an event row, the specific showing
    /// the row is standing in for.
    func isFavorite(_ item: SearchResultItem) -> Bool {
        favoriteIdentifiers.contains(item.favoriteIdentity)
    }

    /// Flip the favorite state of a search result.
    ///
    /// The row state is flipped up front rather than waiting for the write to land. Screens
    /// backed by a GRDB observation let the stream deliver the new state, but these results
    /// come from one-shot fetches with no observation behind them — without an optimistic
    /// flip the heart wouldn't change until the next search. The database is still the
    /// source of truth: the write is re-read on failure, and every re-run of the search
    /// re-syncs the whole set from `favoriteIdentifiers(among:)`.
    func toggleFavorite(_ item: SearchResultItem) {
        let key = item.favoriteIdentity
        let wasFavorite = favoriteIdentifiers.contains(key)
        setFavoriteState(!wasFavorite, for: key)

        let object = item.dataObject
        let syncType = Self.syncType(for: item)
        let syncUID = key

        favoriteTask?.cancel()
        favoriteTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.playaDB.toggleFavorite(object)
                let isFavorite = try await self.playaDB.isFavorite(object)
                self.setFavoriteState(isFavorite, for: key)
                // Fire-and-forget mirror into legacy YapDatabase, matching the list
                // screens' data providers. PlayaDB is the source of truth and the UI
                // must not wait on the Yap write.
                let favoriteSync = self.favoriteSync
                Task {
                    await favoriteSync.mirrorFavorite(type: syncType, uid: syncUID, isFavorite: isFavorite)
                }
            } catch {
                // Put the heart back where the database says it belongs.
                self.setFavoriteState(wasFavorite, for: key)
                print("Search favorite toggle error: \(error)")
            }
        }
    }

    private func setFavoriteState(_ isFavorite: Bool, for key: String) {
        if isFavorite {
            favoriteIdentifiers.insert(key)
        } else {
            favoriteIdentifiers.remove(key)
        }
    }

    /// Re-read favorite state for everything currently listed. Cheap — one indexed query
    /// per type present — and it picks up favorites toggled on other screens.
    private func refreshFavorites() async {
        let objects = sections.flatMap(\.items).map(\.dataObject)
        guard !objects.isEmpty else {
            favoriteIdentifiers = []
            return
        }
        do {
            favoriteIdentifiers = try await playaDB.favoriteIdentifiers(among: objects)
        } catch {
            print("Search favorite lookup error: \(error)")
        }
    }

    private static func syncType(for item: SearchResultItem) -> FavoriteSyncObjectType {
        switch item {
        case .art: .art
        case .camp: .camp
        case .event: .event
        case .mutantVehicle: .mutantVehicle
        }
    }

    /// Run AI search and merge any new results not found by FTS5
    private func runAISearch(
        query: String,
        ftsUIDs: Set<String>,
        scope: GlobalSearchScope,
        filter: GlobalSearchFilter
    ) async {
        guard let aiService = aiSearchService else { return }
        guard !Task.isCancelled else { return }

        isAISearching = true

        do {
            let aiResults = try await aiService.search(query)
            guard !Task.isCancelled else { return }

            // Find UIDs that AI found but FTS5 missed
            let newUIDs = aiResults.map(\.uid).filter { !ftsUIDs.contains($0) }

            guard !newUIDs.isEmpty else {
                isAISearching = false
                return
            }

            // Fetch the actual objects for these UIDs and build SearchResultItems
            var newItems: [SearchResultItem] = []
            var resolvedUIDs: Set<String> = []
            for uid in newUIDs {
                if scope.allows(.art), let art = try? await playaDB.fetchArt(uid: uid) {
                    newItems.append(.art(art))
                    resolvedUIDs.insert(uid)
                } else if scope.allows(.camp), let camp = try? await playaDB.fetchCamp(uid: uid) {
                    newItems.append(.camp(camp))
                    resolvedUIDs.insert(uid)
                } else if scope.allows(.event),
                          let occurrences = try? await playaDB.fetchOccurrences(forEventUID: uid),
                          let occurrence = pickOccurrence(from: occurrences, filter: filter) {
                    newItems.append(.event(occurrence))
                    resolvedUIDs.insert(uid)
                } else if scope.allows(.mutantVehicle), let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                    newItems.append(.mutantVehicle(mv))
                    resolvedUIDs.insert(uid)
                }
            }
            guard !Task.isCancelled else { return }

            aiSuggestedUIDs = resolvedUIDs
            mergeAIResults(newItems)
            await refreshFavorites()
            isAISearching = false
        } catch {
            print("AI search error: \(error)")
            isAISearching = false
        }
    }

    /// AI results bypass the SQL filters, so the event-scoped knobs are applied here: an
    /// event only survives if one of its occurrences satisfies all of them.
    private func pickOccurrence(
        from occurrences: [EventObjectOccurrence],
        filter: GlobalSearchFilter
    ) -> EventObjectOccurrence? {
        let now = Date()
        let bounds = filter.dayBounds
        return occurrences.first { occurrence in
            if filter.happeningNow && !occurrence.isCurrentlyHappening(now) { return false }
            if let bounds, occurrence.startDate < bounds.start || occurrence.startDate >= bounds.end {
                return false
            }
            return filter.timeOfDay.contains(occurrence.startDate)
        }
    }

    /// Merge AI-discovered items into existing sections
    private func mergeAIResults(_ newItems: [SearchResultItem]) {
        var artItems = sections.first(where: { $0.id == .art })?.items ?? []
        var campItems = sections.first(where: { $0.id == .camp })?.items ?? []
        var eventItems = sections.first(where: { $0.id == .event })?.items ?? []
        var mvItems = sections.first(where: { $0.id == .mutantVehicle })?.items ?? []

        for item in newItems {
            switch item {
            case .art: artItems.append(item)
            case .camp: campItems.append(item)
            case .event: eventItems.append(item)
            case .mutantVehicle: mvItems.append(item)
            }
        }

        // Re-sorted rather than appended: AI results land at the end of their section
        // otherwise, which would break the A→Z run the index rail is built from.
        var newSections: [SearchResultSection] = []
        if !artItems.isEmpty {
            newSections.append(SearchResultSection(id: .art, title: "Art", items: Self.sortedByName(artItems)))
        }
        if !campItems.isEmpty {
            newSections.append(SearchResultSection(id: .camp, title: "Camps", items: Self.sortedByName(campItems)))
        }
        if !eventItems.isEmpty {
            newSections.append(SearchResultSection(
                id: .event,
                title: "Events",
                items: eventItems.sorted { $0.startDate ?? .distantFuture < $1.startDate ?? .distantFuture }
            ))
        }
        if !mvItems.isEmpty {
            newSections.append(SearchResultSection(
                id: .mutantVehicle,
                title: "Vehicles",
                items: Self.sortedByName(mvItems)
            ))
        }
        self.sections = newSections
    }

    // MARK: - Filter Persistence

    private func saveFilter() {
        guard let filterStorageKey,
              let data = try? JSONEncoder().encode(filter) else { return }
        UserDefaults.standard.set(data, forKey: filterStorageKey)
    }

    private static func loadFilter(key: String) -> GlobalSearchFilter? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlobalSearchFilter.self, from: data)
    }
}
