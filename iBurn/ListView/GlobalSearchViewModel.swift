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

    // MARK: - Dependencies

    private let playaDB: PlayaDB

    // MARK: - Tasks

    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    deinit {
        searchTask?.cancel()
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard query.count >= 2 else {
            sections = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task { [weak self] in
            // Debounce 0.3 seconds
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            guard let self else { return }

            do {
                let results = try await self.playaDB.searchObjects(query)
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.sections = Self.groupResults(results)
                    self.isSearching = false
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

    // MARK: - Grouping

    private static func groupResults(_ objects: [Any]) -> [SearchResultSection] {
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
                eventItems.append(.event(event))
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
}
