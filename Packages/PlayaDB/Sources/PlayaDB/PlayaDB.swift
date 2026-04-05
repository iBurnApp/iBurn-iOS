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
    @discardableResult
    func observeMutantVehicles(
        filter: MutantVehicleFilter,
        onChange: @escaping ([MutantVehicleObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Fetch remote thumbnail URLs for mutant vehicles (uid -> URL)
    func fetchMutantVehicleImageURLs() async throws -> [String: URL]

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
    ///
    /// - Parameters:
    ///   - filter: Filter options for art objects.
    ///   - onChange: Called each time the underlying query results change.
    ///   - onError: Called if the observation encounters an error.
    /// - Returns: Token for cancelling the observation.
    @discardableResult
    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ArtObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe camp objects matching the specified filter criteria.
    @discardableResult
    func observeCamps(
        filter: CampFilter,
        onChange: @escaping ([CampObject]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken

    /// Observe event occurrences matching the specified filter criteria.
    @discardableResult
    func observeEvents(
        filter: EventFilter,
        onChange: @escaping ([EventObjectOccurrence]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> PlayaDBObservationToken
    
    // MARK: - Single Object Fetch

    /// Fetch a single art object by UID
    func fetchArt(uid: String) async throws -> ArtObject?

    /// Fetch a single camp object by UID
    func fetchCamp(uid: String) async throws -> CampObject?

    /// Fetch a single event object by UID
    func fetchEvent(uid: String) async throws -> EventObject?

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

    /// Update user notes for an object (nil/empty clears notes).
    func setUserNotes(_ notes: String?, for object: any DataObject) async throws

    /// Mark an object as viewed at the provided date (used for recents, etc.).
    func setLastViewed(_ date: Date, for object: any DataObject) async throws
    
    // MARK: - Data Import
    
    /// Import data from the PlayaAPI
    func importFromPlayaAPI() async throws
    
    /// Import data from provided JSON data (for testing)
    func importFromData(artData: Data, campData: Data, eventData: Data, mvData: Data?) async throws
    
    /// Get update information for all data types
    func getUpdateInfo() async throws -> [UpdateInfo]
    
    // MARK: - Reactive Data Access
    
    /// All art objects (reactive)
    var allArt: [ArtObject] { get }

    /// All camps (reactive)
    var allCamps: [CampObject] { get }

    /// All events with their occurrences (reactive)
    var allEvents: [EventObjectOccurrence] { get }

    /// All mutant vehicles (reactive)
    var allMutantVehicles: [MutantVehicleObject] { get }
    
    /// All favorited objects metadata (reactive)
    var favorites: [ObjectMetadata] { get }
}

// MARK: - Observation Convenience

public extension PlayaDB {
    @discardableResult
    func observeArt(
        filter: ArtFilter,
        onChange: @escaping ([ArtObject]) -> Void
    ) -> PlayaDBObservationToken {
        observeArt(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeCamps(
        filter: CampFilter,
        onChange: @escaping ([CampObject]) -> Void
    ) -> PlayaDBObservationToken {
        observeCamps(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeEvents(
        filter: EventFilter,
        onChange: @escaping ([EventObjectOccurrence]) -> Void
    ) -> PlayaDBObservationToken {
        observeEvents(filter: filter, onChange: onChange, onError: { _ in })
    }

    @discardableResult
    func observeMutantVehicles(
        filter: MutantVehicleFilter,
        onChange: @escaping ([MutantVehicleObject]) -> Void
    ) -> PlayaDBObservationToken {
        observeMutantVehicles(filter: filter, onChange: onChange, onError: { _ in })
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

public extension PlayaDB {
    /// Create a new PlayaDB instance
    /// Note: Due to Swift limitations with protocol metatypes, prefer using the global
    /// createPlayaDB() function instead of calling this static method.
    static func create() throws -> PlayaDB {
        try PlayaDBImpl()
    }
}
