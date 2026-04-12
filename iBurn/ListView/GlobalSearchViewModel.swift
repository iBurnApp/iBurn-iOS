import Foundation
import PlayaDB

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    // MARK: - Published

    @Published var searchText: String = "" {
        didSet { scheduleSearch() }
    }

    @Published var sections: [SearchResultSection] = []
    @Published var isSearching: Bool = false
    @Published private(set) var resolvedHosts: [String: ResolvedEventHost] = [:]

    /// UIDs of results that came from AI semantic search (not FTS5)
    @Published var aiSuggestedUIDs: Set<String> = []

    /// Whether AI search is currently running (FTS5 results already shown)
    @Published var isAISearching: Bool = false

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let aiSearchService: AISearchService?

    // MARK: - Tasks

    private var searchTask: Task<Void, Never>?
    private var aiSearchTask: Task<Void, Never>?

    // MARK: - Init

    init(playaDB: PlayaDB, aiSearchService: AISearchService? = nil) {
        self.playaDB = playaDB
        self.aiSearchService = aiSearchService
    }

    deinit {
        searchTask?.cancel()
        aiSearchTask?.cancel()
    }

    /// Whether AI-enhanced search is available on this device
    var isAISearchAvailable: Bool {
        aiSearchService?.isAvailable == true
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        aiSearchTask?.cancel()

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

        searchTask = Task { [weak self] in
            // Debounce 0.3 seconds
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            guard let self else { return }

            do {
                let results = try await self.playaDB.searchObjects(query)
                guard !Task.isCancelled else { return }

                let ftsUIDs = Set(results.map { $0.uid })

                let grouped = await self.groupResults(results)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.sections = grouped
                    self.isSearching = false
                }

                // Launch AI search in parallel if available
                if let aiService = self.aiSearchService, aiService.isAvailable {
                    await self.runAISearch(query: query, ftsUIDs: ftsUIDs)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.sections = []
                    self.isSearching = false
                }
                print("Search error: \(error)")
            }
        }
    }

    /// Run AI search and merge any new results not found by FTS5
    private func runAISearch(query: String, ftsUIDs: Set<String>) async {
        guard let aiService = aiSearchService else { return }
        guard !Task.isCancelled else { return }

        await MainActor.run { self.isAISearching = true }

        do {
            let aiResults = try await aiService.search(query)
            guard !Task.isCancelled else { return }

            // Find UIDs that AI found but FTS5 missed
            let newUIDs = aiResults.map(\.uid).filter { !ftsUIDs.contains($0) }

            if !newUIDs.isEmpty {
                // Fetch the actual objects for these UIDs and build SearchResultItems
                var newItems: [SearchResultItem] = []
                for uid in newUIDs {
                    if let art = try? await playaDB.fetchArt(uid: uid) {
                        newItems.append(.art(art))
                    } else if let camp = try? await playaDB.fetchCamp(uid: uid) {
                        newItems.append(.camp(camp))
                    } else if let occurrences = try? await playaDB.fetchOccurrences(forEventUID: uid),
                              let occurrence = occurrences.first {
                        newItems.append(.event(occurrence))
                    } else if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                        newItems.append(.mutantVehicle(mv))
                    }
                }

                await MainActor.run {
                    self.aiSuggestedUIDs = Set(newUIDs)
                    self.mergeAIResults(newItems)
                    self.isAISearching = false
                }
            } else {
                await MainActor.run { self.isAISearching = false }
            }
        } catch {
            print("AI search error: \(error)")
            await MainActor.run { self.isAISearching = false }
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

    // MARK: - Grouping

    /// Group search results into sections, resolving EventObject → EventObjectOccurrence
    private func groupResults(_ objects: [Any]) async -> [SearchResultSection] {
        var artItems: [SearchResultItem] = []
        var campItems: [SearchResultItem] = []
        var eventItems: [SearchResultItem] = []
        var mvItems: [SearchResultItem] = []

        for object in objects {
            if let art = object as? ArtObject {
                artItems.append(.art(art))
            } else if let camp = object as? CampObject {
                campItems.append(.camp(camp))
            } else if let event = object as? EventObject {
                // Resolve to first occurrence for display
                if let occurrences = try? await playaDB.fetchOccurrences(forEventUID: event.uid),
                   let occurrence = occurrences.first {
                    eventItems.append(.event(occurrence))
                }
            } else if let mv = object as? MutantVehicleObject {
                mvItems.append(.mutantVehicle(mv))
            }
        }

        var sections: [SearchResultSection] = []
        if !artItems.isEmpty {
            sections.append(SearchResultSection(id: .art, title: "Art", items: artItems))
        }
        if !campItems.isEmpty {
            sections.append(SearchResultSection(id: .camp, title: "Camps", items: campItems))
        }
        if !eventItems.isEmpty {
            sections.append(SearchResultSection(id: .event, title: "Events", items: eventItems))
        }
        if !mvItems.isEmpty {
            sections.append(SearchResultSection(id: .mutantVehicle, title: "Vehicles", items: mvItems))
        }
        return sections
    }

    // MARK: - Event Host Resolution

    func resolvedHost(for event: EventObjectOccurrence) -> ResolvedEventHost? {
        resolvedHosts[event.event.uid]
    }

    func resolveHosts(for events: [EventObjectOccurrence]) {
        let needsResolution = events.filter { resolvedHosts[$0.event.uid] == nil }
        guard !needsResolution.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            var newHosts: [String: ResolvedEventHost] = [:]

            for event in needsResolution {
                let eventUID = event.event.uid
                if let campUID = event.event.hostedByCamp {
                    if let camp = try? await playaDB.fetchCamp(uid: campUID) {
                        newHosts[eventUID] = ResolvedEventHost(
                            name: camp.name,
                            address: camp.locationString,
                            description: camp.description,
                            thumbnailObjectID: campUID,
                            isArt: false
                        )
                    }
                } else if let artUID = event.event.locatedAtArt {
                    if let art = try? await playaDB.fetchArt(uid: artUID) {
                        newHosts[eventUID] = ResolvedEventHost(
                            name: art.name,
                            address: art.locationString ?? art.timeBasedAddress,
                            description: art.description,
                            thumbnailObjectID: artUID,
                            isArt: true
                        )
                    }
                }
            }

            await MainActor.run {
                self.resolvedHosts.merge(newHosts) { _, new in new }
            }
        }
    }
}
