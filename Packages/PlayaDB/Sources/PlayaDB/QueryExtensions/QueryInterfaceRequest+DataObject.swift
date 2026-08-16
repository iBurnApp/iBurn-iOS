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

// MARK: - Geo-Location via R*Tree

extension QueryInterfaceRequest where RowDecoder: DataObjectColumnProviding & TableRecord, RowDecoder.ColumnSet: GeoLocatableColumns {
    /// Geographic filtering via the point R*Tree (`spatial_index`), keyed by object type + uid.
    /// Equivalent to the prior bounding-box filter but served by the spatial index.
    public func inRegion(_ region: MKCoordinateRegion) -> Self {
        let b = FilterRegion(region).bounds
        let type: String
        switch RowDecoder.databaseTableName {
        case "art_objects": type = "art"
        case "camp_objects": type = "camp"
        case "event_objects": type = "event"
        default: type = ""
        }
        return filter(sql: """
            uid IN (
                SELECT so.object_uid FROM spatial_objects so
                JOIN spatial_index si ON si.id = so.spatial_id
                WHERE so.object_type = ?
                  AND si.maxLat >= ? AND si.minLat <= ?
                  AND si.maxLon >= ? AND si.minLon <= ?
            )
            """, arguments: [type, b.minLat, b.maxLat, b.minLon, b.maxLon])
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

    /// Filters on the presence of an audio-tour recording.
    ///
    /// Empty strings count as absent. The importer itself can never write one
    /// (`LenientURL` yields either a valid URL or nil), so this is defence in depth
    /// against hand-written or externally seeded rows.
    public func hasAudioTour(_ hasAudio: Bool) -> Self {
        // Parenthesized explicitly: predicates are combined with AND, and the
        // `false` branch is a disjunction that must not bind loosely.
        if hasAudio {
            return filter(sql: "(art_objects.audio_tour_url IS NOT NULL AND art_objects.audio_tour_url != '')")
        } else {
            return filter(sql: "(art_objects.audio_tour_url IS NULL OR art_objects.audio_tour_url = '')")
        }
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
    ///
    /// Uses **prefix** matching on every token (`temp* gard*`) rather than whole-token
    /// matching. Live search feeds this a partial query on each keystroke, and whole-token
    /// matching is all-or-nothing: "tem" matches nothing until the exact indexed token is
    /// typed. Prefixing every token (not just the last) keeps earlier words incremental too
    /// — "cent cam" still finds "Center Camp" — and matches how users type multi-word
    /// queries, none of which they expect to have to finish.
    ///
    /// The FTS tables are tokenized with `porter`, so indexed terms are stems. A prefix of
    /// the word is (for English suffix stemming) also a prefix of its stem, so prefix
    /// queries survive stemming: "templ*" matches the stem "templ" indexed for "Temple"
    /// and "Temples" alike. `prefix='2 3 4'` on the FTS tables (see
    /// `PlayaDBImpl.setupFTS5Tables`) makes the short prefixes typed first index-served
    /// rather than a full-table term scan.
    public func matching(searchText: String?) -> Self {
        guard let searchText = searchText, !searchText.isEmpty else {
            return self
        }
        let pattern = FTS5Pattern(matchingAllPrefixesIn: searchText)
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
