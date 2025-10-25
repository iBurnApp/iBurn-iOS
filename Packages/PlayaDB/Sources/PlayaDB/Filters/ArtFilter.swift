//
//  ArtFilter.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapKit

/// Filter options for querying art objects
///
/// Use this struct to build filtered queries for art objects without exposing
/// database implementation details. All filters are optional and combine with AND logic.
///
/// Example:
/// ```swift
/// let filter = ArtFilter(
///     year: 2025,
///     region: currentMapRegion,
///     searchText: "temple"
/// )
/// let art = try await playaDB.fetchArt(filter: filter)
/// ```
public struct ArtFilter: Hashable, Codable {
    /// Filter by year (e.g., 2025)
    public var year: Int?

    /// Filter by geographic region (requires GPS coordinates)
    private var regionStorage: FilterRegion?

    /// Full-text search across name, description, artist, etc.
    public var searchText: String?

    /// Only show art pieces that have associated events
    public var onlyWithEvents: Bool

    /// Only show favorited art pieces
    public var onlyFavorites: Bool

    /// Create a new art filter
    public init(
        year: Int? = nil,
        region: MKCoordinateRegion? = nil,
        searchText: String? = nil,
        onlyWithEvents: Bool = false,
        onlyFavorites: Bool = false
    ) {
        self.year = year
        self.regionStorage = region.map(FilterRegion.init)
        self.searchText = searchText
        self.onlyWithEvents = onlyWithEvents
        self.onlyFavorites = onlyFavorites
    }

    /// Filter that matches all art objects (no filtering)
    public static var all: ArtFilter {
        ArtFilter()
    }

    /// The region expressed as `MKCoordinateRegion`.
    public var region: MKCoordinateRegion? {
        get { regionStorage?.coordinateRegion }
        set { regionStorage = newValue.map(FilterRegion.init) }
    }

    /// Accessor for the underlying hashable region representation.
    public var filterRegion: FilterRegion? {
        get { regionStorage }
        set { regionStorage = newValue }
    }
}
