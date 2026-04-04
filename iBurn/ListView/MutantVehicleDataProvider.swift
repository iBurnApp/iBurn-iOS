import Foundation
import CoreLocation
import PlayaDB

class MutantVehicleDataProvider: ObjectListDataProvider {
    typealias Object = MutantVehicleObject
    typealias Filter = MutantVehicleFilter

    private let playaDB: PlayaDB

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    func isDatabaseSeeded() async -> Bool {
        guard let updateInfo = try? await playaDB.getUpdateInfo() else { return false }
        return !updateInfo.isEmpty
    }

    func observeObjects(filter: MutantVehicleFilter) -> AsyncStream<[MutantVehicleObject]> {
        AsyncStream { continuation in
            let token = playaDB.observeMutantVehicles(filter: filter) { objects in
                continuation.yield(objects)
            } onError: { error in
                print("MV observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    func toggleFavorite(_ object: MutantVehicleObject) async throws {
        try await playaDB.toggleFavorite(object)
    }

    func isFavorite(_ object: MutantVehicleObject) async throws -> Bool {
        try await playaDB.isFavorite(object)
    }

    func distanceAttributedString(from location: CLLocation?, to object: MutantVehicleObject) -> AttributedString? {
        nil
    }
}
