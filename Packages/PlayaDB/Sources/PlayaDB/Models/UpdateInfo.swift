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
        case fileName = "file_name"
        case fetchStatus = "fetch_status"
        case lastCheckedDate = "last_checked_date"
        case fetchDate = "fetch_date"
        case ingestionDate = "ingestion_date"
    }

    /// Type of data (art, camp, event, mutantVehicle)
    public var dataType: String

    /// When this data was last updated on the server
    public var lastUpdated: Date

    /// Version identifier for this data
    public var version: String?

    /// Total count of objects of this type
    public var totalCount: Int

    /// When this record was created
    public var createdAt: Date

    /// Source URL or bundle path
    public var fileName: String?

    /// Fetch status: "unknown", "fetching", "failed", "complete"
    public var fetchStatus: String

    /// When update.json was last checked
    public var lastCheckedDate: Date?

    /// When data was fetched from server
    public var fetchDate: Date?

    /// When data was successfully loaded into app
    public var ingestionDate: Date?

    public init(
        dataType: String,
        lastUpdated: Date,
        version: String? = nil,
        totalCount: Int,
        createdAt: Date = Date(),
        fileName: String? = nil,
        fetchStatus: String = "unknown",
        lastCheckedDate: Date? = nil,
        fetchDate: Date? = nil,
        ingestionDate: Date? = nil
    ) {
        self.dataType = dataType
        self.lastUpdated = lastUpdated
        self.version = version
        self.totalCount = totalCount
        self.createdAt = createdAt
        self.fileName = fileName
        self.fetchStatus = fetchStatus
        self.lastCheckedDate = lastCheckedDate
        self.fetchDate = fetchDate
        self.ingestionDate = ingestionDate
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
