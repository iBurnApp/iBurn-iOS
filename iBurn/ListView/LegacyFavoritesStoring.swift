//
//  LegacyFavoritesStoring.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import Foundation
import PlayaDB

/// Minimal interface for reading/writing favorites in the legacy (YapDatabase) store.
///
/// The SwiftUI lists currently use legacy favorites as the UI source of truth during migration.
protocol LegacyFavoritesStoring: AnyObject {
    func favoriteIDs(for type: DataObjectType) async -> Set<String>
    func updateFavoriteStatus(uid: String, type: DataObjectType, isFavorite: Bool) async
}

