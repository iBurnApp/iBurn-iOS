//
//  QueryInterfaceRequest+DataObject.swift
//  PlayaDB
//
//  Created by Claude on 10/19/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import GRDB
import CoreLocation
import MapKit

// MARK: - Common DataObject Queries for ArtObject

extension QueryInterfaceRequest where RowDecoder == ArtObject {
    /// Order by name
    public func orderedByName() -> Self {
        self.order(ArtObject.Columns.name.asc)
    }

    /// Filter by year
    public func forYear(_ year: Int) -> Self {
        self.filter(ArtObject.Columns.year == year)
    }

    /// Only objects with descriptions
    public func withDescription() -> Self {
        self.filter(ArtObject.Columns.description != nil)
    }

    /// Search in description
    public func descriptionContains(_ text: String) -> Self {
        self.filter(ArtObject.Columns.description.like("%\(text)%"))
    }

    /// Geographic filtering
    public func inRegion(_ region: MKCoordinateRegion) -> Self {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return self
            .filter(ArtObject.Columns.gpsLatitude >= minLat)
            .filter(ArtObject.Columns.gpsLatitude <= maxLat)
            .filter(ArtObject.Columns.gpsLongitude >= minLon)
            .filter(ArtObject.Columns.gpsLongitude <= maxLon)
    }

    /// Only objects with valid GPS coordinates
    public func withLocation() -> Self {
        self
            .filter(ArtObject.Columns.gpsLatitude != nil)
            .filter(ArtObject.Columns.gpsLongitude != nil)
    }

    /// Order by distance approximation
    public func orderedByDistance(from coordinate: CLLocationCoordinate2D) -> Self {
        let latDiff = ArtObject.Columns.gpsLatitude - coordinate.latitude
        let lonDiff = ArtObject.Columns.gpsLongitude - coordinate.longitude
        let distanceApprox = latDiff * latDiff + lonDiff * lonDiff
        return self.order(distanceApprox.asc)
    }

    /// Only art installations that have associated events
    public func withEvents() -> Self {
        self.filter(
            sql: """
                EXISTS (
                    SELECT 1
                    FROM event_objects
                    WHERE event_objects.located_at_art = art_objects.uid
                )
            """
        )
    }
}

// MARK: - Common DataObject Queries for CampObject

extension QueryInterfaceRequest where RowDecoder == CampObject {
    /// Order by name
    public func orderedByName() -> Self {
        self.order(CampObject.Columns.name.asc)
    }

    /// Filter by year
    public func forYear(_ year: Int) -> Self {
        self.filter(CampObject.Columns.year == year)
    }

    /// Only objects with descriptions
    public func withDescription() -> Self {
        self.filter(CampObject.Columns.description != nil)
    }

    /// Search in description
    public func descriptionContains(_ text: String) -> Self {
        self.filter(CampObject.Columns.description.like("%\(text)%"))
    }

    /// Geographic filtering
    public func inRegion(_ region: MKCoordinateRegion) -> Self {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return self
            .filter(CampObject.Columns.gpsLatitude >= minLat)
            .filter(CampObject.Columns.gpsLatitude <= maxLat)
            .filter(CampObject.Columns.gpsLongitude >= minLon)
            .filter(CampObject.Columns.gpsLongitude <= maxLon)
    }

    /// Only objects with valid GPS coordinates
    public func withLocation() -> Self {
        self
            .filter(CampObject.Columns.gpsLatitude != nil)
            .filter(CampObject.Columns.gpsLongitude != nil)
    }

    /// Order by distance approximation
    public func orderedByDistance(from coordinate: CLLocationCoordinate2D) -> Self {
        let latDiff = CampObject.Columns.gpsLatitude - coordinate.latitude
        let lonDiff = CampObject.Columns.gpsLongitude - coordinate.longitude
        let distanceApprox = latDiff * latDiff + lonDiff * lonDiff
        return self.order(distanceApprox.asc)
    }
}

// MARK: - Common DataObject Queries for EventObject

