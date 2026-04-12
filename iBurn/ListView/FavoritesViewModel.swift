import CoreLocation
import Dispatch
import Foundation
import PlayaDB

@MainActor
final class FavoritesViewModel: ObservableObject {
    // MARK: - Published

    @Published var artItems: [ListRow<ArtObject>] = []
    @Published var campItems: [ListRow<CampObject>] = []
    @Published var eventItems: [ListRow<EventObjectOccurrence>] = []
    @Published var mvItems: [ListRow<MutantVehicleObject>] = []

    @Published var selectedTypeFilter: FavoritesTypeFilter {
        didSet {
            UserSettings.favoritesTypeFilter = selectedTypeFilter
        }
    }

    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    /// Current time, updated every 60s for event status indicators
    @Published var now: Date = .present

    /// Resolved host data for events (event UID → host info)
    @Published private(set) var resolvedHosts: [String: ResolvedEventHost] = [:]

    // MARK: - Dependencies

    private let artProvider: ArtDataProvider
    private let campProvider: CampDataProvider
    private let eventProvider: EventDataProvider
    private let mvProvider: MutantVehicleDataProvider
    private let locationProvider: LocationProvider

    // MARK: - Tasks

    private var artTask: Task<Void, Never>?
    private var campTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var mvTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?

    /// Track which type streams have emitted at least once
    private var receivedFirstEmission: Set<String> = []

    // MARK: - Init

    init(
        artProvider: ArtDataProvider,
        campProvider: CampDataProvider,
        eventProvider: EventDataProvider,
        mvProvider: MutantVehicleDataProvider,
        locationProvider: LocationProvider
    ) {
        self.artProvider = artProvider
        self.campProvider = campProvider
        self.eventProvider = eventProvider
        self.mvProvider = mvProvider
        self.locationProvider = locationProvider

        self.selectedTypeFilter = UserSettings.favoritesTypeFilter
        self.currentLocation = locationProvider.currentLocation

        startAllObservations()
        startLocationUpdates()
        startRefreshTimer()
    }

    deinit {
        artTask?.cancel()
        campTask?.cancel()
        eventTask?.cancel()
        mvTask?.cancel()
        locationTask?.cancel()
        timerTask?.cancel()
        loadingGateTask?.cancel()
    }

    // MARK: - Computed Sections

    var sections: [FavoriteSection] {
        let filter = selectedTypeFilter
        let q = searchText.lowercased()

        var result: [FavoriteSection] = []

        if filter == .all || filter == .art {
            let items = filteredArt(q).map { FavoriteItem.art($0) }
            if !items.isEmpty {
                result.append(FavoriteSection(id: .art, title: "Art", items: items))
            }
        }
        if filter == .all || filter == .camp {
            let items = filteredCamps(q).map { FavoriteItem.camp($0) }
            if !items.isEmpty {
                result.append(FavoriteSection(id: .camp, title: "Camps", items: items))
            }
        }
        if filter == .all || filter == .event {
            let items = filteredEvents(q).map { FavoriteItem.event($0) }
            if !items.isEmpty {
                result.append(FavoriteSection(id: .event, title: "Events", items: items))
            }
        }
        if filter == .all || filter == .mutantVehicle {
            let items = filteredMVs(q).map { FavoriteItem.mutantVehicle($0) }
            if !items.isEmpty {
                result.append(FavoriteSection(id: .mutantVehicle, title: "Vehicles", items: items))
            }
        }

        return result
    }

    var allFavoriteItems: [FavoriteItem] {
        sections.flatMap(\.items)
    }

    var isEmpty: Bool {
        artItems.isEmpty && campItems.isEmpty && eventItems.isEmpty && mvItems.isEmpty
    }

    // MARK: - Search Filtering

    private func filteredArt(_ q: String) -> [ListRow<ArtObject>] {
        guard !q.isEmpty else { return artItems }
        return artItems.filter {
            $0.object.name.lowercased().contains(q) ||
            $0.object.description?.lowercased().contains(q) == true ||
            $0.object.artist?.lowercased().contains(q) == true
        }
    }

    private func filteredCamps(_ q: String) -> [ListRow<CampObject>] {
        guard !q.isEmpty else { return campItems }
        return campItems.filter {
            $0.object.name.lowercased().contains(q) ||
            $0.object.description?.lowercased().contains(q) == true ||
            $0.object.hometown?.lowercased().contains(q) == true
        }
    }

    private func filteredEvents(_ q: String) -> [ListRow<EventObjectOccurrence>] {
        guard !q.isEmpty else { return eventItems }
        return eventItems.filter {
            $0.object.name.lowercased().contains(q) ||
            $0.object.description?.lowercased().contains(q) == true ||
            $0.object.eventTypeLabel.lowercased().contains(q) == true
        }
    }

    private func filteredMVs(_ q: String) -> [ListRow<MutantVehicleObject>] {
        guard !q.isEmpty else { return mvItems }
        return mvItems.filter {
            $0.object.name.lowercased().contains(q) ||
            $0.object.description?.lowercased().contains(q) == true ||
            $0.object.artist?.lowercased().contains(q) == true
        }
    }

    // MARK: - Derived

    func isFavorite(_ uid: String) -> Bool {
        // Everything in the favorites view is favorited by definition
        true
    }

