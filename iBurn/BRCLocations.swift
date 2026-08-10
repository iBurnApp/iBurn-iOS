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

    /// The second point a map frames alongside a destination, so a single pin never zooms in
    /// to a featureless patch of playa.
    ///
    /// On playa that second point is the user: "you and the thing you're looking at" is the
    /// picture that answers *which way do I walk*. Off playa it is the Man, because a frame
    /// stretched from the couch you're planning on to Black Rock City would render the
    /// destination as an invisible speck — where the Man puts it in the context of the city
    /// it sits in. The 5-mile `burningManRegion` is the line between the two.
    ///
    /// Shared by `MLNMapView.brc_showDestination` (detail maps) and `MapListViewController`
    /// (the map pushed from a detail screen or a list) so both frame a lone pin identically.
    ///
    /// - Parameter location: The device's last known location, or nil if there isn't one.
    @objc static func mapFramingCoordinate(forUserLocation location: CLLocation?) -> CLLocationCoordinate2D {
        guard let coordinate = location?.coordinate,
              CLLocationCoordinate2DIsValid(coordinate),
              burningManRegion.contains(coordinate) else {
            return blackRockCityCenter
        }
        return coordinate
    }
}
