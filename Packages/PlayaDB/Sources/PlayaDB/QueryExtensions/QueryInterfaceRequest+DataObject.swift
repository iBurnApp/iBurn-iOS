import GRDB
import CoreLocation
import MapKit

// MARK: - Generic DataObject Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding {
    private static var columns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Order by name
    public func orderedByName() -> Self {
        order(Self.columns.name.asc)
    }

    /// Filter by year
    public func forYear(_ year: Int) -> Self {
        filter(Self.columns.year == year)
    }

    /// Only objects with descriptions
    public func withDescription() -> Self {
        filter(Self.columns.description != nil)
    }

    /// Search in description
    public func descriptionContains(_ text: String) -> Self {
        filter(Self.columns.description.like("%\(text)%"))
    }
}

// MARK: - Generic Geo-Location Queries

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding, RowDecoder.ColumnSet: GeoLocatableColumns {
    private static var geoColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Geographic filtering using an `MKCoordinateRegion` bounding box.
    public func inRegion(_ region: MKCoordinateRegion) -> Self {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return self
            .filter(Self.geoColumns.gpsLatitude >= minLat)
            .filter(Self.geoColumns.gpsLatitude <= maxLat)
            .filter(Self.geoColumns.gpsLongitude >= minLon)
            .filter(Self.geoColumns.gpsLongitude <= maxLon)
    }

    /// Only objects with valid GPS coordinates.
    public func withLocation() -> Self {
        self
            .filter(Self.geoColumns.gpsLatitude != nil)
            .filter(Self.geoColumns.gpsLongitude != nil)
    }

    /// Order by squared distance approximation relative to a coordinate.
    public func orderedByDistance(from coordinate: CLLocationCoordinate2D) -> Self {
        let latDiff = Self.geoColumns.gpsLatitude - coordinate.latitude
        let lonDiff = Self.geoColumns.gpsLongitude - coordinate.longitude
        let distanceApprox = latDiff * latDiff + lonDiff * lonDiff
        return order(distanceApprox.asc)
    }
}

// MARK: - Art-Specific Queries

extension QueryInterfaceRequest where RowDecoder == ArtObject {
    /// Only art installations that have associated events.
    public func withEvents() -> Self {
        filter(
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

// MARK: - Event Occurrence Queries

extension QueryInterfaceRequest where RowDecoder == EventOccurrence {
    /// Only events that haven't expired.
    public func notExpired(at date: Date = Date()) -> Self {
        filter(EventOccurrence.Columns.endTime > date)
    }

    /// Events happening now.
    public func happeningNow(at date: Date = Date()) -> Self {
        self
            .filter(EventOccurrence.Columns.startTime <= date)
            .filter(EventOccurrence.Columns.endTime > date)
    }

    /// Upcoming events (starting within X hours).
    public func startingWithin(hours: Int, from date: Date = Date()) -> Self {
        let endDate = Calendar.current.date(byAdding: .hour, value: hours, to: date) ?? date
        return self
            .filter(EventOccurrence.Columns.startTime >= date)
            .filter(EventOccurrence.Columns.startTime <= endDate)
    }

    /// Order by start time.
    public func orderedByStartTime() -> Self {
        order(EventOccurrence.Columns.startTime.asc)
    }
}

// MARK: - Full-Text Search

extension QueryInterfaceRequest where RowDecoder: TableRecord {
    /// Full-text search using FTS5.
    public func matching(searchText: String?) -> Self {
        guard let searchText = searchText, !searchText.isEmpty else {
            return self
        }
        let pattern = FTS5Pattern(matchingAllTokensIn: searchText)
        let tableName = RowDecoder.databaseTableName
        let ftsTableName = "\(tableName)_fts"
        return filter(
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

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding & TableRecord & FetchableRecord {
    private static var favoriteColumns: RowDecoder.ColumnSet.Type { RowDecoder.columnSet }

    /// Filters to only objects marked as favorites in metadata.
    public func onlyFavorites(ofType type: DataObjectType) -> Self {
        let favoritesPredicate: SQL = SQL("""
            EXISTS (
                SELECT 1
                FROM object_metadata
                WHERE object_metadata.object_type = \(type.rawValue)
                  AND object_metadata.object_id = \(Self.favoriteColumns.uid)
                  AND object_metadata.is_favorite = 1
            )
        """)
        return filter(favoritesPredicate)
    }
}