    func distanceAttributedString(for item: FavoriteItem) -> AttributedString? {
        switch item {
        case .art(let r): artProvider.distanceAttributedString(from: currentLocation, to: r.object)
        case .camp(let r): campProvider.distanceAttributedString(from: currentLocation, to: r.object)
        case .event(let r): eventProvider.distanceAttributedString(from: currentLocation, to: r.object)
        case .mutantVehicle: nil
        }
    }

    func resolvedHost(for event: EventObjectOccurrence) -> ResolvedEventHost? {
        resolvedHosts[event.event.uid]
    }

    func locationString(for event: EventObjectOccurrence) -> String? {
        if let resolved = resolvedHosts[event.event.uid] {
            return resolved.name
        }
        return event.event.hasOtherLocation ? event.event.otherLocation : nil
    }

    // MARK: - Actions

    func toggleFavorite(_ item: FavoriteItem) async {
        do {
            switch item {
            case .art(let r): try await artProvider.toggleFavorite(r.object)
            case .camp(let r): try await campProvider.toggleFavorite(r.object)
            case .event(let r): try await eventProvider.toggleFavorite(r.object)
            case .mutantVehicle(let r): try await mvProvider.toggleFavorite(r.object)
            }
        } catch {
            print("Error toggling favorite for \(item.name): \(error)")
        }
    }

    /// Called when the filter sheet changes event filter settings
    func reloadEventFilter() {
        startEventObservation()
    }

    // MARK: - Map

    var allAnnotations: [PlayaObjectAnnotation] {
        var annotations: [PlayaObjectAnnotation] = []
        for section in sections {
            for item in section.items {
                switch item {
                case .art(let r):
                    if let a = PlayaObjectAnnotation(art: r.object) { annotations.append(a) }
                case .camp(let r):
                    if let a = PlayaObjectAnnotation(camp: r.object) { annotations.append(a) }
                case .event(let r):
                    if let a = PlayaObjectAnnotation(event: r.object) { annotations.append(a) }
                case .mutantVehicle:
                    break // No location
                }
            }
        }
        return annotations
    }

    // MARK: - Observation

    private func startAllObservations() {
        receivedFirstEmission.removeAll()
        startArtObservation()
        startCampObservation()
        startEventObservation()
        startMVObservation()
    }

    private func startArtObservation() {
        artTask?.cancel()
        let filter = ArtFilter(onlyFavorites: true)
        artTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.artProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.artItems = items
                    self.markReceived("art")
                }
            }
        }
    }

    private func startCampObservation() {
        campTask?.cancel()
        let filter = CampFilter(onlyFavorites: true)
        campTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.campProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.campItems = items
                    self.markReceived("camp")
                }
            }
        }
    }

    private func startEventObservation() {
        eventTask?.cancel()
        var filter = EventFilter(onlyFavorites: true)
        filter.includeExpired = UserSettings.showExpiredEventsInFavorites

        if UserSettings.showTodayOnlyInFavorites {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: .present)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            filter.startDate = startOfDay
            filter.endDate = endOfDay
        }

        eventTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.eventProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.eventItems = items
                    self.markReceived("event")
                    self.resolveHosts(for: items.map(\.object))
                }
            }
        }
    }

    private func startMVObservation() {
        mvTask?.cancel()
        let filter = MutantVehicleFilter(onlyFavorites: true)
        mvTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.mvProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.mvItems = items
                    self.markReceived("mv")
                }
            }
        }
    }

    private func markReceived(_ key: String) {
        receivedFirstEmission.insert(key)
        if receivedFirstEmission.count >= 4 {
            isLoading = false
            loadingGateTask?.cancel()
        } else {
            startLoadingGateIfNeeded()
        }
    }

    private func startLoadingGateIfNeeded() {
        guard loadingGateTask == nil else { return }

        loadingGateTask = Task { [weak self] in
            let timeoutNanoseconds: UInt64 = 5_000_000_000
            let pollNanoseconds: UInt64 = 200_000_000
            let start = DispatchTime.now().uptimeNanoseconds

            while !Task.isCancelled {
                if await self?.artProvider.isDatabaseSeeded() == true {
                    await MainActor.run {
                        self?.isLoading = false
                    }
                    return
                }

                let elapsed = DispatchTime.now().uptimeNanoseconds - start
                if elapsed >= timeoutNanoseconds {
                    await MainActor.run {
                        self?.isLoading = false
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }
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

    // MARK: - Host Resolution

    private func resolveHosts(for events: [EventObjectOccurrence]) {
        let needsResolution = events.filter { event in
            let uid = event.event.uid
            if resolvedHosts[uid] != nil { return false }
            return event.event.isHostedByCamp || event.event.isLocatedAtArt
        }
        guard !needsResolution.isEmpty else { return }

        Task { [weak self, eventProvider] in
            guard let self else { return }
            var newHosts: [String: ResolvedEventHost] = [:]

            for event in needsResolution {
                let eventUID = event.event.uid
                if let campUID = event.event.hostedByCamp {
                    if let camp = try? await eventProvider.playaDB.fetchCamp(uid: campUID) {
                        newHosts[eventUID] = ResolvedEventHost(
                            name: camp.name,
                            address: camp.locationString,
                            description: camp.description,
                            thumbnailObjectID: campUID,
                            isArt: false
                        )
                    }
                } else if let artUID = event.event.locatedAtArt {
                    if let art = try? await eventProvider.playaDB.fetchArt(uid: artUID) {
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

            guard !newHosts.isEmpty else { return }
            await MainActor.run {
                self.resolvedHosts.merge(newHosts) { _, new in new }
            }
        }
    }
}
