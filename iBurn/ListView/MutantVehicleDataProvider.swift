import Foundation
import CoreLocation
import PlayaDB

class MutantVehicleDataProvider: ObjectListDataProvider {
    typealias Object = MutantVehicleObject
    typealias Filter = MutantVehicleFilter

    private let playaDB: PlayaDB
    private let favoriteSync: FavoriteSyncService

    init(playaDB: PlayaDB, favoriteSync: FavoriteSyncService = FavoriteSyncServiceFactory.shared) {
        self.playaDB = playaDB
        self.favoriteSync = favoriteSync
    }

    func isDatabaseSeeded() async -> Bool {
        guard let updateInfo = try? await playaDB.getUpdateInfo() else { return false }
        return !updateInfo.isEmpty
    }

    func observeObjects(filter: MutantVehicleFilter) -> AsyncStream<[ListRow<MutantVehicleObject>]> {
        AsyncStream { continuation in
            let token = playaDB.observeMutantVehicles(filter: filter) { rows in
                continuation.yield(rows)
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
        let isFavorite = try await playaDB.isFavorite(object)
        // Mutant vehicles have no legacy Yap class; the mirror is a documented no-op,
        // kept here so all four providers share the same favorite pipeline.
        let favoriteSync = self.favoriteSync
        Task {
            await favoriteSync.mirrorFavorite(type: .mutantVehicle, uid: object.uid, isFavorite: isFavorite)
        }
    }

    func distanceAttributedString(from location: CLLocation?, to object: MutantVehicleObject) -> AttributedString? {
        nil
    }
}
