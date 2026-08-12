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
        // The favourites layer is bounded by *today*, and that boundary is baked into the
        // query when the observation starts. A phone left on the map overnight — the normal
        // case on playa — would otherwise show yesterday's favourites until it was relaunched.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dayDidChange),
            name: .NSCalendarDayChanged,
            object: nil
        )
    }

    @objc private func embargoDidClear() {
        guard isObserving else { return }
        startObserving()
    }

    @objc private func dayDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isObserving else { return }
            self.startObserving()
        }
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

        // Favorite events — today's occurrences only, see `favoriteEventFilter`.
        if UserSettings.showFavoritesOnMap {
            let eventFilter = Self.favoriteEventFilter(
                includeExpired: UserSettings.showExpiredEventsInFavorites,
                now: .present
            )
            let token = playaDB.observeEvents(filter: eventFilter) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    // The SQL window was fixed when this observation started; re-checked
                    // here against the clock at delivery so a map left up across midnight
                    // can't keep drawing yesterday's favourites (the day-change observer
                    // rebuilds the query itself).
                    let now = Date.present
                    self.favoriteEventAnnotations = rows.compactMap { row in
                        guard Self.occurrenceIsToday(startDate: row.object.startDate,
                                                     endDate: row.object.endDate,
                                                     now: now) else { return nil }
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

    /// Today, as the map means it: `[startOfDay, startOfDay + 1 day)` in the device calendar.
    static func todayWindow(now: Date, calendar: Calendar = .current) -> DateInterval {
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)
            ?? startOfDay.addingTimeInterval(24 * 60 * 60)
        return DateInterval(start: startOfDay, end: endOfDay)
    }

    /// Whether a favourited occurrence belongs on the map right now.
    ///
    /// Overlap, not start-time bucketing: an occurrence that began at 11pm yesterday and is
    /// still running at 1am is a thing you can still walk to, and a 10pm–2am set favourited
    /// for tonight belongs on tonight's map. `[start, end)` intersecting `[startOfDay,
    /// tomorrow)` is the same predicate the SQL below runs, kept here so the in-memory
    /// re-check and the query can't drift apart.
    static func occurrenceIsToday(startDate: Date,
                                  endDate: Date,
                                  now: Date,
                                  calendar: Calendar = .current) -> Bool {
        let window = todayWindow(now: now, calendar: calendar)
        return startDate < window.end && endDate > window.start
    }

    /// The filter behind the map's favourited-events layer.
    ///
    /// Always narrowed to today. Favourites are per-occurrence (`EventFavoriteKey` embeds the
    /// occurrence's start instant), and a week of them pins the whole city at once: the
    /// Wednesday set you starred is noise on Monday's map, drawn over the camps you are
    /// actually standing in. The list screens are where the whole week lives.
    ///
    /// The window is an *overlap* window (`EventFilter.activeWindow`), not a start-time
    /// range, so an occurrence running across midnight stays on the map while it runs. It is
    /// applied in SQL (`PlayaDBImpl.eventOccurrenceRequest`), so an occurrence weeks out is
    /// never fetched, let alone drawn.
    ///
    /// Pure, and split out of `startObserving()` so the window can be tested without a
    /// database: it reads the clock through `now` (`Date.present`, which honours the
    /// mock-date scheme) rather than calling `Date()` itself.
    static func favoriteEventFilter(includeExpired: Bool,
                                    now: Date,
                                    calendar: Calendar = .current) -> EventFilter {
        var filter = EventFilter(onlyFavorites: true, includeExpired: includeExpired)
        filter.activeWindow = todayWindow(now: now, calendar: calendar)
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
