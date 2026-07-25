//
//  VisitListViewModel.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import PlayaDB

// MARK: - Filter

/// Segmented control selection for the Visit List. Mirrors the legacy
/// `VisitFilter` used by `VisitListViewController` (All / Want to Visit / Visited).
/// The "unvisited" bucket is never shown, exactly like the legacy screen.
enum VisitListFilter: String, CaseIterable, Hashable {
    case all = "All"
    case wantToVisit = "Want to Visit"
    case visited = "Visited"

    /// The single status this filter shows, or nil when both sections are shown.
    var visitStatus: VisitStatus? {
        switch self {
        case .all: nil
        case .wantToVisit: .wantToVisit
        case .visited: .visited
        }
    }
}

// MARK: - Item

/// Type-safe wrapper for a visit-list object of any type.
enum VisitListItem: Identifiable {
    case art(ArtObject, VisitStatus)
    case camp(CampObject, VisitStatus)
    case event(EventObjectOccurrence, VisitStatus)
    case mutantVehicle(MutantVehicleObject, VisitStatus)

    var id: String { uid }

    /// Display identity. For events this is the occurrence uid ("<eventUID>_<occID>").
    var uid: String {
        switch self {
        case .art(let o, _): o.uid
        case .camp(let o, _): o.uid
        case .event(let o, _): o.uid
        case .mutantVehicle(let o, _): o.uid
        }
    }

    /// Metadata identity used for favorite/visit lookups. Event metadata is keyed by
    /// the parent event uid, never the synthesized per-occurrence uid.
    var favoriteKey: String {
        switch self {
        case .art(let o, _): o.uid
        case .camp(let o, _): o.uid
        case .event(let o, _): o.event.uid
        case .mutantVehicle(let o, _): o.uid
        }
    }

    var name: String {
        switch self {
        case .art(let o, _): o.name
        case .camp(let o, _): o.name
        case .event(let o, _): o.name
        case .mutantVehicle(let o, _): o.name
        }
    }

    var visitStatus: VisitStatus {
        switch self {
        case .art(_, let s): s
        case .camp(_, let s): s
        case .event(_, let s): s
        case .mutantVehicle(_, let s): s
        }
    }

    var location: CLLocation? {
        switch self {
        case .art(let o, _): o.location
        case .camp(let o, _): o.location
        case .event(let o, _): o.location
        case .mutantVehicle: nil
        }
    }

    var detailSubject: DetailSubject {
        switch self {
        case .art(let o, _): .art(o)
        case .camp(let o, _): .camp(o)
        case .event(let o, _): .eventOccurrence(o)
        case .mutantVehicle(let o, _): .mutantVehicle(o)
        }
    }

    var detailPageItem: DetailPageItem {
        DetailPageItem(subject: detailSubject)
    }

    var annotation: PlayaObjectAnnotation? {
        switch self {
        case .art(let o, _): PlayaObjectAnnotation(art: o)
        case .camp(let o, _): PlayaObjectAnnotation(camp: o)
        case .event(let o, _): PlayaObjectAnnotation(event: o)
        case .mutantVehicle: nil
        }
    }

    /// Lowercased haystack for the in-memory search filter.
    fileprivate var searchableText: [String?] {
        switch self {
        case .art(let o, _): [o.name, o.description, o.artist]
        case .camp(let o, _): [o.name, o.description, o.hometown, o.locationString]
        case .event(let o, _): [o.name, o.description, o.eventTypeLabel, o.hostName]
        case .mutantVehicle(let o, _): [o.name, o.description, o.artist, o.hometown]
        }
    }
}

// MARK: - Section

/// A section of visit-list items grouped by visit status.
struct VisitListSection: Identifiable {
    let id: VisitStatus
    let title: String
    let items: [VisitListItem]
}

// MARK: - View Model

/// View model for the SwiftUI/PlayaDB Visit List (More → Visit List).
///
/// PlayaDB has no reactive observation API for visit status, so this is a one-shot
/// fetch that reloads on appear (and when the app returns to the foreground, e.g.
/// after a watch sync applies a status change). Search filters in memory, matching
/// `FavoritesViewModel`/`RecentlyViewedViewModel`.
@MainActor
final class VisitListViewModel: ObservableObject {
    // MARK: - Published

    @Published private(set) var wantToVisitItems: [VisitListItem] = []
    @Published private(set) var visitedItems: [VisitListItem] = []
    @Published private(set) var favoriteKeys: Set<String> = []

    @Published var selectedFilter: VisitListFilter = .all
    @Published var searchText: String = ""
    @Published private(set) var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    /// Current time, updated every 60s for event status indicators
    @Published var now: Date = .present

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let artProvider: ArtDataProvider
    private let campProvider: CampDataProvider
    private let eventProvider: EventDataProvider
    private let mvProvider: MutantVehicleDataProvider
    private let locationProvider: LocationProvider

    // MARK: - Tasks

    private var loadTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(
        playaDB: PlayaDB,
        artProvider: ArtDataProvider,
        campProvider: CampDataProvider,
        eventProvider: EventDataProvider,
        mvProvider: MutantVehicleDataProvider,
        locationProvider: LocationProvider
    ) {
        self.playaDB = playaDB
        self.artProvider = artProvider
        self.campProvider = campProvider
        self.eventProvider = eventProvider
        self.mvProvider = mvProvider
        self.locationProvider = locationProvider
        self.currentLocation = locationProvider.currentLocation

        refresh()
        startLocationUpdates()
        startRefreshTimer()
    }

    deinit {
        loadTask?.cancel()
        locationTask?.cancel()
        timerTask?.cancel()
    }

    // MARK: - Computed Sections

