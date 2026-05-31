//
//  NearbyCardViewModel.swift
//  iBurn
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Backing model for the on-map "nearby card" overlay. Emits a single flat,
//  ordered, de-duped list of objects within a tight radius of the user, with
//  events (happening now / starting soon) prioritized first, then art + camps
//  by distance. This is NOT the full-screen Nearby list (NearbyViewModel) — it
//  reuses the same data providers and `NearbyItem`, but produces a compact feed
//  for the map card.
//

import CoreLocation
import Foundation
import MapKit
import PlayaDB

@MainActor
final class NearbyCardViewModel: ObservableObject {
    // MARK: - Published

    /// Ordered, de-duped nearby items: events first, then art + camps by distance.
    @Published private(set) var items: [NearbyItem] = []

    /// Currently paged item, tracked by `NearbyItem.id` (not index) so that location
    /// updates re-ordering the feed don't yank the user mid-swipe.
    @Published var selectedID: String?

    /// Whether the card is collapsed into its FAB.
    @Published var isMinimized: Bool = false

    /// Live "now" for event timing display; refreshed on a timer.
    @Published var now: Date = .present

    // MARK: - Tuning

    /// Only surface objects within this radius of the user (meters).
    let nearbyRadius: CLLocationDistance = 100

    /// Re-center the DB region query after the user moves at least this far (meters).
    private let regionRecenterThreshold: CLLocationDistance = 25

    /// Cap the pager so it stays light.
    private let maxItems = 12

    // MARK: - Dependencies

    private let playaDB: PlayaDB
    private let artProvider: ArtDataProvider
    private let campProvider: CampDataProvider
    private let eventProvider: EventDataProvider
    private let locationProvider: LocationProvider

    // MARK: - State

    private var rawLocation: CLLocation?
    private var lastRegionLocation: CLLocation?
    private var artItems: [ListRow<ArtObject>] = []
    private var campItems: [ListRow<CampObject>] = []
    private var eventItems: [ListRow<EventObjectOccurrence>] = []

    // MARK: - Tasks

    private var artTask: Task<Void, Never>?
    private var campTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var locationTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    // MARK: - Computed

    var currentLocation: CLLocation? { rawLocation }

    var count: Int { items.count }

    /// A small region centered on the user for the DB region queries. Sized a bit
    /// larger than `nearbyRadius` (a square bbox circumscribing the circle) so the
    /// exact per-item distance filter in `rebuildItems()` is the precise gate.
    var searchRegion: MKCoordinateRegion? {
        guard let location = currentLocation else { return nil }
        return MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: nearbyRadius * 2,
            longitudinalMeters: nearbyRadius * 2
        )
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

