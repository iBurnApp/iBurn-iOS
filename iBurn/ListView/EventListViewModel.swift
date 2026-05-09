import CoreLocation
import Dispatch
import Foundation
import PlayaDB

@MainActor
final class EventListViewModel: ObservableObject {

    enum Mode: Equatable {
        case browse
        case search(String)
    }

    // MARK: - Published

    /// Sections for browse mode (search empty). Ordered ascending by hour.
    @Published var browseSections: [EventHourSection] = []

    /// Flat results for search mode (FTS). Empty when not searching.
    @Published var searchResults: [ListRow<EventObjectOccurrence>] = []

    @Published var filter: EventFilter {
        didSet {
            saveFilter()
            restartObservation()
        }
    }

    @Published var searchText: String = "" {
        didSet { restartObservation() }
    }

    @Published var isLoading: Bool = true
    @Published var currentLocation: CLLocation?

    /// Currently selected day (drives day-scoped browse observation)
    @Published var selectedDay: Date {
        didSet { restartObservation() }
    }

    /// Current time, updated every 60s for status indicators
    @Published var now: Date = .present

    /// Browse vs. search; derived from `searchText`.
    var mode: Mode { searchText.isEmpty ? .browse : .search(searchText) }

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

        restartObservation()
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

    func distanceAttributedString(for object: EventObjectOccurrence) -> AttributedString? {
        dataProvider.distanceAttributedString(from: currentLocation, to: object)
    }

    /// Flat list of all currently visible rows (sections flattened in browse mode).
    /// Used by the hosting controller for detail-paging order.
    var visibleRows: [ListRow<EventObjectOccurrence>] {
        switch mode {
        case .browse:
            return browseSections.flatMap { $0.rows }
        case .search:
            return searchResults
        }
    }

    /// Flat list of all currently visible event objects, for the "Show map" action.
    var visibleObjects: [EventObjectOccurrence] {
        visibleRows.map(\.object)
    }

    var isEmpty: Bool {
        switch mode {
        case .browse: return browseSections.isEmpty
        case .search: return searchResults.isEmpty
        }
    }

    // MARK: - Actions

    /// Toggle favorite. The DB observation re-emits the updated rows;
    /// no optimistic in-memory mutation here.
    func toggleFavorite(_ row: ListRow<EventObjectOccurrence>) async {
        do {
            try await dataProvider.toggleFavorite(row.object)
        } catch {
            print("Error toggling favorite for \(row.object.name): \(error)")
        }
    }

    // MARK: - Observation

    /// Browse mode filter: user filters + day-scoped date range, no searchText.
    private func browseFilter() -> EventFilter {
        var f = filter
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDay)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        f.startDate = startOfDay
        f.endDate = endOfDay
        f.searchText = nil
        return f
    }

    /// Search mode filter: user filters + searchText, all days (no date scope).
    private func searchFilter(query: String) -> EventFilter {
        var f = filter
        f.startDate = nil
        f.endDate = nil
        f.searchText = query
        return f
    }

    private func restartObservation() {
        observationTask?.cancel()
        loadingGateTask?.cancel()
        isLoading = true

        switch mode {
        case .browse:
            searchResults = []
            let f = browseFilter()
            observationTask = Task { [weak self] in
                guard let self else { return }
                var didReceiveFirstEmission = false
                for await sections in self.dataProvider.observeObjectsByHour(filter: f) {
                    didReceiveFirstEmission = true
                    await MainActor.run {
                        self.browseSections = sections
                        if !sections.isEmpty {
                            self.isLoading = false
                        }
                    }
                    if didReceiveFirstEmission, !sections.isEmpty {
                        await MainActor.run { self.loadingGateTask?.cancel() }
                    } else if didReceiveFirstEmission, sections.isEmpty {
                        startLoadingGateIfNeeded()
                    }
                }
            }

        case .search(let query):
            browseSections = []
            let f = searchFilter(query: query)
            observationTask = Task { [weak self] in
                guard let self else { return }
                for await rows in self.dataProvider.observeObjects(filter: f) {
                    await MainActor.run {
                        self.searchResults = rows
                        self.isLoading = false
                    }
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
        // Don't persist startDate/endDate (those come from selectedDay) or searchText.
        var persistFilter = filter
        persistFilter.startDate = nil
        persistFilter.endDate = nil
        persistFilter.searchText = nil
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
