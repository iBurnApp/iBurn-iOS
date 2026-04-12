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

    // MARK: - Init

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
        super.init()
    }

    // MARK: - AnnotationDataSource

    func allAnnotations() -> [MLNAnnotation] {
        cachedAnnotations
    }

    // MARK: - Observation Lifecycle

    /// Start GRDB observations based on current UserSettings.
    func startObserving() {
        stopObserving()

        let embargoAllowed = BRCEmbargo.allowEmbargoedData()

        // Art
        if UserSettings.showArtOnMap {
            let token = playaDB.observeArt(filter: ArtFilter()) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.artAnnotations = embargoAllowed
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
                    self.campAnnotations = embargoAllowed
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
                    self.eventAnnotations = embargoAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(event: $0.object) }
                        : []
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
                    self.favoriteArtAnnotations = embargoAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(art: $0.object) }
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
                    self.favoriteCampAnnotations = embargoAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(camp: $0.object) }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }

        // Favorite events
        if UserSettings.showFavoritesOnMap {
            var eventFilter = EventFilter(
                onlyFavorites: true,
                includeExpired: UserSettings.showExpiredEventsInFavorites
            )
            if UserSettings.showTodaysFavoritesOnlyOnMap {
                let calendar = Calendar.current
                let today = Date.present
                eventFilter.startDate = calendar.startOfDay(for: today)
                eventFilter.endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))
            }
            let token = playaDB.observeEvents(filter: eventFilter) { [weak self] rows in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.favoriteEventAnnotations = embargoAllowed
                        ? rows.compactMap { PlayaObjectAnnotation(event: $0.object) }
                        : []
                    self.rebuildCache()
                }
            }
            observationTokens.append(token)
        }
    }

    /// Cancel all observations and clear caches.
    func stopObserving() {
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
