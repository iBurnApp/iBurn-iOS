import Combine
import CoreLocation
import Foundation
import MapKit
import PlayaDB

@MainActor
final class NearbyViewModel: ObservableObject {
    // MARK: - Published

    @Published var artItems: [ListRow<ArtObject>] = []
    @Published var campItems: [ListRow<CampObject>] = []
    @Published var eventItems: [ListRow<EventObjectOccurrence>] = []

    @Published var searchDistance: CLLocationDistance = 500 {
        didSet { restartObservations() }
    }

    @Published var selectedFilter: NearbyFilter = .all {
        didSet { UserSettings.nearbyFilter = selectedFilter }
    }

    @Published var timeShiftConfig: TimeShiftConfiguration? {
        didSet {
            UserSettings.nearbyTimeShiftConfig = timeShiftConfig
            // Most recent explicit action wins: warping to a *place* is the user asking to
            // look from there, so it retires an earlier dropped pin rather than being
            // silently outranked by it. Warping in time only leaves the pin alone.
            if timeShiftConfig?.location != nil {
                sourceLocationOverride = nil
                sourceLocationAddress = nil
            }
            now = effectiveDate
            restartObservations()
        }
    }

    /// Transient "look from here" location handed in by the map's dropped person marker.
    ///
    /// Never persisted — unlike `timeShiftConfig`, which round-trips through
    /// `UserSettings.nearbyTimeShiftConfig`. It arrives as an init argument from the card's
    /// "See all" and dies with the screen.
    @Published private(set) var sourceLocationOverride: CLLocation?

    /// Reverse-geocoded playa address for `sourceLocationOverride`, once it lands.
    @Published private(set) var sourceLocationAddress: String?

    @Published var isLoading: Bool = true

    /// The date every timing readout on this screen is measured against.
    ///
    /// This is `effectiveDate`, NOT wall-clock now: the list is *filtered* at the warped
    /// date, so labeling the rows against real time made a warped list read as a pile of
    /// events that don't start for hours. Kept as stored published state (rather than a
    /// computed property) so the refresh timer can tick it and re-render the rows.
    @Published private(set) var now: Date = .present

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let artProvider: ArtDataProvider
    private let campProvider: CampDataProvider
    private let eventProvider: EventDataProvider
    private let locationProvider: LocationProvider

    /// Shared with the map's nearby card — see `NearbyEventFilterStore`.
    let filterStore: NearbyEventFilterStore
    private var filterSubscription: AnyCancellable?
    private var embargoSubscription: AnyCancellable?

    // MARK: - Location State

    private var rawLocation: CLLocation?
    private var lastObservedLocation: CLLocation?

    // MARK: - Tasks

    private var artTask: Task<Void, Never>?
    private var campTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var loadingGateTask: Task<Void, Never>?
    private var receivedFirstEmission: Set<String> = []

    // MARK: - Computed

    /// Where this screen is looking from, in precedence order:
    ///
    /// 1. `sourceLocationOverride` — the person the user dropped on the map;
    /// 2. the Warp configuration's location, when one was chosen;
    /// 3. the device's own fix.
    ///
    /// The two explicit choices can't both be live: setting either one clears the other
    /// (see `timeShiftConfig`'s `didSet` and `setSourceLocationOverride`), so the order
    /// above only decides which is *stored*, never which of two live choices wins.
    var currentLocation: CLLocation? {
        if let sourceLocationOverride {
            return sourceLocationOverride
        }
        if let config = timeShiftConfig, let location = config.location {
            return location
        }
        return rawLocation
    }

    /// True while some explicit choice — a dropped pin or a warp location — has taken the
    /// screen off the device's fix. That is exactly when a GPS update must not re-query.
    var isSourcePinned: Bool {
        sourceLocationOverride != nil || timeShiftConfig?.location != nil
    }

