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
/// PlayaDB (`object_metadata.is_favorite`) is the only store of favorites. Filters conform
/// so a list's favorites toggle can be applied either at the SQL level or client-side
/// against an unfiltered observation.
protocol FavoritesFilterable {
    var onlyFavorites: Bool { get set }
}

extension ArtFilter: FavoritesFilterable {}
extension CampFilter: FavoritesFilterable {}
extension EventFilter: FavoritesFilterable {}
extension MutantVehicleFilter: FavoritesFilterable {}

