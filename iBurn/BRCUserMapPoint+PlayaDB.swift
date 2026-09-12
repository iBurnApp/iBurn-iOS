import Foundation
import PlayaDB
import CoreLocation

extension BRCUserMapPoint {
    /// The PlayaDB pin ID. `BRCMapPoint.uniqueID` is a fresh UUID until the pin is saved.
    var pinId: String {
        get { uniqueID }
        set { uniqueID = newValue }
    }

    convenience init(userMapPin: UserMapPin) {
        let coordinate = CLLocationCoordinate2D(
            latitude: userMapPin.latitude,
            longitude: userMapPin.longitude
        )
        let type = BRCMapPointType.from(pinTypeString: userMapPin.pinType)
        self.init(title: userMapPin.title, coordinate: coordinate, type: type)
        self.modifiedDate = userMapPin.modifiedDate
        self.pinId = userMapPin.id
    }

    func toUserMapPin() -> UserMapPin {
        UserMapPin(
            id: pinId,
            title: title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            pinType: type.pinTypeString,
            createdDate: creationDate,
            modifiedDate: modifiedDate
        )
    }
}

extension BRCMapPointType {
    var pinTypeString: String {
        switch self {
        case .userHome: return "userHome"
        case .userBike: return "userBike"
        case .userStar: return "userStar"
        case .userCamp: return "userCamp"
        case .userHeart: return "userHeart"
        case .userBreadcrumb: return "userBreadcrumb"
        case .toilet: return "toilet"
        case .medical: return "medical"
        case .ranger: return "ranger"
        case .unknown: return "userStar"
        @unknown default: return "userStar"
        }
    }

    static func from(pinTypeString: String) -> BRCMapPointType {
        switch pinTypeString {
        case "userHome": return .userHome
        case "userBike": return .userBike
        case "userStar": return .userStar
        case "userCamp": return .userCamp
        case "userHeart": return .userHeart
        case "userBreadcrumb": return .userBreadcrumb
        case "toilet": return .toilet
        case "medical": return .medical
        case "ranger": return .ranger
        default: return .userStar
        }
    }
}