    /// Sections in legacy order: Want to Visit, then Visited. Never an "unvisited" section.
    var sections: [VisitListSection] {
        let query = searchText.lowercased()
        var result: [VisitListSection] = []

        if selectedFilter != .visited {
            let items = wantToVisitItems.filter { matchesSearch($0, query) }
            if !items.isEmpty {
                result.append(VisitListSection(id: .wantToVisit, title: "⭐ Want to Visit", items: items))
            }
        }
        if selectedFilter != .wantToVisit {
            let items = visitedItems.filter { matchesSearch($0, query) }
            if !items.isEmpty {
                result.append(VisitListSection(id: .visited, title: "✅ Visited", items: items))
            }
        }

        return result
    }

    /// Every item currently listed, in display order (used for paged detail + map).
    var allItems: [VisitListItem] {
        sections.flatMap(\.items)
    }

    /// True when nothing has a visit status at all (independent of the segment/search).
    var isEmpty: Bool {
        wantToVisitItems.isEmpty && visitedItems.isEmpty
    }

    var allAnnotations: [PlayaObjectAnnotation] {
        allItems.compactMap(\.annotation)
    }

    // MARK: - Search

    private func matchesSearch(_ item: VisitListItem, _ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return item.searchableText.contains { $0?.lowercased().contains(query) == true }
    }

    // MARK: - Favorites

    func isFavorite(_ item: VisitListItem) -> Bool {
        favoriteKeys.contains(item.favoriteKey)
    }

    /// Toggles through the shared data providers so the legacy YapDatabase mirror
    /// (`FavoriteSyncService`) stays in agreement, exactly like the other SwiftUI lists.
    func toggleFavorite(_ item: VisitListItem) async {
        do {
            switch item {
            case .art(let o, _):
                try await artProvider.toggleFavorite(o)
                updateFavorite(item, isFavorite: try await playaDB.isFavorite(o))
            case .camp(let o, _):
                try await campProvider.toggleFavorite(o)
                updateFavorite(item, isFavorite: try await playaDB.isFavorite(o))
            case .event(let o, _):
                try await eventProvider.toggleFavorite(o)
                updateFavorite(item, isFavorite: try await playaDB.isFavorite(o))
            case .mutantVehicle(let o, _):
                try await mvProvider.toggleFavorite(o)
                updateFavorite(item, isFavorite: try await playaDB.isFavorite(o))
            }
        } catch {
            print("Error toggling favorite for \(item.name): \(error)")
        }
    }

    private func updateFavorite(_ item: VisitListItem, isFavorite: Bool) {
        if isFavorite {
            favoriteKeys.insert(item.favoriteKey)
        } else {
            favoriteKeys.remove(item.favoriteKey)
        }
    }

    // MARK: - Distance

    func distanceAttributedString(for item: VisitListItem) -> AttributedString? {
        switch item {
        case .art(let o, _): artProvider.distanceAttributedString(from: currentLocation, to: o)
        case .camp(let o, _): campProvider.distanceAttributedString(from: currentLocation, to: o)
        case .event(let o, _): eventProvider.distanceAttributedString(from: currentLocation, to: o)
        case .mutantVehicle: nil
        }
    }

    // MARK: - Data Loading

    /// Reloads visit status from PlayaDB. Fire-and-forget; safe to call repeatedly
    /// (each call cancels the in-flight load).
    func refresh() {
        loadTask?.cancel()
        loadTask = makeLoadTask()
    }

    /// Awaitable variant of `refresh()` for tests.
    func refreshAndWait() async {
        loadTask?.cancel()
        let task = makeLoadTask()
        loadTask = task
        await task.value
    }

    private func makeLoadTask() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }
            await self.load()
        }
    }

    private func load() async {
        do {
            let wantObjects = try await playaDB.fetchObjects(visitStatus: .wantToVisit)
            let visitedObjects = try await playaDB.fetchObjects(visitStatus: .visited)
            let want = try await makeItems(from: wantObjects, status: .wantToVisit)
            let visited = try await makeItems(from: visitedObjects, status: .visited)
            let favorites = try await playaDB.getFavorites()
            let favKeys = Set(favorites.map(\.uid))

            guard !Task.isCancelled else { return }
            wantToVisitItems = want
            visitedItems = visited
            favoriteKeys = favKeys
            isLoading = false
        } catch {
            print("Error loading visit list: \(error)")
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }

    /// Maps raw PlayaDB objects into display items, resolving events to their first
    /// occurrence (events with no occurrences are skipped) and sorting by name.
    ///
    /// Takes `[Any]` because PlayaDB's `DataObject` protocol is shadowed inside this
    /// module by the legacy `iBurn.DataObject` class and cannot be named here.
    private func makeItems(from objects: [Any], status: VisitStatus) async throws -> [VisitListItem] {
        var items: [VisitListItem] = []
        for object in objects {
            if let art = object as? ArtObject {
                items.append(.art(art, status))
            } else if let camp = object as? CampObject {
                items.append(.camp(camp, status))
            } else if let event = object as? EventObject {
                let occurrences = try await playaDB.fetchOccurrences(forEventUID: event.uid)
                if let occurrence = occurrences.first {
                    items.append(.event(occurrence, status))
                }
            } else if let mv = object as? MutantVehicleObject {
                items.append(.mutantVehicle(mv, status))
            }
        }
        return items.sorted {
            let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if comparison == .orderedSame { return $0.uid < $1.uid }
            return comparison == .orderedAscending
        }
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in self.locationProvider.locationStream {
                await MainActor.run {
                    self.currentLocation = location
                }
            }
        }
    }

    // MARK: - Refresh Timer

    private func startRefreshTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                guard let self else { return }
                await MainActor.run {
                    self.now = .present
                }
            }
        }
    }
}
