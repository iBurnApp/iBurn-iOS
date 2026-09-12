//
//  ArtDataProvider.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

/// Data provider for Art objects
///
/// Implements ObjectListDataProvider to provide art-specific data operations
/// including observation, favorite management, and distance calculations.
class ArtDataProvider: ObjectListDataProvider {
    typealias Object = ArtObject
    typealias Filter = ArtFilter

    private let playaDB: PlayaDB

    /// Initialize the data provider
    /// - Parameter playaDB: The PlayaDB instance to use for data access
    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    func isDatabaseSeeded() async -> Bool {
        guard let updateInfo = try? await playaDB.getUpdateInfo() else { return false }
        return !updateInfo.isEmpty
    }

    // MARK: - ObjectListDataProvider

    func observeObjects(filter: ArtFilter) -> AsyncStream<[ListRow<ArtObject>]> {
        AsyncStream { continuation in
            let token = playaDB.observeArt(filter: filter) { rows in
                continuation.yield(rows)
            } onError: { error in
                print("Art observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    func toggleFavorite(_ object: ArtObject) async throws {
        try await playaDB.toggleFavorite(object)
    }

    /// Walk/bike estimate, embargo-gated and sanity-clamped in `PlayaDistanceString` —
    /// art placement is the last thing to unlock, and an estimate leaks it just as surely
    /// as the address would.
    func distanceAttributedString(from location: CLLocation?, to object: ArtObject) -> AttributedString? {
        PlayaDistanceString.forArt(from: location, to: object.location)
    }
}
