import CoreLocation
import Foundation
import PlayaDB

@MainActor
final class RecentlyViewedViewModel: ObservableObject {
    // MARK: - Published

    @Published var items: [RecentlyViewedItem] = []
    @Published var favoriteIDs: Set<String> = []

    @Published var selectedTypeFilter: RecentlyViewedTypeFilter = .all
    @Published var sortOrder: RecentlyViewedSortOrder = .recentFirst
    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let locationProvider: LocationProvider

    // MARK: - Tasks

    private var loadTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?

    // MARK: - Init

    init(playaDB: PlayaDB, locationProvider: LocationProvider) {
        self.playaDB = playaDB
        self.locationProvider = locationProvider
        self.currentLocation = locationProvider.currentLocation

        loadData()
        startLocationUpdates()
    }

    deinit {
        loadTask?.cancel()
        locationTask?.cancel()
    }

    // MARK: - Computed Sections

    var sections: [RecentlyViewedSection] {
        let filter = selectedTypeFilter
        let sorted = sortedItems
        let q = searchText.lowercased()

        var result: [RecentlyViewedSection] = []

        if filter == .all || filter == .art {
            let items = sorted.filter { $0.typeFilter == .art }.filter { matchesSearch($0, q) }
            if !items.isEmpty {
                result.append(RecentlyViewedSection(id: .art, title: "Art", items: items))
            }
        }
        if filter == .all || filter == .camp {
            let items = sorted.filter { $0.typeFilter == .camp }.filter { matchesSearch($0, q) }
            if !items.isEmpty {
                result.append(RecentlyViewedSection(id: .camp, title: "Camps", items: items))
            }
        }
        if filter == .all || filter == .event {
            let items = sorted.filter { $0.typeFilter == .event }.filter { matchesSearch($0, q) }
            if !items.isEmpty {
                result.append(RecentlyViewedSection(id: .event, title: "Events", items: items))
            }
        }
        if filter == .all || filter == .mutantVehicle {
            let items = sorted.filter { $0.typeFilter == .mutantVehicle }.filter { matchesSearch($0, q) }
            if !items.isEmpty {
                result.append(RecentlyViewedSection(id: .mutantVehicle, title: "Vehicles", items: items))
            }
        }

        return result
    }

    var allItems: [RecentlyViewedItem] {
        sections.flatMap(\.items)
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    // MARK: - Sorting

    private var sortedItems: [RecentlyViewedItem] {
        switch sortOrder {
        case .recentFirst:
            return items.sorted { $0.lastViewed > $1.lastViewed }
        case .nearest:
            guard let location = currentLocation else {
                return items.sorted { $0.lastViewed > $1.lastViewed }
            }
            return items.sorted { a, b in
                let distA = a.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
                let distB = b.location.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude
                return distA < distB
            }
        }
    }

    // MARK: - Search

    private func matchesSearch(_ item: RecentlyViewedItem, _ q: String) -> Bool {
        guard !q.isEmpty else { return true }
        return item.name.lowercased().contains(q)
    }

    // MARK: - Distance

    func distanceString(for item: RecentlyViewedItem) -> String? {
        guard let location = currentLocation, let itemLoc = item.location else { return nil }
        let meters = location.distance(from: itemLoc)
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    // MARK: - Last Viewed Formatting

    func lastViewedString(for item: RecentlyViewedItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.lastViewed, relativeTo: Date())
    }

    // MARK: - Favorites

    func isFavorite(_ uid: String) -> Bool {
        favoriteIDs.contains(uid)
    }

    func toggleFavorite(_ item: RecentlyViewedItem) async {
        do {
            switch item {
            case .art(let o, _): try await playaDB.toggleFavorite(o)
            case .camp(let o, _): try await playaDB.toggleFavorite(o)
            case .event(let o, _): try await playaDB.toggleFavorite(o)
            case .mutantVehicle(let o, _): try await playaDB.toggleFavorite(o)
            }
            switch item {
            case .art(let o, _):
                let isFav = try await playaDB.isFavorite(o)
                if isFav { favoriteIDs.insert(item.uid) } else { favoriteIDs.remove(item.uid) }
            case .camp(let o, _):
                let isFav = try await playaDB.isFavorite(o)
                if isFav { favoriteIDs.insert(item.uid) } else { favoriteIDs.remove(item.uid) }
            case .event(let o, _):
                let isFav = try await playaDB.isFavorite(o)
                if isFav { favoriteIDs.insert(item.uid) } else { favoriteIDs.remove(item.uid) }
            case .mutantVehicle(let o, _):
                let isFav = try await playaDB.isFavorite(o)
                if isFav { favoriteIDs.insert(item.uid) } else { favoriteIDs.remove(item.uid) }
            }
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }

    // MARK: - Remove

    func removeItem(_ item: RecentlyViewedItem) async {
        do {
            switch item {
            case .art(let o, _): try await playaDB.clearLastViewed(for: o)
            case .camp(let o, _): try await playaDB.clearLastViewed(for: o)
            case .event(let o, _): try await playaDB.clearLastViewed(for: o)
            case .mutantVehicle(let o, _): try await playaDB.clearLastViewed(for: o)
            }
            items.removeAll { $0.uid == item.uid }
        } catch {
            print("Error removing recent: \(error)")
        }
    }

    func clearAll() async {
        do {
            try await playaDB.clearAllRecentlyViewed()
            items.removeAll()
        } catch {
            print("Error clearing recents: \(error)")
        }
    }

    // MARK: - Data Loading

    func loadData() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await playaDB.fetchRecentlyViewedWithDates(limit: 500)
                let mapped: [RecentlyViewedItem] = results.compactMap { pair in
                    let dates = ViewDates(firstViewed: pair.firstViewed, lastViewed: pair.lastViewed)
                    if let art = pair.object as? ArtObject {
                        return .art(art, dates)
                    } else if let camp = pair.object as? CampObject {
                        return .camp(camp, dates)
                    } else if let event = pair.object as? EventObject {
                        return .event(event, dates)
                    } else if let mv = pair.object as? MutantVehicleObject {
                        return .mutantVehicle(mv, dates)
                    }
                    return nil
                }

                // Batch load favorites
                let favorites = try await playaDB.getFavorites()
                let favUIDs = Set(favorites.map(\.uid))

                await MainActor.run {
                    self.items = mapped
                    self.favoriteIDs = favUIDs.intersection(Set(mapped.map(\.uid)))
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading recently viewed: \(error)")
            }
        }
    }

    // MARK: - Map

    var allAnnotations: [PlayaObjectAnnotation] {
        var annotations: [PlayaObjectAnnotation] = []
        for item in allItems {
            switch item {
            case .art(let o, _):
                if let a = PlayaObjectAnnotation(art: o) { annotations.append(a) }
            case .camp(let o, _):
                if let a = PlayaObjectAnnotation(camp: o) { annotations.append(a) }
            case .event(let o, _):
                if let a = PlayaObjectAnnotation(event: o) { annotations.append(a) }
            case .mutantVehicle:
                break
            }
        }
        return annotations
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
}
