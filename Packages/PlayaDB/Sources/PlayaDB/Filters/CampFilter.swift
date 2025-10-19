//
//  CampFilter.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapKit

/// Filter options for querying camp objects
///
/// Use this struct to build filtered queries for camp objects without exposing
/// database implementation details. All filters are optional and combine with AND logic.
///
/// Example:
/// ```swift
/// let filter = CampFilter(
///     year: 2025,
///     region: currentMapRegion,
///     searchText: "burner"
/// )
/// let camps = try await playaDB.fetchCamps(filter: filter)
/// ```
public struct CampFilter: Hashable {
    /// Filter by year (e.g., 2025)
    public var year: Int?

    /// Filter by geographic region (requires GPS coordinates)
    private var regionStorage: FilterRegion?

    /// Full-text search across name, description, hometown, etc.
    public var searchText: String?

    /// Only show favorited camps
    public var onlyFavorites: Bool

    /// Create a new camp filter
    public init(
        year: Int? = nil,
        region: MKCoordinateRegion? = nil,
        searchText: String? = nil,
        onlyFavorites: Bool = false
    ) {
        self.year = year
        self.regionStorage = region.map(FilterRegion.init)
        self.searchText = searchText
        self.onlyFavorites = onlyFavorites
    }

    /// Filter that matches all camp objects (no filtering)
    public static var all: CampFilter {
        CampFilter()
    }

    /// The region expressed as `MKCoordinateRegion`.
    public var region: MKCoordinateRegion? {
        get { regionStorage?.coordinateRegion }
        set { regionStorage = newValue.map(FilterRegion.init) }
    }

    /// Access the underlying hashable region representation.
    public var filterRegion: FilterRegion? {
        get { regionStorage }
        set { regionStorage = newValue }
    }
}
