import Foundation
import GRDB

/// Information about data updates and versioning
public struct UpdateInfo: Codable, FetchableRecord, MutablePersistableRecord {
    // MARK: - Table Configuration
    
    public static let databaseTableName = "update_info"
    
    // MARK: - Column Mapping
    
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case dataType = "data_type"
        case lastUpdated = "last_updated"
        case version
        case totalCount = "total_count"
        case createdAt = "created_at"
    }
    /// Type of data (art, camp, event)
    public var dataType: String
    
    /// When this data was last updated
    public var lastUpdated: Date
    
    /// Version identifier for this data
    public var version: String?
    
    /// Total count of objects of this type
    public var totalCount: Int
    
    /// When this record was created
    public var createdAt: Date
    
    public init(
        dataType: String,
        lastUpdated: Date,
        version: String? = nil,
        totalCount: Int,
        createdAt: Date = Date()
    ) {
        self.dataType = dataType
        self.lastUpdated = lastUpdated
        self.version = version
        self.totalCount = totalCount
        self.createdAt = createdAt
    }
}

// MARK: - Computed Properties

public extension UpdateInfo {
    /// Data object type enum
    var objectType: DataObjectType? {
        DataObjectType(rawValue: dataType)
    }
    
    /// Whether this update info is for art objects
    var isArt: Bool {
        dataType == DataObjectType.art.rawValue
    }
    
    /// Whether this update info is for camps
    var isCamp: Bool {
        dataType == DataObjectType.camp.rawValue
    }
    
    /// Whether this update info is for events
    var isEvent: Bool {
        dataType == DataObjectType.event.rawValue
    }
}