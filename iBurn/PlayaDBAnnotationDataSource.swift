//
//  PlayaDBAnnotationDataSource.swift
//  iBurn
//
//  Cache-and-observe annotation data source backed by PlayaDB.
//  Replaces YapViewAnnotationDataSource for art, camps, events, and favorites.
//

import Foundation
import MapLibre
import PlayaDB

protocol PlayaDBAnnotationDataSourceDelegate: AnyObject {
    func annotationDataSourceDidUpdate(_ dataSource: PlayaDBAnnotationDataSource)
}

final class PlayaDBAnnotationDataSource: NSObject, AnnotationDataSource {

    weak var delegate: PlayaDBAnnotationDataSourceDelegate?

    private let playaDB: PlayaDB

    // MARK: - Per-category caches

    private var artAnnotations: [MLNAnnotation] = []
    private var campAnnotations: [MLNAnnotation] = []
    private var eventAnnotations: [MLNAnnotation] = []
    private var favoriteArtAnnotations: [MLNAnnotation] = []
    private var favoriteCampAnnotations: [MLNAnnotation] = []
    private var favoriteEventAnnotations: [MLNAnnotation] = []

    /// Merged cache returned by allAnnotations()
    private var cachedAnnotations: [MLNAnnotation] = []

    /// Active observation tokens
    private var observationTokens: [PlayaDBObservationToken] = []

    /// True between `startObserving()` and `stopObserving()`. Gates the embargo-driven
    /// restart so a torn-down data source never resurrects its observations.
    private var isObserving = false

    // MARK: - Init

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
        super.init()
        // `startObserving()` snapshots `BRCEmbargo.allowEmbargoedData()` into each observation
        // block, so an unlock while the map is live would otherwise keep filtering annotations
        // out until the next launch.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(embargoDidClear),
            name: .BRCEmbargoDidClear,
            object: nil
        )
    }

    @objc private func embargoDidClear() {
        guard isObserving else { return }
        startObserving()
    }

    // MARK: - AnnotationDataSource

    func allAnnotations() -> [MLNAnnotation] {
        cachedAnnotations
    }

    // MARK: - Observation Lifecycle

    /// Start GRDB observations based on current UserSettings.
    func startObserving() {
        stopObserving()
        isObserving = true

        // Snapshotted per observation start; embargoDidClear() restarts observations.
        let artAllowed = BRCEmbargo.canShowArtLocations()
        let campAllowed = BRCEmbargo.canShowCampLocations()

        // Art
        if UserSettings.showArtOnMap {
            let token = playaDB.observeArt(filter: ArtFilter()) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.artAnnotations = artAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(art: $0.object) }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Camps
        if UserSettings.showCampsOnMap {
            let token = playaDB.observeCamps(filter: CampFilter()) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.campAnnotations = campAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(camp: $0.object) }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Active events
        if UserSettings.showActiveEventsOnMap {
            let selectedCodes = BRCEventType.eventTypeCodes(from: UserSettings.selectedEventTypesForMap)
            let filter = EventFilter(
                happeningNow: true,
                eventTypeCodes: selectedCodes
            )
            let token = playaDB.observeEvents(filter: filter) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.eventAnnotations = rows.compactMap { row in
                        let allowed = (row.object.locatedAtArt?.isEmpty == false) ? artAllowed : campAllowed
                        return allowed ? PlayaObjectAnnotation(event: row.object) : nil
                    }
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Favorite art
        if UserSettings.showFavoritesOnMap {
            let token = playaDB.observeArt(filter: ArtFilter(onlyFavorites: true)) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.favoriteArtAnnotations = artAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(art: $0.object)?.markedFavorite() }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Favorite camps
        if UserSettings.showFavoritesOnMap {
            let token = playaDB.observeCamps(filter: CampFilter(onlyFavorites: true)) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.favoriteCampAnnotations = campAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(camp: $0.object)?.markedFavorite() }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Favorite events
        if UserSettings.showFavoritesOnMap {
            let eventFilter = Self.favoriteEventFilter(
                showTodaysOnly: UserSettings.showTodaysFavoritesOnlyOnMap,
                includeExpired: UserSettings.showExpiredEventsInFavorites,
                now: .present
            )
            let token = playaDB.observeEvents(filter: eventFilter) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.favoriteEventAnnotations = rows.compactMap { row in
                        let allowed = (row.object.locatedAtArt?.isEmpty == false) ? artAllowed : campAllowed
                        return allowed ? PlayaObjectAnnotation(event: row.object)?.markedFavorite() : nil
                    }
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }
    }

    /// Cancel all observations and clear caches.
    func stopObserving() {
        isObserving = false
        for token in observationTokens {
            token.cancel()
        }
        observationTokens.removeAll()
        artAnnotations.removeAll()
        campAnnotations.removeAll()
        eventAnnotations.removeAll()
        favoriteArtAnnotations.removeAll()
        favoriteCampAnnotations.removeAll()
        favoriteEventAnnotations.removeAll()
        cachedAnnotations.removeAll()
    }

    // MARK: - Favourite-event filter

    /// The filter behind the map's favourited-events layer.
    ///
    /// "Today's Favorites Only" narrows it to occurrences that *start* inside today —
    /// `[startOfDay, startOfDay + 1 day)` — which is what keeps the map readable during the
    /// event, when a week of favourites would otherwise pin the whole city at once. The
    /// window is applied in SQL (`PlayaDBImpl.eventOccurrenceRequest`), so an occurrence
    /// weeks out is never fetched, let alone drawn.
    ///
    /// Pure, and split out of `startObserving()` so the window can be tested without a
    /// database: it reads the clock through `now` (`Date.present`, which honours the
    /// mock-date scheme) rather than calling `Date()` itself.
    static func favoriteEventFilter(showTodaysOnly: Bool,
                                    includeExpired: Bool,
                                    now: Date,
                                    calendar: Calendar = .current) -> EventFilter {
        var filter = EventFilter(onlyFavorites: true, includeExpired: includeExpired)
        guard showTodaysOnly else { return filter }
        let startOfDay = calendar.startOfDay(for: now)
        filter.startDate = startOfDay
        filter.endDate = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        return filter
    }

    // MARK: - Private

    private func rebuildCache() {
        cachedAnnotations = artAnnotations
            + campAnnotations
            + eventAnnotations
            + favoriteArtAnnotations
            + favoriteCampAnnotations
            + favoriteEventAnnotations
        delegate?.annotationDataSourceDidUpdate(self)
    }
}