    /// Banner text while a dropped pin is driving the screen.
    var sourceLocationLabel: String? {
        guard sourceLocationOverride != nil else { return nil }
        let place = sourceLocationAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let place, !place.isEmpty else { return DroppedPersonAnnotation.fallbackTitle }
        return place
    }

    var effectiveDate: Date {
        timeShiftConfig?.date ?? .present
    }

    var searchRegion: MKCoordinateRegion? {
        guard let location = currentLocation else { return nil }
        return MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: searchDistance,
            longitudinalMeters: searchDistance
        )
    }

    var isEmpty: Bool {
        artItems.isEmpty && campItems.isEmpty && eventItems.isEmpty
    }

    // MARK: - Init

    init(
        playaDB: PlayaDB,
        artProvider: ArtDataProvider,
        campProvider: CampDataProvider,
        eventProvider: EventDataProvider,
        locationProvider: LocationProvider,
        // `nil` → the shared store. Not a `= .shared` default argument: default arguments
        // are evaluated in a nonisolated context, and `shared` is main-actor isolated.
        filterStore: NearbyEventFilterStore? = nil,
        /// Transient "look from here" spot, handed in by the map card's "See all" when the
        /// user has a person dropped. Nil for every other entry point into this screen.
        sourceLocationOverride: CLLocation? = nil
    ) {
        self.playaDB = playaDB
        self.artProvider = artProvider
        self.campProvider = campProvider
        self.eventProvider = eventProvider
        self.locationProvider = locationProvider
        self.filterStore = filterStore ?? .shared

        self.selectedFilter = UserSettings.nearbyFilter
        self.timeShiftConfig = UserSettings.nearbyTimeShiftConfig
        // Safe next to a restored `timeShiftConfig` with a location: property observers
        // don't fire for assignments made inside the declaring type's initializer, so the
        // `didSet` that normally retires an override doesn't run here. A restored warp
        // location is stale state; a freshly dropped pin is a live user action, and the
        // precedence in `currentLocation` is what settles that.
        self.sourceLocationOverride = sourceLocationOverride
        self.rawLocation = locationProvider.currentLocation
        self.now = timeShiftConfig?.date ?? .present

        observeFilterChanges()
        observeEmbargoClear()
        startLocationUpdates()
        startRefreshTimer()
        restartObservations()
    }

    /// Unlocking only flips a `UserDefaults` flag, so the embargo guards in the
    /// observation starters never re-evaluate on their own — restart them on the
    /// unlock notification or newly visible locations wait for a relaunch.
    private func observeEmbargoClear() {
        embargoSubscription = NotificationCenter.default
            .publisher(for: .BRCEmbargoDidClear)
            .sink { [weak self] _ in
                Task { @MainActor in self?.restartObservations() }
            }
    }

    /// The duration cap and type toggles are applied in SQL, so a filter change has to
    /// restart the event observation rather than re-filter what's already in memory.
    private func observeFilterChanges() {
        filterSubscription = filterStore.$filter
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.startEventObservation() }
            }
    }

    deinit {
        artTask?.cancel()
        campTask?.cancel()
        eventTask?.cancel()
        locationTask?.cancel()
        timerTask?.cancel()
        loadingGateTask?.cancel()
    }

    // MARK: - Dropped-pin source override

    /// Points the screen at `location` (or back at the device when nil) and re-queries.
    /// Purely in-memory: nothing here touches `UserSettings`.
    func setSourceLocationOverride(_ location: CLLocation?) {
        guard !isSameSourceLocation(sourceLocationOverride, location) else { return }
        sourceLocationOverride = location
        sourceLocationAddress = nil
        lastObservedLocation = currentLocation
        restartObservations()
    }

    /// Attaches the reverse-geocoded address for the drop at `coordinate`, ignoring results
    /// that arrive after the user has moved or removed the person.
    func setSourceLocationAddress(_ address: String?, for coordinate: CLLocationCoordinate2D) {
        guard let current = sourceLocationOverride?.coordinate,
              current.isSameCoordinate(as: coordinate) else { return }
        sourceLocationAddress = address
    }

    /// Back to sourcing from the device (or from an active warp location, if there is one).
    func clearSourceLocationOverride() {
        setSourceLocationOverride(nil)
    }

    // MARK: - Sections

    var sections: [NearbySection] {
        let filter = selectedFilter
        var result: [NearbySection] = []

        if filter == .all || filter == .event {
            let items = happeningEvents.map { NearbyItem.event($0) }
            if !items.isEmpty {
                result.append(NearbySection(id: .events, title: "Events", items: items))
            }
        }
        if filter == .all || filter == .art {
            let items = sortedArt.map { NearbyItem.art($0) }
            if !items.isEmpty {
                result.append(NearbySection(id: .art, title: "Art", items: items))
            }
        }
        if filter == .all || filter == .camp {
            let items = sortedCamps.map { NearbyItem.camp($0) }
            if !items.isEmpty {
                result.append(NearbySection(id: .camps, title: "Camps", items: items))
            }
        }

        return result
    }

    // MARK: - Sorting & Filtering

    private var sortedArt: [ListRow<ArtObject>] {
        guard let loc = currentLocation else { return artItems }
        return artItems.sorted { a, b in
            distanceTo(a.object.location, from: loc) < distanceTo(b.object.location, from: loc)
        }
    }

    private var sortedCamps: [ListRow<CampObject>] {
        guard let loc = currentLocation else { return campItems }
        return campItems.sorted { a, b in
            distanceTo(a.object.location, from: loc) < distanceTo(b.object.location, from: loc)
        }
    }

    /// Events happening at the effective date or starting within the next 30 minutes,
    /// starting-soonest first, then most-recently-started. Window and ordering both live
    /// outside this type so the map's nearby card shows exactly the same set in the same
    /// order — see `isInNearbyWindow` and `NearbyEventOrdering`.
    ///
    /// Long-running "amenity listing" occurrences are excluded upstream by the SQL duration
    /// cap in `filterStore.observationFilter(region:)`, not here.
    var happeningEvents: [ListRow<EventObjectOccurrence>] {
        let date = effectiveDate
        return NearbyEventOrdering.sorted(
            eventItems.filter { $0.object.isInNearbyWindow(now: date) },
            now: date
        )
    }

    private func distanceTo(_ location: CLLocation?, from reference: CLLocation) -> CLLocationDistance {
        guard let location else { return .greatestFiniteMagnitude }
        return reference.distance(from: location)
    }

    // MARK: - Distance Display

    /// Walk/bike estimate, or nil while the item's embargo tier still hides its placement.
    ///
    /// A distance is derived from the embargoed coordinates, so it has to be withheld along
    /// with the address. Returning nil drops the distance line from the row entirely —
    /// `ObjectRowView` renders nothing for a nil subtitle. The providers apply the same
    /// gate (plus the implausible-distance clamp) in `PlayaDistanceString`; the guard here
    /// keeps the intent legible at the call site.
    func distanceString(for item: NearbyItem) -> AttributedString? {
        guard item.canShowLocation else { return nil }
        return switch item {
        case .art(let r): artProvider.distanceAttributedString(from: currentLocation, to: r.object)
        case .camp(let r): campProvider.distanceAttributedString(from: currentLocation, to: r.object)
        case .event(let r): eventProvider.distanceAttributedString(from: currentLocation, to: r.object)
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ item: NearbyItem) async {
        do {
            switch item {
            case .art(let o): try await artProvider.toggleFavorite(o.object)
            case .camp(let o): try await campProvider.toggleFavorite(o.object)
            case .event(let o): try await eventProvider.toggleFavorite(o.object)
            }
        } catch {
            print("Error toggling favorite for \(item.name): \(error)")
        }
    }

    func isFavorite(_ uid: String) -> Bool {
        // TODO: Track favorite IDs via observation if needed
        false
    }

    // MARK: - Map

    var allAnnotations: [PlayaObjectAnnotation] {
        var annotations: [PlayaObjectAnnotation] = []
        for section in sections {
            for item in section.items {
                switch item {
                case .art(let o):
                    if let a = PlayaObjectAnnotation(art: o.object) { annotations.append(a) }
                case .camp(let o):
                    if let a = PlayaObjectAnnotation(camp: o.object) { annotations.append(a) }
                case .event(let o):
                    if let a = PlayaObjectAnnotation(event: o.object) { annotations.append(a) }
                }
            }
        }
        return annotations
    }

    // MARK: - Observations

    func restartObservations() {
        receivedFirstEmission.removeAll()
        isLoading = true
        startArtObservation()
        startCampObservation()
        startEventObservation()
    }

    private func startArtObservation() {
        artTask?.cancel()
        // A region-sourced result leaks embargoed placement by presence and rank alone,
        // so locked tiers contribute nothing — same rule as `MapRegionAnnotationFilter`.
        guard let region = searchRegion, BRCEmbargo.canShowArtLocations() else {
            artItems = []
            markReceived("art")
            return
        }
        let filter = ArtFilter(region: region)
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
        guard let region = searchRegion, BRCEmbargo.canShowCampLocations() else {
            campItems = []
            markReceived("camp")
            return
        }
        let filter = CampFilter(region: region)
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
        guard let region = searchRegion else {
            eventItems = []
            markReceived("event")
            return
        }
        // The user's filter (duration cap, event types, favorites) applied in SQL; the
        // now-window stays client-side so it can be evaluated at `effectiveDate`.
        let filter = filterStore.observationFilter(region: region)
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.eventProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    // Per-occurrence tier: an event's presence here places its host, so a
                    // locked host hides the event (art-located events ride the art tier).
                    self.eventItems = BRCEmbargo.visibleNearbyEvents(items)
                    self.markReceived("event")
                }
            }
        }
    }

    private func markReceived(_ key: String) {
        receivedFirstEmission.insert(key)
        if receivedFirstEmission.count >= 3 {
            isLoading = false
            loadingGateTask?.cancel()
        } else {
            startLoadingGateIfNeeded()
        }
    }

    private func startLoadingGateIfNeeded() {
        guard loadingGateTask == nil else { return }
        loadingGateTask = Task { [weak self] in
            let timeout: UInt64 = 5_000_000_000
            let poll: UInt64 = 200_000_000
            let start = DispatchTime.now().uptimeNanoseconds
            while !Task.isCancelled {
                if await self?.artProvider.isDatabaseSeeded() == true {
                    await MainActor.run { self?.isLoading = false }
                    return
                }
                if DispatchTime.now().uptimeNanoseconds - start >= timeout {
                    await MainActor.run { self?.isLoading = false }
                    return
                }
                try? await Task.sleep(nanoseconds: poll)
            }
        }
    }

    // MARK: - Location

    private func startLocationUpdates() {
        locationTask?.cancel()
        locationTask = Task { [weak self] in
            guard let self else { return }
            for await location in self.locationProvider.locationStream {
                guard let location else { continue }
                await MainActor.run {
                    self.rawLocation = location
                    // Only restart observations if location moved significantly
                    if let last = self.lastObservedLocation {
                        if location.distance(from: last) > 50 {
                            self.lastObservedLocation = location
                            // Only restart while the screen is actually following the
                            // device — a dropped pin or a warp location pins it in place.
                            if !self.isSourcePinned {
                                self.restartObservations()
                            }
                        }
                    } else {
                        self.lastObservedLocation = location
                        // First location — start observations unless the screen is pinned
                        if !self.isSourcePinned {
                            self.restartObservations()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Refresh Timer

    private func startRefreshTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let self else { return }
                await MainActor.run {
                    self.now = self.effectiveDate
                }
            }
        }
    }
}