        self.rawLocation = locationProvider.currentLocation
        self.lastRegionLocation = rawLocation

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
    }

    // MARK: - Favorites

    func toggleFavorite(_ item: NearbyItem) async {
        do {
            switch item {
            case .art(let row): try await artProvider.toggleFavorite(row.object)
            case .camp(let row): try await campProvider.toggleFavorite(row.object)
            case .event(let row): try await eventProvider.toggleFavorite(row.object)
            }
        } catch {
            // Favorite state is driven by DB observation; a failed toggle is a no-op.
        }
    }

    // MARK: - Item assembly

    /// Recompute `items` from the latest observations + location. Events that are
    /// happening now or starting soon come first (by start time); then art + camps
    /// merged by distance. Everything is gated to `nearbyRadius`, de-duped by id,
    /// and capped to `maxItems`.
    private func rebuildItems() {
        guard let location = currentLocation else {
            items = []
            reconcileSelection()
            return
        }
        items = Self.orderedItems(
            art: artItems,
            camps: campItems,
            events: eventItems,
            from: location,
            now: now,
            radius: nearbyRadius,
            maxItems: maxItems
        )
        reconcileSelection()
    }

    /// Pure ordering used by `rebuildItems()`, exposed for unit testing.
    ///
    /// Events that are happening now or starting soon come first (by start time);
    /// then art + camps merged by distance. All gated to `radius`, de-duped by id,
    /// capped to `maxItems`. Objects without a location are dropped.
    static func orderedItems(
        art: [ListRow<ArtObject>],
        camps: [ListRow<CampObject>],
        events: [ListRow<EventObjectOccurrence>],
        from location: CLLocation,
        now: Date,
        radius: CLLocationDistance,
        maxItems: Int
    ) -> [NearbyItem] {
        let orderedEvents = events
            .filter { row in
                guard let loc = row.object.location,
                      location.distance(from: loc) <= radius else { return false }
                return row.object.isCurrentlyHappening(now) || row.object.isStartingSoon(now)
            }
            .sorted { $0.object.startDate < $1.object.startDate }
            .map { NearbyItem.event($0) }

        var others: [(item: NearbyItem, distance: CLLocationDistance)] = []
        for row in art {
            guard let loc = row.object.location else { continue }
            let distance = location.distance(from: loc)
            if distance <= radius { others.append((.art(row), distance)) }
        }
        for row in camps {
            guard let loc = row.object.location else { continue }
            let distance = location.distance(from: loc)
            if distance <= radius { others.append((.camp(row), distance)) }
        }
        let sortedOthers = others.sorted { $0.distance < $1.distance }.map(\.item)

        var seen = Set<String>()
        var combined: [NearbyItem] = []
        for item in orderedEvents + sortedOthers {
            guard seen.insert(item.id).inserted else { continue }
            combined.append(item)
            if combined.count >= maxItems { break }
        }
        return combined
    }

    /// Keep the paged selection stable across rebuilds; only reset when the
    /// selected item is no longer present.
    private func reconcileSelection() {
        if let selectedID, items.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = items.first?.id
    }

    // MARK: - Observations

    private func restartObservations() {
        startArtObservation()
        startCampObservation()
        startEventObservation()
    }

    private func startArtObservation() {
        artTask?.cancel()
        guard let region = searchRegion else {
            artItems = []
            rebuildItems()
            return
        }
        let filter = ArtFilter(region: region)
        artTask = Task { [weak self] in
            guard let self else { return }
            for await rows in self.artProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.artItems = rows
                    self.rebuildItems()
                }
            }
        }
    }

    private func startCampObservation() {
        campTask?.cancel()
        guard let region = searchRegion else {
            campItems = []
            rebuildItems()
            return
        }
        let filter = CampFilter(region: region)
        campTask = Task { [weak self] in
            guard let self else { return }
            for await rows in self.campProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.campItems = rows
                    self.rebuildItems()
                }
            }
        }
    }

    private func startEventObservation() {
        eventTask?.cancel()
        guard let region = searchRegion else {
            eventItems = []
            rebuildItems()
            return
        }
        // Region-filtered (R*Tree-backed). Fetch all in-region occurrences and apply the
        // exact happening-now / starting-soon gate client-side at `now` (the region is
        // tiny, and this also captures starting-soon events that `happeningNow` would drop).
        let filter = EventFilter(includeExpired: true, region: region)
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await rows in self.eventProvider.observeObjects(filter: filter) {
                await MainActor.run {
                    self.eventItems = rows
                    self.rebuildItems()
                }
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
                    if let last = self.lastRegionLocation,
                       location.distance(from: last) < self.regionRecenterThreshold {
                        // Small move: re-sort / re-gate against the existing observations.
                        self.rebuildItems()
                    } else {
                        // First fix or meaningful move: recenter the region queries.
                        self.lastRegionLocation = location
                        self.restartObservations()
                    }
                }
            }
        }
    }

    // MARK: - Refresh timer

    private func startRefreshTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                guard let self else { return }
                await MainActor.run {
                    self.now = .present
                    self.rebuildItems()
                }
            }
        }
    }
}
