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
    private let favoriteSync: FavoriteSyncService

    /// Initialize the data provider
    /// - Parameters:
    ///   - playaDB: The PlayaDB instance to use for data access
    ///   - favoriteSync: Mirrors favorite changes into the legacy YapDatabase
    init(playaDB: PlayaDB, favoriteSync: FavoriteSyncService = FavoriteSyncServiceFactory.shared) {
        self.playaDB = playaDB
        self.favoriteSync = favoriteSync
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
        let isFavorite = try await playaDB.isFavorite(object)
        // Fire-and-forget mirror into legacy YapDatabase; PlayaDB is the source
        // of truth and the UI must not wait on the Yap write.
        let favoriteSync = self.favoriteSync
        Task {
            await favoriteSync.mirrorFavorite(type: .art, uid: object.uid, isFavorite: isFavorite)
        }
    }

    func distanceAttributedString(from location: CLLocation?, to object: ArtObject) -> AttributedString? {
        guard let location = location,
              let objectLocation = object.location else {
            return nil
        }

        let distance = location.distance(from: objectLocation)

        // Use existing TTTLocationFormatter for consistent walk/bike estimates + coloring.
        guard let nsAttributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance) else {
            return nil
        }
        return AttributedString(nsAttributedString)
    }
}
