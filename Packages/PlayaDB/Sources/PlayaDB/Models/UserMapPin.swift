import Foundation
import GRDB

/// A user-placed map pin (home, bike, star).
public struct UserMapPin: Codable, FetchableRecord, MutablePersistableRecord, Identifiable {
    public static let databaseTableName = "user_map_pins"

    public enum Columns: String, CodingKey, ColumnExpression {
        case id
        case title
        case latitude
        case longitude
        case pinType = "pin_type"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case latitude
        case longitude
        case pinType = "pin_type"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
    }

    public var id: String
    public var title: String?
    public var latitude: Double
    public var longitude: Double
    public var pinType: String
    public var createdDate: Date
    public var modifiedDate: Date

    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        latitude: Double,
        longitude: Double,
        pinType: String,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.pinType = pinType
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
}
