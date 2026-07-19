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

    /// Full-festival browse results, bucketed by start-of-day then hour. Built once per
    /// filter/search change and re-emitted only when underlying data changes (favorites,
    /// imports). Day-tab switching is a pure in-memory dictionary lookup over this map —
    /// no observation restart, no DB hit.
    @Published private(set) var dayBuckets: [Date: [EventHourSection]] = [:]

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

    /// Currently selected day. Does NOT trigger an observation restart — the browse
    /// observation produces all days; the UI slices `dayBuckets` by this value.
    @Published var selectedDay: Date

    /// Current time, updated every 60s for status indicators
    @Published var now: Date = .present

    /// Browse vs. search; derived from `searchText`.
    var mode: Mode { searchText.isEmpty ? .browse : .search(searchText) }

    // MARK: - Dependencies

    private let dataProvider: EventDataProvider
    private let locationProvider: LocationProvider
    private let regionStatus: RegionStatusService
    private let filterStorageKey: String

    // MARK: - Public

    /// Festival days for the day picker
    let festivalDays: [Date]

    // MARK: - Tasks

    private var observationTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    /// Monotonic token identifying the current observation. Rapid filter changes (e.g.
    /// each tick of the duration slider) cancel-and-restart the observation many times in
    /// quick succession, but cancellation doesn't stop an emission already past its
    /// suspension point — a superseded observation can deliver AFTER the newest one,
    /// silently replacing fresh buckets with stale ones (rows the current filter
    /// excludes; their taps then fail showDetail's visibleRows guard). Emissions are
    /// dropped unless their generation is still current.
    private var observationGeneration = 0

    // MARK: - Init

    init(
        dataProvider: EventDataProvider,
        locationProvider: LocationProvider,
        regionStatus: RegionStatusService = RegionStatusServiceFactory.makeService(),
        filterStorageKey: String = "eventListFilter",
        festivalDays: [Date]
    ) {
        self.dataProvider = dataProvider
        self.locationProvider = locationProvider
        self.regionStatus = regionStatus
        self.filterStorageKey = filterStorageKey
        self.festivalDays = festivalDays

        // Default to current day within the festival range
        self.selectedDay = YearSettings.dayWithinFestival(.present)

        // Load persisted filter or use sensible default (hide expired). The max-duration
        // preference is stored under its own key and overlaid here so the 6h default applies
        // to fresh AND existing installs (see loadMaxDuration / StoredMaxDuration).
        var loadedFilter = Self.loadFilter(key: filterStorageKey)
            ?? EventFilter(includeExpired: false)
        loadedFilter.maxDuration = Self.loadMaxDuration(
            key: Self.durationStorageKey(for: filterStorageKey)
        )
        self.filter = loadedFilter

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

    /// Sections for the currently selected day — pure in-memory dict lookup.
    /// Returns `[]` for days the user hasn't generated content for.
    var browseSections: [EventHourSection] {
        let key = Calendar.current.startOfDay(for: selectedDay)
        return dayBuckets[key] ?? []
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

    /// Browse mode filter: user filters across the full festival. No day scoping (the UI
    /// slices `dayBuckets[selectedDay]` in memory) and no searchText.
    private func browseFilter() -> EventFilter {
        var f = filter
        f.startDate = nil
        f.endDate = nil
        f.searchText = nil
        return gatedForRegion(f)
    }

    /// Search mode filter: user filters + searchText, all days (no date scope).
    private func searchFilter(query: String) -> EventFilter {
        var f = filter
        f.startDate = nil
        f.endDate = nil
        f.searchText = query
        return gatedForRegion(f)
    }

    /// Legacy parity: hide "Mature Audiences" (`adlt`) events until the device has
    /// physically entered the Burning Man region, mirroring the YapDatabase gate in
    /// `BRCDatabaseManager.eventsFilteredByExpiration:eventTypes:artHostedOnly:`.
    /// Applied to the observation filter only — never persisted, and the filter
    /// sheet still reflects the user's own type selection.
    private func gatedForRegion(_ f: EventFilter) -> EventFilter {
        guard !regionStatus.hasEnteredBurningManRegion else { return f }
        return f.excludingAdultEvents()
    }

    private func restartObservation() {
        observationTask?.cancel()
        loadingGateTask?.cancel()
        isLoading = true
        observationGeneration += 1
        let generation = observationGeneration

        switch mode {
        case .browse:
            searchResults = []
            let f = browseFilter()
            observationTask = Task { [weak self] in
                guard let self else { return }
                for await bucket in self.dataProvider.observeObjectsByDayThenHour(filter: f) {
                    await MainActor.run {
                        guard self.observationGeneration == generation else { return }
                        self.dayBuckets = bucket
                        if !bucket.isEmpty {
                            self.isLoading = false
                            self.loadingGateTask?.cancel()
                        }
                    }
                    if bucket.isEmpty {
                        await MainActor.run {
                            guard self.observationGeneration == generation else { return }
                            self.startLoadingGateIfNeeded()
                        }
                    }
                }
            }

        case .search(let query):
            dayBuckets = [:]
            let f = searchFilter(query: query)
            observationTask = Task { [weak self] in
                guard let self else { return }
                for await rows in self.dataProvider.observeObjects(filter: f) {
                    await MainActor.run {
                        guard self.observationGeneration == generation else { return }
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

    // MARK: - Max Duration Preference

    /// Default max event-occurrence duration for the Events tab: hide occurrences longer
    /// than 6h (all-day / half-day "amenity listing" pseudo-events). Applied to fresh AND
    /// existing installs until the user chooses their own value.
    ///
    /// This default deliberately lives here — the Events-tab preference layer — and NOT in
    /// PlayaDB's `EventFilter`, whose package default stays `nil` (no limit) so other
    /// consumers (watch, Nearby / Right Now, detail screens) are unaffected.
    static let defaultMaxDuration: TimeInterval = 6 * 3600

    /// Persisted Events-tab duration choice. Stored under its own UserDefaults key rather
    /// than inside the EventFilter blob so "never chosen" (key absent → 6h default) stays
    /// distinct from "explicitly Any" (`.unlimited` → no limit). Synthesized Codable omits
    /// nil optionals, so a `nil` maxDuration inside the blob would be indistinguishable from
    /// a pre-existing install whose blob predates the field — collapsing both to the default.
    private enum StoredMaxDuration: Codable {
        case limited(TimeInterval)
        case unlimited
    }

    private static func durationStorageKey(for filterKey: String) -> String {
        "\(filterKey).maxDuration"
    }

    private static func loadMaxDuration(key: String) -> TimeInterval? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode(StoredMaxDuration.self, from: data) else {
            // Unset (fresh or pre-existing install) → apply the Events-tab default.
            return defaultMaxDuration
        }
        switch stored {
        case .limited(let seconds): return seconds
        case .unlimited: return nil
        }
    }

    private func saveMaxDuration(_ maxDuration: TimeInterval?) {
        let stored: StoredMaxDuration = maxDuration.map(StoredMaxDuration.limited) ?? .unlimited
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.durationStorageKey(for: filterStorageKey))
    }

    // MARK: - Filter Persistence

    private func saveFilter() {
        // Don't persist startDate/endDate (those come from selectedDay) or searchText.
        // maxDuration is persisted separately (see saveMaxDuration) so its "unset vs. Any"
        // distinction survives; strip it from the blob to keep a single source of truth.
        var persistFilter = filter
        persistFilter.startDate = nil
        persistFilter.endDate = nil
        persistFilter.searchText = nil
        persistFilter.maxDuration = nil
        if let data = try? JSONEncoder().encode(persistFilter) {
            UserDefaults.standard.set(data, forKey: filterStorageKey)
        }
        saveMaxDuration(filter.maxDuration)
    }

    private static func loadFilter(key: String) -> EventFilter? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let filter = try? JSONDecoder().decode(EventFilter.self, from: data) else {
            return nil
        }
        return filter
    }
}
