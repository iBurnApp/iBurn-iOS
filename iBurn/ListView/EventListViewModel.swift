import CoreLocation
import Dispatch
import Foundation
import PlayaDB

@MainActor
final class EventListViewModel: ObservableObject {
    // MARK: - Published

    @Published var items: [EventObjectOccurrence] = []

    @Published var filter: EventFilter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    @Published var searchText: String = ""
    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?
    @Published private(set) var favoriteIDs: Set<String> = []

    /// Resolved location names for events (event UID → display string)
    @Published private(set) var resolvedLocationNames: [String: String] = [:]

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
    private var favoritesObservationTask: Task<Void, Never>?
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
        startObservingFavorites()
        startLocationUpdates()
        startRefreshTimer()
    }

    deinit {
        observationTask?.cancel()
        locationTask?.cancel()
        favoritesObservationTask?.cancel()
        loadingGateTask?.cancel()
        timerTask?.cancel()
    }

    // MARK: - Derived

    func isFavorite(_ object: EventObjectOccurrence) -> Bool {
        // Favorites are stored per event UID, not per occurrence UID
        favoriteIDs.contains(object.event.uid)
    }

    func distanceAttributedString(for object: EventObjectOccurrence) -> AttributedString? {
        dataProvider.distanceAttributedString(from: currentLocation, to: object)
    }

    /// Returns the resolved location string for an event, or nil if no location.
    func locationString(for event: EventObjectOccurrence) -> String? {
        if let resolved = resolvedLocationNames[event.event.uid] {
            return resolved
        }
        return event.event.hasOtherLocation ? event.event.otherLocation : nil
    }

    var filteredItems: [EventObjectOccurrence] {
        guard !searchText.isEmpty else { return items }
        let q = searchText.lowercased()
        return items.filter {
            $0.name.lowercased().contains(q) ||
            $0.description?.lowercased().contains(q) == true ||
            $0.eventTypeLabel.lowercased().contains(q) == true ||
            $0.hostedByCamp?.lowercased().contains(q) == true
        }
    }

    /// Items grouped by hour for sectioned display
    var groupedItems: [(header: String, items: [EventObjectOccurrence])] {
        let filtered = filteredItems
        guard !filtered.isEmpty else { return [] }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { event -> Int in
            calendar.component(.hour, from: event.startDate)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (hour, events) in
                let displayHour = hour % 12 == 0 ? 12 : hour % 12
                let ampm = hour >= 12 ? "PM" : "AM"
                return (header: "\(displayHour) \(ampm)", items: events)
            }
    }

    // MARK: - Actions

    func toggleFavorite(_ object: EventObjectOccurrence) async {
        let eventUID = object.event.uid
        let desiredIsFavorite = !favoriteIDs.contains(eventUID)
        if desiredIsFavorite {
            favoriteIDs.insert(eventUID)
        } else {
            favoriteIDs.remove(eventUID)
        }
        do {
            try await dataProvider.toggleFavorite(object)
        } catch {
            // Revert optimistic UI if write fails.
            if desiredIsFavorite {
                favoriteIDs.remove(eventUID)
            } else {
                favoriteIDs.insert(eventUID)
            }
            print("Error toggling favorite for \(object.name): \(error)")
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
            for await observedItems in self.dataProvider.observeObjects(filter: filterForObservation) {
                didReceiveFirstEmission = true
                await MainActor.run {
                    self.items = observedItems
                    if !observedItems.isEmpty {
                        self.isLoading = false
                    }
                    self.resolveLocationNames(for: observedItems)
                }

                if didReceiveFirstEmission, !observedItems.isEmpty {
                    loadingGateTask?.cancel()
                } else if didReceiveFirstEmission, observedItems.isEmpty {
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
        startObservingFavorites()
    }

    // MARK: - Favorites

    private func startObservingFavorites() {
        favoritesObservationTask?.cancel()

        // Build a favorites-only filter (clears time/search constraints)
        var favFilter = filter
        favFilter.searchText = nil
        favFilter.happeningNow = false
        favFilter.includeExpired = true
        favFilter.startingWithinHours = nil
        favFilter.startDate = nil
        favFilter.endDate = nil
        favFilter.eventTypeCodes = nil
        favFilter.onlyFavorites = true

        favoritesObservationTask = Task { [weak self] in
            guard let self else { return }
            for await favorites in self.dataProvider.observeObjects(filter: favFilter) {
                // Map to event UIDs (not occurrence UIDs) since favorites are per-event
                let ids = Set(favorites.map(\.event.uid))
                await MainActor.run {
                    self.favoriteIDs = ids
                }
            }
        }
    }

    // MARK: - Location Resolution

    /// Resolve host camp/art names for events that reference them by UID.
    private func resolveLocationNames(for events: [EventObjectOccurrence]) {
        // Collect events that need resolution and aren't already cached
        let needsResolution = events.filter { event in
            let uid = event.event.uid
            if resolvedLocationNames[uid] != nil { return false }
            return event.event.isHostedByCamp || event.event.isLocatedAtArt
        }
        guard !needsResolution.isEmpty else { return }

        Task { [weak self, dataProvider] in
            guard let self else { return }
            var newNames: [String: String] = [:]

            for event in needsResolution {
                let eventUID = event.event.uid
                if let campUID = event.event.hostedByCamp {
                    if let camp = try? await dataProvider.playaDB.fetchCamp(uid: campUID) {
                        newNames[eventUID] = camp.name
                    }
                } else if let artUID = event.event.locatedAtArt {
                    if let art = try? await dataProvider.playaDB.fetchArt(uid: artUID) {
                        newNames[eventUID] = art.name
                    }
                }
            }

            guard !newNames.isEmpty else { return }
            await MainActor.run {
                self.resolvedLocationNames.merge(newNames) { _, new in new }
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
