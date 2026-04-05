import CoreLocation
import Foundation
import MapKit
import PlayaDB

@MainActor
final class NearbyViewModel: ObservableObject {
    // MARK: - Published

    @Published var artItems: [ArtObject] = []
    @Published var campItems: [CampObject] = []
    @Published var eventItems: [EventObjectOccurrence] = []

    @Published var searchDistance: CLLocationDistance = 500 {
        didSet { restartObservations() }
    }

    @Published var selectedFilter: NearbyFilter = .all {
        didSet { UserSettings.nearbyFilter = selectedFilter }
    }

    @Published var timeShiftConfig: TimeShiftConfiguration? {
        didSet {
            UserSettings.nearbyTimeShiftConfig = timeShiftConfig
            restartObservations()
        }
    }

    @Published var isLoading: Bool = true
    @Published var now: Date = .present
    @Published private(set) var resolvedHosts: [String: ResolvedEventHost] = [:]

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let artProvider: ArtDataProvider
    private let campProvider: CampDataProvider
    private let eventProvider: EventDataProvider
    private let locationProvider: LocationProvider

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

    var currentLocation: CLLocation? {
        if let config = timeShiftConfig, let location = config.location {
            return location
        }
        return rawLocation
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
        locationProvider: LocationProvider
    ) {
        self.playaDB = playaDB
        self.artProvider = artProvider
        self.campProvider = campProvider
        self.eventProvider = eventProvider
        self.locationProvider = locationProvider

        self.selectedFilter = UserSettings.nearbyFilter
        self.timeShiftConfig = UserSettings.nearbyTimeShiftConfig
        self.rawLocation = locationProvider.currentLocation

        startLocationUpdates()
        startRefreshTimer()
        restartObservations()
    }

    deinit {
        artTask?.cancel()
        campTask?.cancel()
        eventTask?.cancel()
        locationTask?.cancel()
        timerTask?.cancel()
        loadingGateTask?.cancel()
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

    private var sortedArt: [ArtObject] {
        guard let loc = currentLocation else { return artItems }
        return artItems.sorted { a, b in
            distanceTo(a.location, from: loc) < distanceTo(b.location, from: loc)
        }
    }

    private var sortedCamps: [CampObject] {
        guard let loc = currentLocation else { return campItems }
        return campItems.sorted { a, b in
            distanceTo(a.location, from: loc) < distanceTo(b.location, from: loc)
        }
    }

    /// Events happening at the effective date, sorted by start time
    private var happeningEvents: [EventObjectOccurrence] {
        let date = effectiveDate
        return eventItems
            .filter { $0.startDate <= date && $0.endDate > date }
            .sorted { $0.startDate < $1.startDate }
    }

    private func distanceTo(_ location: CLLocation?, from reference: CLLocation) -> CLLocationDistance {
        guard let location else { return .greatestFiniteMagnitude }
        return reference.distance(from: location)
    }

    // MARK: - Distance Display

    func distanceString(for item: NearbyItem) -> AttributedString? {
        switch item {
        case .art(let o): artProvider.distanceAttributedString(from: currentLocation, to: o)
        case .camp(let o): campProvider.distanceAttributedString(from: currentLocation, to: o)
        case .event(let o): eventProvider.distanceAttributedString(from: currentLocation, to: o)
        }
    }

    // MARK: - Host Resolution

    func resolvedHost(for event: EventObjectOccurrence) -> ResolvedEventHost? {
        resolvedHosts[event.event.uid]
    }

    private func resolveHosts(for events: [EventObjectOccurrence]) {
        let needsResolution = events.filter { event in
            let uid = event.event.uid
            if resolvedHosts[uid] != nil { return false }
            return event.event.isHostedByCamp || event.event.isLocatedAtArt
        }
        guard !needsResolution.isEmpty else { return }

        Task { [weak self, playaDB] in
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

            guard !newHosts.isEmpty else { return }
            await MainActor.run {
                self.resolvedHosts.merge(newHosts) { _, new in new }
            }
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ item: NearbyItem) async {
        do {
            switch item {
            case .art(let o): try await artProvider.toggleFavorite(o)
            case .camp(let o): try await campProvider.toggleFavorite(o)
            case .event(let o): try await eventProvider.toggleFavorite(o)
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
                    if let a = PlayaObjectAnnotation(art: o) { annotations.append(a) }
                case .camp(let o):
                    if let a = PlayaObjectAnnotation(camp: o) { annotations.append(a) }
                case .event(let o):
                    if let a = PlayaObjectAnnotation(event: o) { annotations.append(a) }
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
        guard let region = searchRegion else {
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
        guard let region = searchRegion else {
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
        // Fetch all events in region; client-side filter for "happening now" at effectiveDate
        let filter = EventFilter(region: region, includeExpired: true)
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await items in self.eventProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.eventItems = items
                    self.markReceived("event")
                    self.resolveHosts(for: items)
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
                            // Only restart if not using time-shifted location
                            if self.timeShiftConfig?.location == nil {
                                self.restartObservations()
                            }
                        }
                    } else {
                        self.lastObservedLocation = location
                        // First location — start observations if not already running with time shift
                        if self.timeShiftConfig?.location == nil {
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
                    self.now = .present
                }
            }
        }
    }
}
