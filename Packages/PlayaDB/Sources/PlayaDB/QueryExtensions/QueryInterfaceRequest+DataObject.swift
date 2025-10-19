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

// MARK: - Common DataObject Queries

extension QueryInterfaceRequest {
    /// Generic name search (works for any model with DataObjectColumns)
    public func matching(name searchText: String?) -> Self where RowDecoder.Columns: DataObjectColumns {
        guard let searchText = searchText, !searchText.isEmpty else {
            return self
        }
        return self.filter(RowDecoder.Columns.name.like("%\(searchText)%"))
    }

    /// Generic name ordering (works for any model with DataObjectColumns)
    public func orderedByName() -> Self where RowDecoder.Columns: DataObjectColumns {
        self.order(RowDecoder.Columns.name.asc)
    }

    /// Filter by year
    public func forYear(_ year: Int) -> Self where RowDecoder.Columns: DataObjectColumns {
        self.filter(RowDecoder.Columns.year == year)
    }

    /// Only objects with descriptions
    public func withDescription() -> Self where RowDecoder.Columns: DataObjectColumns {
        self.filter(RowDecoder.Columns.description != nil)
    }

    /// Search in description
    public func descriptionContains(_ text: String) -> Self where RowDecoder.Columns: DataObjectColumns {
        self.filter(RowDecoder.Columns.description.like("%\(text)%"))
    }
}

// MARK: - Geographic Queries

extension QueryInterfaceRequest {
    /// Generic geographic filtering (works for any model with GeoLocatableColumns)
    public func inRegion(_ region: MKCoordinateRegion) -> Self where RowDecoder.Columns: GeoLocatableColumns {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return self
            .filter(RowDecoder.Columns.gpsLatitude >= minLat)
            .filter(RowDecoder.Columns.gpsLatitude <= maxLat)
            .filter(RowDecoder.Columns.gpsLongitude >= minLon)
            .filter(RowDecoder.Columns.gpsLongitude <= maxLon)
    }

    /// Only objects with valid GPS coordinates
    public func withLocation() -> Self where RowDecoder.Columns: GeoLocatableColumns {
        self
            .filter(RowDecoder.Columns.gpsLatitude != nil)
            .filter(RowDecoder.Columns.gpsLongitude != nil)
    }

    /// Order by distance approximation (for initial filtering, use Haversine in Swift for exact distance)
    public func orderedByDistance(from coordinate: CLLocationCoordinate2D) -> Self where RowDecoder.Columns: GeoLocatableColumns {
        // Simple Pythagorean approximation for SQL sorting
        // For exact calculations, post-process in Swift with Haversine formula
        let latDiff = RowDecoder.Columns.gpsLatitude - coordinate.latitude
        let lonDiff = RowDecoder.Columns.gpsLongitude - coordinate.longitude
        let distanceApprox = latDiff * latDiff + lonDiff * lonDiff

        return self.order(distanceApprox.asc)
    }
}

// MARK: - Event Occurrence Queries

extension QueryInterfaceRequest {
    /// Only events that haven't expired
    public func notExpired(at date: Date = Date.present) -> Self where RowDecoder.Columns: EventOccurrenceColumns {
        self.filter(RowDecoder.Columns.endTime > date)
    }

    /// Events happening now
    public func happeningNow(at date: Date = Date.present) -> Self where RowDecoder.Columns: EventOccurrenceColumns {
        self
            .filter(RowDecoder.Columns.startTime <= date)
            .filter(RowDecoder.Columns.endTime > date)
    }

    /// Upcoming events (starting within X hours)
    public func startingWithin(hours: Int, from date: Date = Date.present) -> Self where RowDecoder.Columns: EventOccurrenceColumns {
        let endDate = Calendar.current.date(byAdding: .hour, value: hours, to: date) ?? date
        return self
            .filter(RowDecoder.Columns.startTime >= date)
            .filter(RowDecoder.Columns.startTime <= endDate)
    }

    /// Order by start time
    public func orderedByStartTime() -> Self where RowDecoder.Columns: EventOccurrenceColumns {
        self.order(RowDecoder.Columns.startTime.asc)
    }
}

// MARK: - Full-Text Search

extension QueryInterfaceRequest {
    /// Full-text search using FTS5
    public func matching(searchText: String?) -> Self {
        guard let searchText = searchText, !searchText.isEmpty else {
            return self
        }
        let pattern = FTS5Pattern(matchingAllTokensIn: searchText)
        return self.matching(pattern)
    }
}

// MARK: - Favorites Filter

extension QueryInterfaceRequest where RowDecoder: DataObject {
    /// Filter to only favorited objects (generic for all DataObjects)
    public func onlyFavorites() -> Self {
        // Derive object type name from table name
        let tableName = RowDecoder.databaseTableName
        let objectType = tableName.replacingOccurrences(of: "_objects", with: "")

        return self.joining(
            required: ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == objectType)
                .filter(ObjectMetadata.Columns.isFavorite == true)
        )
    }
}
