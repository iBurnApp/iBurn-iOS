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

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    func isDatabaseSeeded() async -> Bool {
        guard let updateInfo = try? await playaDB.getUpdateInfo() else { return false }
        return !updateInfo.isEmpty
    }

    // MARK: - ObjectListDataProvider

    func observeObjects(filter: EventFilter) -> AsyncStream<[EventObjectOccurrence]> {
        AsyncStream { continuation in
            let token = playaDB.observeEvents(filter: filter) { objects in
                continuation.yield(objects)
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
    }

    func isFavorite(_ object: EventObjectOccurrence) async throws -> Bool {
        try await playaDB.isFavorite(object)
    }

    func distanceAttributedString(from location: CLLocation?, to object: EventObjectOccurrence) -> AttributedString? {
        guard let location = location,
              let objectLocation = object.location else {
            return nil
        }

        let distance = location.distance(from: objectLocation)

        guard let nsAttributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance) else {
            return nil
        }
        return AttributedString(nsAttributedString)
    }
}
