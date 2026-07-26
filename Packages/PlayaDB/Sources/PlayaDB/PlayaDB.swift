import Foundation
import CoreLocation
import MapKit

/// Public interface for the PlayaDB database system
public protocol PlayaDB {
    // MARK: - Data Access

    /// Fetch all art objects
    func fetchArt() async throws -> [ArtObject]

    /// Fetch all camps
    func fetchCamps() async throws -> [CampObject]

    /// Fetch all events with their occurrences
    func fetchEvents() async throws -> [EventObjectOccurrence]

    /// Fetch events occurring on a specific date (no midnight splitting - events spanning days appear on all relevant days)
    func fetchEvents(on date: Date) async throws -> [EventObjectOccurrence]

    /// Fetch events occurring within a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [EventObjectOccurrence]

    /// Fetch currently happening events
    func fetchCurrentEvents(_ now: Date) async throws -> [EventObjectOccurrence]

    /// Fetch upcoming events (starting within the next N hours)
    func fetchUpcomingEvents(within hours: Int, from now: Date) async throws -> [EventObjectOccurrence]

    /// Fetch all mutant vehicles
    func fetchMutantVehicles() async throws -> [MutantVehicleObject]

    /// Fetch mutant vehicles matching the specified filter criteria
    func fetchMutantVehicles(filter: MutantVehicleFilter) async throws -> [MutantVehicleObject]

    /// Fetch a single mutant vehicle by UID
    func fetchMutantVehicle(uid: String) async throws -> MutantVehicleObject?

