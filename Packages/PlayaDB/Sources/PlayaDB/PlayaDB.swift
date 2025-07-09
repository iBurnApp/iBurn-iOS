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
    
    /// Fetch all events
    func fetchEvents() async throws -> [EventObject]
    
    /// Fetch all objects within a geographic region
    func fetchObjects(in region: MKCoordinateRegion) async throws -> [any DataObject]
    
    /// Search for objects using full-text search
    func searchObjects(_ query: String) async throws -> [any DataObject]
    
    // MARK: - Metadata Operations
    
    /// Get all favorited objects
    func getFavorites() async throws -> [any DataObject]
    
    /// Toggle the favorite status of an object
    func toggleFavorite(_ object: any DataObject) async throws
    
    /// Check if an object is favorited
    func isFavorite(_ object: any DataObject) async throws -> Bool
    
    // MARK: - Data Import
    
    /// Import data from the PlayaAPI
    func importFromPlayaAPI() async throws
    
    /// Get update information for all data types
    func getUpdateInfo() async throws -> [UpdateInfo]
    
    // MARK: - Reactive Data Access
    
    /// All art objects (reactive)
    var allArt: [ArtObject] { get }
    
    /// All camps (reactive)
    var allCamps: [CampObject] { get }
    
    /// All events (reactive)
    var allEvents: [EventObject] { get }
    
    /// All favorited objects metadata (reactive)
    var favorites: [ObjectMetadata] { get }
}

// MARK: - Factory

public extension PlayaDB {
    /// Create a new PlayaDB instance
    static func create() throws -> PlayaDB {
        try PlayaDBImpl()
    }
}