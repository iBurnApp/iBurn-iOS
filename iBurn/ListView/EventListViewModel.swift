import CoreLocation
import Dispatch
import Foundation
import PlayaDB

/// Resolved host information for an event (camp or art installation).
struct ResolvedEventHost {
    let name: String
    let address: String?
    let description: String?
    let thumbnailObjectID: String?
    let isArt: Bool
}

@MainActor
final class EventListViewModel: ObservableObject {
    // MARK: - Published

    @Published var items: [ListRow<EventObjectOccurrence>] = []

    @Published var filter: EventFilter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?
    /// Resolved host data for events (event UID → host info)
    @Published private(set) var resolvedHosts: [String: ResolvedEventHost] = [:]

    /// Currently selected day (drives day-scoped observation)
    @Published var selectedDay: Date {
        didSet { restartObservation() }
    }

    /// Current time, updated every 60s for status indicators
    @Published var now: Date = .present

    // MARK: - Dependencies

    private let dataProvider: EventDataProvider
    private let locationProvider: LocationProvider
    private let filterStorageKey: String

    // MARK: - Public

    /// Festival days for the day picker
    let festivalDays: [Date]

    // MARK: - Tasks

    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(
        dataProvider: EventDataProvider,
        locationProvider: LocationProvider,
        filterStorageKey: String = "eventListFilter",
        festivalDays: [Date]
    ) {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.filterStorageKey = filterStorageKey
        self.festivalDays = festivalDays

        // Default to current day within the festival range
        self.selectedDay = YearSettings.dayWithinFestival(.present)

        // Load persisted filter or use sensible default (hide expired)
        self.filter = Self.loadFilter(key: filterStorageKey)
            ?? EventFilter(includeExpired: false)

        self.currentLocation = locationProvider.currentLocation

        startObserving()
        startLocationUpdates()
        startRefreshTimer()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        loadingGateTask?.cancel()
        timerTask?.cancel()
    }

    // MARK: - Derived

    func isFavorite(_ object: EventObjectOccurrence) -> Bool {
        items.first(where: { $0.object.uid == object.uid })?.isFavorite ?? false
    }

    func distanceAttributedString(for object: EventObjectOccurrence) -> AttributedString? {
        dataProvider.distanceAttributedString(from: currentLocation, to: object)
    }

    /// Returns the resolved host for an event, or nil if no host was resolved.
    func resolvedHost(for event: EventObjectOccurrence) -> ResolvedEventHost? {
        resolvedHosts[event.event.uid]
    }

    /// Returns the resolved location string for an event, or nil if no location.
    func locationString(for event: EventObjectOccurrence) -> String? {
        if let resolved = resolvedHosts[event.event.uid] {
            return resolved.name
        }
        return event.event.hasOtherLocation ? event.event.otherLocation : nil
    }