    /// Observe mutant vehicles matching the specified filter criteria.
    /// Returns fully-inflated `ListRow`s with metadata and thumbnail colors.
    @discardableResult
    func observeMutantVehicles(
        filter: MutantVehicleFilter,
        onChange: @escaping ([ListRow<MutantVehicleObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Fetch remote thumbnail URLs for mutant vehicles (uid -> URL)
    func fetchMutantVehicleImageURLs() async throws -> [String: URL]

    /// Fetch remote thumbnail URLs for art objects (uid -> URL)
    func fetchArtImageURLs() async throws -> [String: URL]

    /// Fetch remote thumbnail URLs for camp objects (uid -> URL)
    func fetchCampImageURLs() async throws -> [String: URL]

    /// Fetch all objects within a geographic region
    func fetchObjects(in region: MKCoordinateRegion) async throws -> [any DataObject]

    /// Search for objects using full-text search
    func searchObjects(_ query: String) async throws -> [any DataObject]

    // MARK: - Filtered Data Access

    /// Fetch art objects matching the specified filter criteria
    ///
    /// - Parameter filter: Filter options for art objects (year, region, search, etc.)
    /// - Returns: Array of art objects matching all specified filter criteria
    ///
    /// Example:
    /// ```swift
    /// let filter = ArtFilter(year: 2025, region: mapRegion)
    /// let art = try await playaDB.fetchArt(filter: filter)
    /// ```
    func fetchArt(filter: ArtFilter) async throws -> [ArtObject]

    /// Fetch camp objects matching the specified filter criteria
    ///
    /// - Parameter filter: Filter options for camp objects (year, region, search, etc.)
    /// - Returns: Array of camp objects matching all specified filter criteria
    ///
    /// Example:
    /// ```swift
    /// let filter = CampFilter(region: mapRegion, searchText: "burner")
    /// let camps = try await playaDB.fetchCamps(filter: filter)
    /// ```
    func fetchCamps(filter: CampFilter) async throws -> [CampObject]

    /// Fetch event occurrences matching the specified filter criteria
    ///
    /// - Parameter filter: Filter options for events (time-based, region, search, etc.)
    /// - Returns: Array of event occurrences matching all specified filter criteria
    ///
    /// Example:
    /// ```swift
    /// let filter = EventFilter(happeningNow: true, region: mapRegion)
    /// let events = try await playaDB.fetchEvents(filter: filter)
    /// ```
    func fetchEvents(filter: EventFilter) async throws -> [EventObjectOccurrence]
    
    /// Observe art objects matching the specified filter criteria.
    /// Returns fully-inflated `ListRow`s with metadata and thumbnail colors.
    @discardableResult
    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ListRow<ArtObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe camp objects matching the specified filter criteria.
    /// Returns fully-inflated `ListRow`s with metadata and thumbnail colors.
    @discardableResult
    func observeCamps(
        filter: CampFilter,
        onChange: @escaping ([ListRow<CampObject>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe event occurrences matching the specified filter criteria.
    /// Returns fully-inflated `ListRow`s with metadata and thumbnail colors.
    @discardableResult
    func observeEvents(
        filter: EventFilter,
        onChange: @escaping ([ListRow<EventObjectOccurrence>]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe event occurrences pre-grouped by hour-of-day. Sections are sorted
    /// ascending by hour; rows within a section preserve the underlying ordering
    /// from `observeEvents` (start time).
    @discardableResult
    func observeEventsByHour(
        filter: EventFilter,
        onChange: @escaping ([EventHourSection]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe event occurrences bucketed by start-day then hour-of-day. The day key is
    /// the device-calendar `startOfDay` for each occurrence's start time. Use this for the
    /// browse list: subscribe once with a full-festival filter, then slice the result by
    /// day in the UI so day-tab switching never re-hits the database.
    @discardableResult
    func observeEventsByDayThenHour(
        filter: EventFilter,
        onChange: @escaping ([Date: [EventHourSection]]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    // MARK: - Single Object Fetch

    /// Fetch a single art object by UID
    func fetchArt(uid: String) async throws -> ArtObject?

    /// Fetch a single camp object by UID
    func fetchCamp(uid: String) async throws -> CampObject?

    /// Fetch a single event object by UID
    func fetchEvent(uid: String) async throws -> EventObject?

    /// Fetch all occurrences for a specific event by its UID
    func fetchOccurrences(forEventUID uid: String) async throws -> [EventObjectOccurrence]

    /// Fetch event occurrences hosted by a specific camp
    func fetchEvents(hostedByCampUID: String) async throws -> [EventObjectOccurrence]

    /// Fetch event occurrences located at a specific art installation
    func fetchEvents(locatedAtArtUID: String) async throws -> [EventObjectOccurrence]

    // MARK: - Metadata Operations

    /// Fetch metadata for the specified object, creating a default record if needed.
    func metadata(for object: any DataObject) async throws -> ObjectMetadata
    
    /// Get all favorited objects
    func getFavorites() async throws -> [any DataObject]
    
    /// Toggle the favorite status of an object
    func toggleFavorite(_ object: any DataObject) async throws

    /// Set the favorite status of an object to a specific value
    func setFavorite(_ isFavorite: Bool, for object: any DataObject) async throws

    /// Check if an object is favorited
    func isFavorite(_ object: any DataObject) async throws -> Bool

    /// Set the visit status of an object. Setting the same value again is a
    /// no-op (no write), and `.unvisited` never materializes a metadata row.
    func setVisitStatus(_ status: VisitStatus, for object: any DataObject) async throws

    /// Get all objects with the given visit status
    func fetchObjects(visitStatus: VisitStatus) async throws -> [any DataObject]

    /// Update user notes for an object (nil/empty clears notes).
    func setUserNotes(_ notes: String?, for object: any DataObject) async throws

    /// Mark an object as viewed at the provided date (used for recents, etc.).
    func setLastViewed(_ date: Date, for object: any DataObject) async throws

    /// Fetch recently viewed objects, ordered by most recent first
    func fetchRecentlyViewed(limit: Int) async throws -> [any DataObject]

    /// Fetch recently viewed objects with their view dates, ordered by most recent first
    func fetchRecentlyViewedWithDates(limit: Int) async throws -> [(object: any DataObject, firstViewed: Date?, lastViewed: Date)]

    /// Clear the last-viewed date for a single object (removes it from recently viewed)
    func clearLastViewed(for object: any DataObject) async throws

    /// Clear all recently viewed history
    func clearAllRecentlyViewed() async throws

    /// Fetch favorited events with their occurrences (for schedule optimization)
    func fetchFavoriteEvents() async throws -> [EventObjectOccurrence]

    /// Batch fetch objects of any type by their UIDs (4 queries total, one per type)
    func fetchObjects(byUIDs uids: [String]) async throws -> [any DataObject]

    // MARK: - Favorite Sync

    /// Snapshot of all favorite/visit states that have ever been explicitly set
    /// (rows with a non-nil favorite or visit stamp), for last-writer-wins sync.
    /// Ordered by objectType then objectId for determinism.
    func favoriteSyncSnapshot() async throws -> [FavoriteSyncItem]

    /// Merge incoming favorite/visit states using per-field last-writer-wins:
    /// the favorite and visit-status fields merge independently, each on its
    /// own dedicated stamp. Same-state fields are skipped and rows where no
    /// field applies are never written, so applying a peer's snapshot never
    /// re-fires observations. Returns the items for which at least one field
    /// was applied.
    @discardableResult
    func applyFavoriteSync(_ items: [FavoriteSyncItem]) async throws -> [FavoriteSyncItem]

    /// Observe the favorite sync snapshot reactively (same query as
    /// `favoriteSyncSnapshot()`).
    @discardableResult
    func observeFavoriteSyncState(onChange: @escaping ([FavoriteSyncItem]) -> Void, onError: @escaping (Error) -> Void) -> PlayaDBObservationToken

    // MARK: - Thumbnail Colors

    /// Save (insert or replace) a single thumbnail color entry.
    func saveThumbnailColors(_ colors: ThumbnailColors) async throws

    /// Save a batch of thumbnail color entries in a single transaction.
    func saveThumbnailColorsBatch(_ batch: [ThumbnailColors]) async throws

    /// Fetch cached thumbnail colors for an object.
    func fetchThumbnailColors(objectId: String) async throws -> ThumbnailColors?

    /// Fetch all object IDs that have cached thumbnail colors.
    func fetchCachedColorObjectIDs() async throws -> Set<String>

    // MARK: - User Map Pins

    /// Save (insert or update) a user map pin.
    func saveUserMapPin(_ pin: UserMapPin) async throws

    /// Delete a user map pin by id. This is a soft delete: the row is kept as a
    /// tombstone (`isDeleted`) so the deletion can propagate through sync.
    func deleteUserMapPin(id: String) async throws

    /// Fetch all user map pins, tombstones excluded.
    func fetchUserMapPins() async throws -> [UserMapPin]

    /// Observe all user map pins reactively, tombstones excluded.
    @discardableResult
    func observeUserMapPins(onChange: @escaping ([UserMapPin]) -> Void) -> PlayaDBObservationToken

    // MARK: - Calendar Entries

    /// Save (insert or replace) the EventKit identifier for one event occurrence.
    /// Upsert on (`eventId`, `occurrenceKey`).
    func saveCalendarEntry(_ entry: EventCalendarEntry) async throws

    /// Fetch all calendar entries for an event, ordered by occurrence key.
    func fetchCalendarEntries(eventId: String) async throws -> [EventCalendarEntry]

    /// Delete every calendar entry belonging to an event (used when a favorite is removed).
    func deleteCalendarEntries(eventId: String) async throws

    /// Fetch every calendar entry, ordered by event id then occurrence key.
    func fetchAllCalendarEntries() async throws -> [EventCalendarEntry]

    // MARK: - User Map Pin Sync

    /// Snapshot of every pin row **including tombstones**, for last-writer-wins
    /// sync. Ordered by id for determinism.
    func userMapPinSyncSnapshot() async throws -> [UserMapPin]

    /// Merge incoming pins using last-writer-wins on `modifiedDate`. Older or
    /// equally-stamped incoming rows lose, tombstones for unknown pins are
    /// ignored, and rows that would be unchanged are never written — so
    /// applying a peer's snapshot cannot re-fire local observations. Returns the
    /// rows that were actually written.
    @discardableResult
    func applyUserMapPinSync(_ pins: [UserMapPin]) async throws -> [UserMapPin]

    /// Observe the pin sync snapshot reactively (same query as
    /// `userMapPinSyncSnapshot()`).
    @discardableResult
    func observeUserMapPinSyncState(
        onChange: @escaping ([UserMapPin]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    // MARK: - Data Import
    
    /// Import data from the PlayaAPI
    func importFromPlayaAPI() async throws
    
    /// Import data from provided JSON data. `updateData` is the accompanying update.json;
    /// when provided, its per-type timestamps are stored as each type's `lastUpdated` so
    /// later imports can detect whether bundled data is newer than what's in the database.
    func importFromData(artData: Data, campData: Data, eventData: Data, mvData: Data?, updateData: Data?) async throws

    /// Whether the data described by `bundleUpdateData` (an update.json payload) is newer
    /// than what has been imported. Returns true when the database has never been seeded,
    /// when a data type in the bundle has no imported counterpart, or when the bundle's
    /// timestamp for any type is newer than the stored `lastUpdated`.
    func needsImport(bundleUpdateData: Data) async throws -> Bool

    /// Get update information for all data types
    func getUpdateInfo() async throws -> [UpdateInfo]

    /// Observe update info changes reactively
    @discardableResult
    func observeUpdateInfo(onChange: @escaping ([UpdateInfo]) -> Void, onError: @escaping (Error) -> Void) -> PlayaDBObservationToken

    // MARK: - Distribution

    /// Compacts the database and folds the write-ahead log back into the main file,
    /// so the `.sqlite` can be shipped on its own without its `-wal`/`-shm` sidecars.
    ///
    /// Only meaningful for on-disk databases; harmless on in-memory ones. Intended for
    /// the seed tool — the app never needs to call this.
    func compactForDistribution() async throws
}

// MARK: - Observation Convenience

public extension PlayaDB {
    @discardableResult
    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ListRow<ArtObject>]) -> Void
    ) -> PlayaDBObservationToken {
        observeArt(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeCamps(
        filter: CampFilter,
        onChange: @escaping ([ListRow<CampObject>]) -> Void
    ) -> PlayaDBObservationToken {
        observeCamps(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeEvents(
        filter: EventFilter,
        onChange: @escaping ([ListRow<EventObjectOccurrence>]) -> Void
    ) -> PlayaDBObservationToken {
        observeEvents(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeMutantVehicles(
        filter: MutantVehicleFilter,
        onChange: @escaping ([ListRow<MutantVehicleObject>]) -> Void
    ) -> PlayaDBObservationToken {
        observeMutantVehicles(filter: filter, onChange: onChange, onError: { _ in })
    }

    /// Convenience overload for importFromData without update.json metadata
    func importFromData(artData: Data, campData: Data, eventData: Data, mvData: Data?) async throws {
        try await importFromData(artData: artData, campData: campData, eventData: eventData, mvData: mvData, updateData: nil)
    }

    /// Convenience overload for importFromData without MV data
    func importFromData(artData: Data, campData: Data, eventData: Data) async throws {
        try await importFromData(artData: artData, campData: campData, eventData: eventData, mvData: nil)
    }
}

// MARK: - Factory

/// Create a new PlayaDB instance
/// This is a global factory function to avoid protocol metatype issues
public func createPlayaDB() throws -> PlayaDB {
    try PlayaDBImpl()
}

/// Create an in-memory PlayaDB instance. Nothing persists and no connection is
/// opened to the on-disk database — intended for SwiftUI previews and tests.
public func createInMemoryPlayaDB() throws -> PlayaDB {
    try PlayaDBImpl(dbPath: ":memory:")
}

/// Create a PlayaDB backed by a database file at an explicit path, rather than the
/// app's Documents directory. Used by the seed tool, which builds a database outside
/// any app container, and by tests that need a real file on disk.
public func createPlayaDB(atPath path: String) throws -> PlayaDB {
    try PlayaDBImpl(dbPath: path)
}

public extension PlayaDB {
    /// Create a new PlayaDB instance
    /// Note: Due to Swift limitations with protocol metatypes, prefer using the global
    /// createPlayaDB() function instead of calling this static method.
    static func create() throws -> PlayaDB {
        try PlayaDBImpl()
    }
}
