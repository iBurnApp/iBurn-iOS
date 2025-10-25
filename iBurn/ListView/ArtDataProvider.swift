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

    // MARK: - ObjectListDataProvider

    func observeObjects(filter: ArtFilter) -> AsyncStream<[ArtObject]> {
        AsyncStream { continuation in
            // Observe art objects from PlayaDB
            let token = playaDB.observeArt(filter: filter) { objects in
                continuation.yield(objects)
            } onError: { error in
                print("Art observation error: \(error)")
            }

            // Cancel observation when stream terminates
            continuation.onTermination = { @Sendable _ in
                token.cancel()
            }
        }
    }

    func toggleFavorite(_ object: ArtObject) async throws {
        try await playaDB.toggleFavorite(object)
    }

    func isFavorite(_ object: ArtObject) async throws -> Bool {
        try await playaDB.isFavorite(object)
    }

    func distanceString(from location: CLLocation?, to object: ArtObject) -> String? {
        guard let location = location,
              let objectLocation = object.location else {
            return nil
        }

        let distance = location.distance(from: objectLocation)

        // Use existing TTTLocationFormatter for consistent formatting
        let attributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance)
        return attributedString?.string
    }
}
