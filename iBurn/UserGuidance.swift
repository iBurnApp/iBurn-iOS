//
//  UserGuidance.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/16/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

class UserGuidance {

    static func findNearest(
        userLocation: CLLocation,
        mapPointType: BRCMapPointType,
        playaDB: PlayaDB
    ) async -> BRCUserMapPoint? {
        guard let pins = try? await playaDB.fetchUserMapPins() else { return nil }
        let targetType = mapPointType.pinTypeString

        return pins
            .filter { $0.pinType == targetType }
            .compactMap { pin -> (BRCUserMapPoint, CLLocationDistance)? in
                let loc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
                let distance = userLocation.distance(from: loc)
                return (BRCUserMapPoint(userMapPin: pin), distance)
            }
            .min(by: { $0.1 < $1.1 })?
            .0
    }
}
