import Foundation
import SharingGRDB

/// Metadata for data objects (app-specific data like favorites, notes, etc.)
@Table("object_metadata")
public struct ObjectMetadata {
    /// Type of object this metadata belongs to
    public var objectType: String
    
    /// ID of the object this metadata belongs to
    public var objectId: String
    
    /// Whether this object is favorited by the user
    public var isFavorite: Bool
    
    /// When this object was last viewed by the user
    public var lastViewed: Date?
    
    /// User notes about this object
    public var userNotes: String?
    
    /// When this metadata was created
    public var createdAt: Date
    
    /// When this metadata was last updated
    public var updatedAt: Date
    
    public init(
        objectType: String,
        objectId: String,
        isFavorite: Bool = false,
        lastViewed: Date? = nil,
        userNotes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.objectType = objectType
        self.objectId = objectId
        self.isFavorite = isFavorite
        self.lastViewed = lastViewed
        self.userNotes = userNotes
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
}