extension QueryInterfaceRequest where RowDecoder == EventObject {
    /// Order by name
    public func orderedByName() -> Self {
        self.order(EventObject.Columns.name.asc)
    }

    /// Filter by year
    public func forYear(_ year: Int) -> Self {
        self.filter(EventObject.Columns.year == year)
    }

    /// Only objects with descriptions
    public func withDescription() -> Self {
        self.filter(EventObject.Columns.description != nil)
    }

    /// Search in description
    public func descriptionContains(_ text: String) -> Self {
        self.filter(EventObject.Columns.description.like("%\(text)%"))
    }

    /// Geographic filtering
    public func inRegion(_ region: MKCoordinateRegion) -> Self {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return self
            .filter(EventObject.Columns.gpsLatitude >= minLat)
            .filter(EventObject.Columns.gpsLatitude <= maxLat)
            .filter(EventObject.Columns.gpsLongitude >= minLon)
            .filter(EventObject.Columns.gpsLongitude <= maxLon)
    }

    /// Only objects with valid GPS coordinates
    public func withLocation() -> Self {
        self
            .filter(EventObject.Columns.gpsLatitude != nil)
            .filter(EventObject.Columns.gpsLongitude != nil)
    }

    /// Order by distance approximation
    public func orderedByDistance(from coordinate: CLLocationCoordinate2D) -> Self {
        let latDiff = EventObject.Columns.gpsLatitude - coordinate.latitude
        let lonDiff = EventObject.Columns.gpsLongitude - coordinate.longitude
        let distanceApprox = latDiff * latDiff + lonDiff * lonDiff
        return self.order(distanceApprox.asc)
    }
}

// MARK: - Event Occurrence Queries

extension QueryInterfaceRequest where RowDecoder == EventOccurrence {
    /// Only events that haven't expired
    public func notExpired(at date: Date = Date()) -> Self {
        self.filter(EventOccurrence.Columns.endTime > date)
    }

    /// Events happening now
    public func happeningNow(at date: Date = Date()) -> Self {
        self
            .filter(EventOccurrence.Columns.startTime <= date)
            .filter(EventOccurrence.Columns.endTime > date)
    }

    /// Upcoming events (starting within X hours)
    public func startingWithin(hours: Int, from date: Date = Date()) -> Self {
        let endDate = Calendar.current.date(byAdding: .hour, value: hours, to: date) ?? date
        return self
            .filter(EventOccurrence.Columns.startTime >= date)
            .filter(EventOccurrence.Columns.startTime <= endDate)
    }

    /// Order by start time
    public func orderedByStartTime() -> Self {
        self.order(EventOccurrence.Columns.startTime.asc)
    }
}

// MARK: - Full-Text Search

extension QueryInterfaceRequest where RowDecoder: TableRecord {
    /// Full-text search using FTS5
    public func matching(searchText: String?) -> Self {
        guard let searchText = searchText, !searchText.isEmpty else {
            return self
        }
        let pattern = FTS5Pattern(matchingAllTokensIn: searchText)
        let tableName = RowDecoder.databaseTableName
        let ftsTableName = "\(tableName)_fts"
        return self.filter(
            sql: """
                rowid IN (
                    SELECT rowid
                    FROM \"\(ftsTableName)\"
                    WHERE \"\(ftsTableName)\" MATCH ?
                )
            """,
            arguments: [pattern]
        )
    }
}

// MARK: - Favorites Filter

extension QueryInterfaceRequest where RowDecoder: FetchableRecord & TableRecord, RowDecoder.Columns: DataObjectColumns {
    /// Filters to only objects marked as favorites in metadata.
    public func onlyFavorites(ofType type: DataObjectType) -> Self {
        let favoritesPredicate: SQL = SQL("""
            EXISTS (
                SELECT 1
                FROM object_metadata
                WHERE object_metadata.object_type = \(type.rawValue)
                  AND object_metadata.object_id = \(RowDecoder.Columns.uid)
                  AND object_metadata.is_favorite = 1
            )
        """)
        return self.filter(favoritesPredicate)
    }
}
