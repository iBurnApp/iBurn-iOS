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

    @Published var sections: [SearchResultSection] = []
    @Published var isSearching: Bool = false

    /// UIDs of results that came from AI semantic search (not FTS5)
    @Published var aiSuggestedUIDs: Set<String> = []

    /// Whether AI search is currently running (FTS5 results already shown)
    @Published var isAISearching: Bool = false

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let aiSearchService: AISearchService?
    /// `nil` opts out of persistence entirely (previews, tests).
    private let filterStorageKey: String?

    // MARK: - Tasks

    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(
        playaDB: PlayaDB,
        aiSearchService: AISearchService? = nil,
        filterStorageKey: String? = "globalSearchFilter"
    ) {
        self.playaDB = playaDB
        self.aiSearchService = aiSearchService
        self.filterStorageKey = filterStorageKey
        self.filter = filterStorageKey.flatMap(Self.loadFilter(key:)) ?? GlobalSearchFilter()
    }

    deinit {
        searchTask?.cancel()
    }

    /// Whether AI-enhanced search is available on this device
    var isAISearchAvailable: Bool {
        aiSearchService?.isAvailable == true
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
                sections.append(SearchResultSection(id: .art, title: "Art", items: art.map(SearchResultItem.art)))
            }
        }

        if scope.allows(.camp) {
            let camps = try await playaDB.fetchCamps(
                filter: CampFilter(searchText: query, onlyFavorites: filter.onlyFavorites)
            )
            matchedUIDs.formUnion(camps.map(\.uid))
            if !camps.isEmpty {
                sections.append(SearchResultSection(id: .camp, title: "Camps", items: camps.map(SearchResultItem.camp)))
            }
        }

        if scope.allows(.event) {
            let occurrences = try await playaDB.fetchEvents(
                filter: EventFilter(
                    searchText: query,
                    onlyFavorites: filter.onlyFavorites,
                    includeExpired: true,
                    happeningNow: filter.happeningNow
                )
            )
            // One row per event, matching the previous EventObject → first-occurrence
            // display. The fetch is ordered by start time, so "first seen" is the
            // earliest matching occurrence.
            var seenEventUIDs: Set<String> = []
            let deduped = occurrences.filter { seenEventUIDs.insert($0.event.uid).inserted }
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
                        items: vehicles.map(SearchResultItem.mutantVehicle)
                    )
                )
            }
        }

        return (sections, matchedUIDs)
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
            isAISearching = false
        } catch {
            print("AI search error: \(error)")
            isAISearching = false
        }
    }

    /// AI results bypass the SQL filters, so the happening-now knob is applied here:
    /// an event only survives if one of its occurrences is running right now.
    private func pickOccurrence(
        from occurrences: [EventObjectOccurrence],
        filter: GlobalSearchFilter
    ) -> EventObjectOccurrence? {
        guard filter.happeningNow else { return occurrences.first }
        let now = Date()
        return occurrences.first { $0.isCurrentlyHappening(now) }
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

        var newSections: [SearchResultSection] = []
        if !artItems.isEmpty {
            newSections.append(SearchResultSection(id: .art, title: "Art", items: artItems))
        }
        if !campItems.isEmpty {
            newSections.append(SearchResultSection(id: .camp, title: "Camps", items: campItems))
        }
        if !eventItems.isEmpty {
            newSections.append(SearchResultSection(id: .event, title: "Events", items: eventItems))
        }
        if !mvItems.isEmpty {
            newSections.append(SearchResultSection(id: .mutantVehicle, title: "Vehicles", items: mvItems))
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
