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
    }

    func distanceAttributedString(from location: CLLocation?, to object: MutantVehicleObject) -> AttributedString? {
        nil
    }
}
