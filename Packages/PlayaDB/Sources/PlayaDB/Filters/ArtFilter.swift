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
public struct ArtFilter {
    /// Filter by year (e.g., 2025)
    public var year: Int?

    /// Filter by geographic region (requires GPS coordinates)
    public var region: MKCoordinateRegion?

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
        self.region = region
        self.searchText = searchText
        self.onlyWithEvents = onlyWithEvents
        self.onlyFavorites = onlyFavorites
    }

    /// Filter that matches all art objects (no filtering)
    public static var all: ArtFilter {
        ArtFilter()
    }
}

// MARK: - Equatable

extension ArtFilter: Equatable {
    public static func == (lhs: ArtFilter, rhs: ArtFilter) -> Bool {
        lhs.year == rhs.year &&
        lhs.searchText == rhs.searchText &&
        lhs.onlyWithEvents == rhs.onlyWithEvents &&
        lhs.onlyFavorites == rhs.onlyFavorites &&
        lhs.region?.center.latitude == rhs.region?.center.latitude &&
        lhs.region?.center.longitude == rhs.region?.center.longitude &&
        lhs.region?.span.latitudeDelta == rhs.region?.span.latitudeDelta &&
        lhs.region?.span.longitudeDelta == rhs.region?.span.longitudeDelta
    }
}

// MARK: - Hashable

extension ArtFilter: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(searchText)
        hasher.combine(onlyWithEvents)
        hasher.combine(onlyFavorites)
        hasher.combine(region?.center.latitude)
        hasher.combine(region?.center.longitude)
        hasher.combine(region?.span.latitudeDelta)
        hasher.combine(region?.span.longitudeDelta)
    }
}
