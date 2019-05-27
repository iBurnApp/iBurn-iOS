//
//  BRCLocations.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/15/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc class BRCLocations: NSObject {
    private static let kBRCManRegionIdentifier = "kBRCManRegionIdentifier"
    
    /** location of the man */
    @objc static let blackRockCityCenter = YearSettings.manCenterCoordinate
    
    /** Within 5 miles of the man */
    @objc static let burningManRegion: CLCircularRegion = {
        let manCoordinate: CLLocationCoordinate2D = blackRockCityCenter
        let radius = CLLocationDistance(5 * 8046.72)
        // Within 5 miles of the man
        let burningManRegion = CLCircularRegion(center: manCoordinate, radius: radius, identifier: kBRCManRegionIdentifier)
        return burningManRegion
    }()
    
    @objc static var hasEnteredBurningManRegion: Bool = false
}
