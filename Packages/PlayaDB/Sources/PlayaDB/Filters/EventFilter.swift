//
//  EventFilter.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapKit

/// Filter options for querying event occurrences
///
/// Use this struct to build filtered queries for event occurrences without exposing
/// database implementation details. All filters are optional and combine with AND logic.
///
/// Example:
/// ```swift
/// let filter = EventFilter(
///     happeningNow: true,
///     region: currentMapRegion
/// )
/// let events = try await playaDB.fetchEvents(filter: filter)
/// ```
public struct EventFilter: Hashable {
    /// Filter by year (e.g., 2025)
    public var year: Int?

    /// Filter by geographic region (requires GPS coordinates from host camp/art)
    private var regionStorage: FilterRegion?

    /// Full-text search across event name, description, etc.
    public var searchText: String?

    /// Only show favorited events
    public var onlyFavorites: Bool

    /// Include expired events (events that have already ended)
    /// Default: true (show all events including past)
    public var includeExpired: Bool

    /// Only show events currently happening
    /// Overrides other time-based filters if true
    public var happeningNow: Bool

    /// Only show events starting within the next N hours
    /// Example: startingWithinHours = 2 shows events starting in next 2 hours
    public var startingWithinHours: Int?

    /// Create a new event filter
    public init(
        year: Int? = nil,
        region: MKCoordinateRegion? = nil,
        searchText: String? = nil,
        onlyFavorites: Bool = false,
        includeExpired: Bool = true,
        happeningNow: Bool = false,
        startingWithinHours: Int? = nil
    ) {
        self.year = year
        self.regionStorage = region.map(FilterRegion.init)
        self.searchText = searchText
        self.onlyFavorites = onlyFavorites
        self.includeExpired = includeExpired
        self.happeningNow = happeningNow
        self.startingWithinHours = startingWithinHours
    }

    /// Filter that matches all events (no filtering)
    public static var all: EventFilter {
        EventFilter()
    }

    /// Filter for currently happening events
    public static var happening: EventFilter {
        EventFilter(happeningNow: true)
    }

    /// Filter for upcoming events (not expired, not currently happening)
    public static var upcoming: EventFilter {
        EventFilter(includeExpired: false)
    }

    /// Filter for events starting within the next N hours
    public static func startingSoon(hours: Int) -> EventFilter {
        EventFilter(startingWithinHours: hours)
    }

    /// Region expressed as `MKCoordinateRegion`.
    public var region: MKCoordinateRegion? {
        get { regionStorage?.coordinateRegion }
        set { regionStorage = newValue.map(FilterRegion.init) }
    }

    /// Underlying hashable region representation.
    public var filterRegion: FilterRegion? {
        get { regionStorage }
        set { regionStorage = newValue }
    }
}
