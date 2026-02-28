//
//  FavoritesFilterable.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import Foundation
import PlayaDB

/// Minimal protocol for filters that can scope results to favorites only.
///
/// During the migration, the SwiftUI lists treat legacy (YapDatabase) favorites as the UI source of truth,
/// so we observe *all* rows from PlayaDB and apply favorites filtering client-side.
protocol FavoritesFilterable {
    var onlyFavorites: Bool { get set }
}

extension ArtFilter: FavoritesFilterable {}
extension CampFilter: FavoritesFilterable {}
extension EventFilter: FavoritesFilterable {}

