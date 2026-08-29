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

    /// Favourited-event pins with the occurrence times they live or die by. Kept apart from
    /// the other caches because this is the one layer whose membership changes with the clock
    /// and not with the database: an occurrence ages out of `recentlyEndedGrace` while nothing
    /// at all is written, so the set is re-derived on every `allAnnotations()` rather than
    /// frozen at delivery.
    private var favoriteEventCandidates: [FavoriteEventCandidate] = []

    private struct FavoriteEventCandidate {
        let annotation: MLNAnnotation
        let startDate: Date
        let endDate: Date
    }

    /// Merged cache of the clock-independent layers, returned (plus live favourite events)
    /// by `allAnnotations()`.
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
        // Re-checked against the clock on every read, not cached: `MapViewAdapter` calls this
        // on every reload (returning to the map, closing the filter sheet, any database
        // write), which is what makes a pin whose grace has run out actually leave the map
        // without a timer ticking behind it.
        cachedAnnotations + favoriteEventAnnotations(now: .present)
    }

    private func favoriteEventAnnotations(now: Date) -> [MLNAnnotation] {
        favoriteEventCandidates.compactMap { candidate in
            Self.occurrenceBelongsOnMap(startDate: candidate.startDate,
                                        endDate: candidate.endDate,
                                        now: now) ? candidate.annotation : nil
        }
    }

    // MARK: - Observation Lifecycle

    /// Start GRDB observations based on current UserSettings.
    func startObserving() {
        stopObserving()
        isObserving = true

        // Snapshotted per observation start; embargoDidClear() restarts observations.
        let artAllowed = MapEmbargo.allowsArtLocation()
        // The browse layers draw every camp in the city at once, which is exact placement
        // data in bulk — gates tier, not the week-early camp release. See `MapEmbargo`.
        let campBulkAllowed = MapEmbargo.allowsBulkCampPlacement()
        // The favourites layers draw a set the user built by hand, one object at a time, the
        // same subset the Favorites list shows; they stay on the camp tier with it.
        let campFavoriteAllowed = MapEmbargo.allowsSingleCampLocation()

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
                    self.campAnnotations = campBulkAllowed
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
                        // Every event happening now, pinned at its host — which draws the
                        // host camps' positions in bulk just as surely as the camp layer
                        // does, so it rides the same gates tier.
                        let allowed = (row.object.locatedAtArt?.isEmpty == false)
                            ? artAllowed
                            : campBulkAllowed
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
                    self.favoriteCampAnnotations = campFavoriteAllowed
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
                    // The SQL window was fixed when this observation started; every row is
                    // re-checked against the clock on each `allAnnotations()` read, so what
                    // is kept here is the candidate set, not the answer.
                    self.favoriteEventCandidates = rows.compactMap { row in
                        let allowed = (row.object.locatedAtArt?.isEmpty == false)
                            ? artAllowed
                            : campFavoriteAllowed
                        guard allowed,
                              let annotation = PlayaObjectAnnotation(event: row.object)?.markedFavorite()
                        else { return nil }
                        return FavoriteEventCandidate(annotation: annotation,
                                                      startDate: row.object.startDate,
                                                      endDate: row.object.endDate)
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
        favoriteEventCandidates.removeAll()
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

    /// How long a finished occurrence stays on the map after its end time.
    ///
    /// "Today" alone leaves a 10am workshop pinned through to midnight, and by afternoon the
    /// map is a museum of things that already happened. But dropping a pin the instant its
    /// end time passes is wrong in the other direction: sets run long, and the thing you were
    /// walking to twenty minutes ago is still the thing you are walking to. So a finished
    /// occurrence lingers for an hour — drawn red-for-ended by `EventPinStatus` the whole
    /// time — and then goes.
    static let recentlyEndedGrace: TimeInterval = 60 * 60

    /// The window the map actually draws: today, with everything that finished more than
    /// `recentlyEndedGrace` ago trimmed off the front.
    ///
    /// Only the *start* of today's window moves. Anything still running has an end time later
    /// than `now`, so it is never trimmed, and an occurrence starting later today is untouched
    /// — the trim can only ever remove things that are already over.
    static func mapWindow(now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = todayWindow(now: now, calendar: calendar)
        let graceStart = now.addingTimeInterval(-recentlyEndedGrace)
        return DateInterval(start: max(today.start, graceStart), end: today.end)
    }

    /// Whether a favourited occurrence belongs on the map at `now`: today's, and not finished
    /// longer ago than the grace period.
    ///
    /// Identical to overlapping `mapWindow`, written as the two rules it is made of so the
    /// reason each pin is gone stays readable.
    static func occurrenceBelongsOnMap(startDate: Date,
                                       endDate: Date,
                                       now: Date,
                                       calendar: Calendar = .current) -> Bool {
        occurrenceIsToday(startDate: startDate, endDate: endDate, now: now, calendar: calendar)
            && endDate > now.addingTimeInterval(-recentlyEndedGrace)
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
    /// Its front edge is also trimmed by `recentlyEndedGrace` (see `mapWindow`), so the query
    /// stops fetching this morning's finished workshops instead of fetching them for the
    /// in-memory re-check to throw away. The re-check still has to exist: this bound is frozen
    /// when the observation starts, and occurrences keep ending after that.
    ///
    /// Pure, and split out of `startObserving()` so the window can be tested without a
    /// database: it reads the clock through `now` (`Date.present`, which honours the
    /// mock-date scheme) rather than calling `Date()` itself.
    static func favoriteEventFilter(includeExpired: Bool,
                                    now: Date,
                                    calendar: Calendar = .current) -> EventFilter {
        var filter = EventFilter(onlyFavorites: true, includeExpired: includeExpired)
        filter.activeWindow = mapWindow(now: now, calendar: calendar)
        return filter
    }

    // MARK: - Private

    private func rebuildCache() {
        cachedAnnotations = artAnnotations
            + campAnnotations
            + eventAnnotations
            + favoriteArtAnnotations
            + favoriteCampAnnotations
        delegate?.annotationDataSourceDidUpdate(self)
    }
}
