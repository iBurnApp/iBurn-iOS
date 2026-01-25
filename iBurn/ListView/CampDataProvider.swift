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

    func observeObjects(filter: CampFilter) -> AsyncStream<[CampObject]> {
        AsyncStream { continuation in
            let token = playaDB.observeCamps(filter: filter) { objects in
                continuation.yield(objects)
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
    }

    func isFavorite(_ object: CampObject) async throws -> Bool {
        try await playaDB.isFavorite(object)
    }

    func distanceString(from location: CLLocation?, to object: CampObject) -> String? {
        guard let location = location,
              let objectLocation = object.location else {
            return nil
        }

        let distance = location.distance(from: objectLocation)
        let attributedString = TTTLocationFormatter.brc_humanizedString(forDistance: distance)
        return attributedString?.string
    }
}