    var filteredItems: [ListRow<EventObjectOccurrence>] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.object.name.lowercased().contains(q) ||
            $0.object.description?.lowercased().contains(q) == true ||
            $0.object.eventTypeLabel.lowercased().contains(q) == true ||
            $0.object.hostedByCamp?.lowercased().contains(q) == true
        }
    }

    /// Items grouped by hour for sectioned display
    var groupedItems: [(header: String, items: [ListRow<EventObjectOccurrence>])] {
        let filtered = filteredItems
        guard !filtered.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { row -> Int in
            calendar.component(.hour, from: row.object.startDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (hour, rows) in
                let displayHour = hour % 12 == 0 ? 12 : hour % 12
                let ampm = hour >= 12 ? "PM" : "AM"
                return (header: "\(displayHour) \(ampm)", items: rows)
            }
    }

    // MARK: - Actions

    func toggleFavorite(_ row: ListRow<EventObjectOccurrence>) async {
        let originalRow = row
        if let idx = items.firstIndex(where: { $0.object.uid == row.object.uid }) {
            var updatedMeta = row.metadata
            updatedMeta?.isFavorite = !row.isFavorite
            items[idx] = ListRow(object: row.object, metadata: updatedMeta, thumbnailColors: row.thumbnailColors)
        }
        do {
            try await dataProvider.toggleFavorite(row.object)
        } catch {
            if let idx = items.firstIndex(where: { $0.object.uid == originalRow.object.uid }) {
                items[idx] = originalRow
            }
            print("Error toggling favorite for \(row.object.name): \(error)")
        }
    }

    // MARK: - Observation

    /// Build the effective filter by merging selectedDay into the user's filter
    private func effectiveFilter() -> EventFilter {
        var f = filter
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDay)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        f.startDate = startOfDay
        f.endDate = endOfDay
        return f
    }

    private func startObserving() {
        observationTask?.cancel()
        loadingGateTask?.cancel()

        isLoading = true
        let filterForObservation = effectiveFilter()

        observationTask = Task { [weak self] in
            guard let self else { return }

            var didReceiveFirstEmission = false
            for await rows in self.dataProvider.observeObjects(filter: filterForObservation) {
                didReceiveFirstEmission = true
                await MainActor.run {
                    self.items = rows
                    if !rows.isEmpty {
                        self.isLoading = false
                    }
                    self.resolveHosts(for: rows.map(\.object))
                }

                if didReceiveFirstEmission, !rows.isEmpty {
                    loadingGateTask?.cancel()
                } else if didReceiveFirstEmission, rows.isEmpty {
                    startLoadingGateIfNeeded()
                }
            }
        }
    }

    private func startLoadingGateIfNeeded() {
        guard loadingGateTask == nil else { return }

        loadingGateTask = Task { [weak self] in
            guard let self else { return }

            let timeoutNanoseconds: UInt64 = 5_000_000_000
            let pollNanoseconds: UInt64 = 200_000_000
            let start = DispatchTime.now().uptimeNanoseconds

            while !Task.isCancelled {
                if await self.dataProvider.isDatabaseSeeded() {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                let elapsed = DispatchTime.now().uptimeNanoseconds - start
                if elapsed >= timeoutNanoseconds {
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: pollNanoseconds)
            }
        }
    }

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

    private func restartObservation() {
        startObserving()
    }

    // MARK: - Host Resolution

    /// Resolve host camp/art data for events that reference them by UID.
    private func resolveHosts(for events: [EventObjectOccurrence]) {
        let needsResolution = events.filter { event in
            let uid = event.event.uid
            if resolvedHosts[uid] != nil { return false }
            return event.event.isHostedByCamp || event.event.isLocatedAtArt
        }
        guard !needsResolution.isEmpty else { return }

        Task { [weak self, dataProvider] in
            guard let self else { return }
            var newHosts: [String: ResolvedEventHost] = [:]

            for event in needsResolution {
                let eventUID = event.event.uid
                if let campUID = event.event.hostedByCamp {
                    if let camp = try? await dataProvider.playaDB.fetchCamp(uid: campUID) {
                        newHosts[eventUID] = ResolvedEventHost(
                            name: camp.name,
                            address: camp.locationString,
                            description: camp.description,
                            thumbnailObjectID: campUID,
                            isArt: false
                        )
                    }
                } else if let artUID = event.event.locatedAtArt {
                    if let art = try? await dataProvider.playaDB.fetchArt(uid: artUID) {
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

    // MARK: - Filter Persistence

    private func saveFilter() {
        // Don't persist startDate/endDate (those come from selectedDay)
        var persistFilter = filter
        persistFilter.startDate = nil
        persistFilter.endDate = nil
        guard let data = try? JSONEncoder().encode(persistFilter) else { return }
        UserDefaults.standard.set(data, forKey: filterStorageKey)
    }

    private static func loadFilter(key: String) -> EventFilter? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let filter = try? JSONDecoder().decode(EventFilter.self, from: data) else {
            return nil
        }
        return filter
    }
}
