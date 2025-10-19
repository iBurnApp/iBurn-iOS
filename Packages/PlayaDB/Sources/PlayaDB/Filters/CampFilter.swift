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
public struct CampFilter {
    /// Filter by year (e.g., 2025)
    public var year: Int?

    /// Filter by geographic region (requires GPS coordinates)
    public var region: MKCoordinateRegion?

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
        self.region = region
        self.searchText = searchText
        self.onlyFavorites = onlyFavorites
    }

    /// Filter that matches all camp objects (no filtering)
    public static var all: CampFilter {
        CampFilter()
    }
}

// MARK: - Equatable

extension CampFilter: Equatable {
    public static func == (lhs: CampFilter, rhs: CampFilter) -> Bool {
        lhs.year == rhs.year &&
        lhs.searchText == rhs.searchText &&
        lhs.onlyFavorites == rhs.onlyFavorites &&
        lhs.region?.center.latitude == rhs.region?.center.latitude &&
        lhs.region?.center.longitude == rhs.region?.center.longitude &&
        lhs.region?.span.latitudeDelta == rhs.region?.span.latitudeDelta &&
        lhs.region?.span.longitudeDelta == rhs.region?.span.longitudeDelta
    }
}

// MARK: - Hashable

extension CampFilter: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(searchText)
        hasher.combine(onlyFavorites)
        hasher.combine(region?.center.latitude)
        hasher.combine(region?.center.longitude)
        hasher.combine(region?.span.latitudeDelta)
        hasher.combine(region?.span.longitudeDelta)
    }
}
