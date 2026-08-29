//
//  CampDataProvider.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

/// Data provider for Camp objects
///
/// Implements ObjectListDataProvider to provide camp-specific data operations
/// including observation, favorite management, and distance calculations.
class CampDataProvider: ObjectListDataProvider {
    typealias Object = CampObject
    typealias Filter = CampFilter

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

    func observeObjects(filter: CampFilter) -> AsyncStream<[ListRow<CampObject>]> {
        AsyncStream { continuation in
            let token = playaDB.observeCamps(filter: filter) { rows in
                continuation.yield(rows)
            } onError: { error in
                print("Camp observation error: \(error)")
            }

            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    func toggleFavorite(_ object: CampObject) async throws {
        try await playaDB.toggleFavorite(object)
        let isFavorite = try await playaDB.isFavorite(object)
        // Fire-and-forget mirror into legacy YapDatabase; PlayaDB is the source
        // of truth and the UI must not wait on the Yap write.
        let favoriteSync = self.favoriteSync
        Task {
            await favoriteSync.mirrorFavorite(type: .camp, uid: object.uid, isFavorite: isFavorite)
        }
    }

    /// Walk/bike estimate, embargo-gated and sanity-clamped in `PlayaDistanceString`.
    func distanceAttributedString(from location: CLLocation?, to object: CampObject) -> AttributedString? {
        PlayaDistanceString.forCamp(from: location, to: object.location)
    }
}
