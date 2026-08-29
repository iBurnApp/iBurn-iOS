import Foundation
import GRDB

/// Metadata for data objects (app-specific data like favorites, notes, etc.)
public struct ObjectMetadata: Codable, Equatable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "object_metadata"
    
    // MARK: - Column Mapping

    public enum Columns: String, CodingKey, ColumnExpression {
        case objectType = "object_type"
        case objectId = "object_id"
        case isFavorite = "is_favorite"
        case firstViewed = "first_viewed"
        case lastViewed = "last_viewed"
        case userNotes = "user_notes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case favoriteUpdatedAt = "favorite_updated_at"
        case visitStatus = "visit_status"
        case visitStatusUpdatedAt = "visit_status_updated_at"
    }

    // Use Columns as CodingKeys
    private typealias CodingKeys = Columns
    /// Type of object this metadata belongs to
    public var objectType: String
    
    /// ID of the object this metadata belongs to
    public var objectId: String
    
    /// Whether this object is favorited by the user
    public var isFavorite: Bool

    /// When this object was first viewed by the user
    public var firstViewed: Date?

    /// When this object was last viewed by the user
    public var lastViewed: Date?
    
    /// User notes about this object
    public var userNotes: String?

    /// When this metadata was created
    public var createdAt: Date

    /// When this metadata was last updated
    public var updatedAt: Date

    /// When `isFavorite` was last explicitly changed. Unlike `updatedAt` (which is
    /// bumped by view tracking and notes writes), this stamp is dedicated to
    /// favorite changes so last-writer-wins sync can rely on it.
    public var favoriteUpdatedAt: Date?

    /// Raw `VisitStatus` value (0 = unvisited, 1 = visited, 2 = want to visit).
    /// Stored as a raw Int so unknown future values survive round-trips.
    public var visitStatus: Int

    /// When `visitStatus` was last explicitly changed. Like `favoriteUpdatedAt`,
    /// this stamp is dedicated to visit-status changes so last-writer-wins sync
    /// can rely on it (view tracking and notes writes never touch it).
    public var visitStatusUpdatedAt: Date?

    public init(
        objectType: String,
        objectId: String,
        isFavorite: Bool = false,
        firstViewed: Date? = nil,
        lastViewed: Date? = nil,
        userNotes: String? = nil,
        favoriteUpdatedAt: Date? = nil,
        visitStatus: Int = 0,
        visitStatusUpdatedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.objectType = objectType
        self.objectId = objectId
        self.isFavorite = isFavorite
        self.firstViewed = firstViewed
        self.lastViewed = lastViewed
        self.userNotes = userNotes
        self.favoriteUpdatedAt = favoriteUpdatedAt
        self.visitStatus = visitStatus
        self.visitStatusUpdatedAt = visitStatusUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Computed Properties

public extension ObjectMetadata {
    /// Data object type enum
    var dataObjectType: DataObjectType? {
        DataObjectType(rawValue: objectType)
    }
    
    /// Typed visit status; unknown raw values fall back to `.unvisited`.
    var visitStatusValue: VisitStatus {
        VisitStatus(rawValue: visitStatus) ?? .unvisited
    }

    /// Whether this metadata has user notes
    var hasUserNotes: Bool {
        userNotes != nil && !userNotes!.isEmpty
    }
    
    /// Whether this object has been viewed recently (within 24 hours)
    var viewedRecently: Bool {
        guard let lastViewed = lastViewed else { return false }
        return Date().timeIntervalSince(lastViewed) < 24 * 60 * 60
    }
}

// MARK: - Convenience Initializers

public extension ObjectMetadata {
    /// Create metadata for an art object
    static func forArt(id: String, isFavorite: Bool = false) -> ObjectMetadata {
        ObjectMetadata(
            objectType: DataObjectType.art.rawValue,
            objectId: id,
            isFavorite: isFavorite
        )
    }
    
    /// Create metadata for a camp
    static func forCamp(id: String, isFavorite: Bool = false) -> ObjectMetadata {
        ObjectMetadata(
            objectType: DataObjectType.camp.rawValue,
            objectId: id,
            isFavorite: isFavorite
        )
    }
    
    /// Create metadata for an event
    static func forEvent(id: String, isFavorite: Bool = false) -> ObjectMetadata {
        ObjectMetadata(
            objectType: DataObjectType.event.rawValue,
            objectId: id,
            isFavorite: isFavorite
        )
    }

    /// Create metadata for a mutant vehicle
    static func forMutantVehicle(id: String, isFavorite: Bool = false) -> ObjectMetadata {
        ObjectMetadata(
            objectType: DataObjectType.mutantVehicle.rawValue,
            objectId: id,
            isFavorite: isFavorite
        )
    }
}