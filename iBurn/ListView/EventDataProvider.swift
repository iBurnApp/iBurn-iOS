import Foundation
import CoreLocation
import PlayaDB

/// Data provider for Event objects (occurrences)
///
/// Implements ObjectListDataProvider to provide event-specific data operations
/// including observation, favorite management, and distance calculations.
class EventDataProvider: ObjectListDataProvider {
    typealias Object = EventObjectOccurrence
    typealias Filter = EventFilter

    let playaDB: PlayaDB
    private let favoriteSync: FavoriteSyncService

    init(playaDB: PlayaDB, favoriteSync: FavoriteSyncService = FavoriteSyncServiceFactory.shared) {
        self.playaDB = playaDB
        self.favoriteSync = favoriteSync
    }

    func isDatabaseSeeded() async -> Bool {
        guard let updateInfo = try? await playaDB.getUpdateInfo() else { return false }
        return !updateInfo.isEmpty
    }

    // MARK: - ObjectListDataProvider

    func observeObjects(filter: EventFilter) -> AsyncStream<[ListRow<EventObjectOccurrence>]> {
        AsyncStream { continuation in
            let token = playaDB.observeEvents(filter: filter) { rows in
                continuation.yield(rows)
            } onError: { error in
                print("Event observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    /// Observe events grouped into hour-of-day sections at the data layer.
    /// Use this for browse mode (sectioned list + hour quick-scroll strip);
    /// use `observeObjects` for search mode (flat results).
    func observeObjectsByHour(filter: EventFilter) -> AsyncStream<[EventHourSection]> {
        AsyncStream { continuation in
            let token = playaDB.observeEventsByHour(filter: filter) { sections in
                continuation.yield(sections)
            } onError: { error in
                print("Event observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    /// Observe events bucketed by day then hour. Use this in browse mode with a full-festival
    /// filter (no startDate/endDate). The view model slices `dict[selectedDay]` in memory so
    /// day-tab taps perform zero DB work.
    func observeObjectsByDayThenHour(filter: EventFilter) -> AsyncStream<[Date: [EventHourSection]]> {
        AsyncStream { continuation in
            let token = playaDB.observeEventsByDayThenHour(filter: filter) { bucket in
                continuation.yield(bucket)
            } onError: { error in
                print("Event observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    func toggleFavorite(_ object: EventObjectOccurrence) async throws {
        try await playaDB.toggleFavorite(object)
        let isFavorite = try await playaDB.isFavorite(object)
        // Fire-and-forget mirror into legacy YapDatabase; PlayaDB is the source
        // of truth and the UI must not wait on the Yap write. The occurrence's
        // composite identity mirrors onto the one matching Yap occurrence and
        // reconciles the event's calendar entries.
        let favoriteSync = self.favoriteSync
        let identity = object.favoriteIdentity
        Task {
            await favoriteSync.mirrorFavorite(type: .event, uid: identity, isFavorite: isFavorite)
        }
    }

    /// Walk/bike estimate, embargo-gated and sanity-clamped in `PlayaDistanceString`. An
    /// event follows its host's tier, so an art-hosted event stays dark until art unlocks.
    func distanceAttributedString(from location: CLLocation?, to object: EventObjectOccurrence) -> AttributedString? {
        PlayaDistanceString.forEvent(from: location, to: object)
    }
}
