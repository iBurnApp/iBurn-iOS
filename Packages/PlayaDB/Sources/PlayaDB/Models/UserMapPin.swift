import Foundation
import GRDB

/// A user-placed map pin (home, bike, star).
///
/// Rows are soft-deleted: `isDeleted` marks a tombstone so deletions can
/// propagate through last-writer-wins sync between devices. Every normal read
/// path filters tombstones out; only the sync snapshot carries them.
public struct UserMapPin: Codable, Equatable, Sendable, FetchableRecord, MutablePersistableRecord, Identifiable {
    public static let databaseTableName = "user_map_pins"

    public enum Columns: String, CodingKey, ColumnExpression {
        case id
        case title
        case latitude
        case longitude
        case pinType = "pin_type"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
        case isDeleted = "is_deleted"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case latitude
        case longitude
        case pinType = "pin_type"
        case createdDate = "created_date"
        case modifiedDate = "modified_date"
        case isDeleted = "is_deleted"
    }

    public var id: String
    public var title: String?
    public var latitude: Double
    public var longitude: Double
    public var pinType: String
    public var createdDate: Date
    public var modifiedDate: Date
    /// Tombstone marker. `true` means the pin was deleted at `modifiedDate`.
    public var isDeleted: Bool

    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        latitude: Double,
        longitude: Double,
        pinType: String,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.pinType = pinType
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.isDeleted = isDeleted
    }

    /// Custom decoding so `is_deleted` is optional: a sync payload from a peer
    /// running a build that predates tombstones still decodes (as a live pin)
    /// instead of failing the whole array.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        pinType = try container.decode(String.self, forKey: .pinType)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}

/// The pin types the apps can store, as they appear in `user_map_pins.pin_type`.
///
/// Raw values match the strings the iOS app's `BRCMapPointType.pinTypeString`
/// already writes, so this is a shared vocabulary rather than a new one.
public enum UserMapPinType: String, CaseIterable, Sendable {
    case userBike
    case userHome
    case userStar
    case userCamp
    case userHeart
    case userBreadcrumb
    case toilet
    case medical
    case ranger

    /// Types a user can create by hand. The rest are either legacy, imported
    /// amenities, or written by breadcrumb tracking.
    public static let userCreatable: [UserMapPinType] = [.userBike, .userHome, .userStar]

    public init(pinTypeString: String) {
        self = UserMapPinType(rawValue: pinTypeString) ?? .userStar
    }

    public var displayName: String {
        switch self {
        case .userBike: return "Bike"
        case .userHome: return "Home"
        case .userStar: return "Pin"
        case .userCamp: return "Camp"
        case .userHeart: return "Favorite"
        case .userBreadcrumb: return "Breadcrumb"
        case .toilet: return "Toilet"
        case .medical: return "Medical"
        case .ranger: return "Ranger"
        }
    }

    /// SF Symbol name for the type.
    public var symbolName: String {
        switch self {
        case .userBike: return "bicycle"
        case .userHome: return "house.fill"
        case .userStar: return "star.fill"
        case .userCamp: return "tent.fill"
        case .userHeart: return "heart.fill"
        case .userBreadcrumb: return "point.topleft.down.curvedto.point.bottomright.up"
        case .toilet: return "toilet.fill"
        case .medical: return "cross.case.fill"
        case .ranger: return "shield.fill"
        }
    }
}
