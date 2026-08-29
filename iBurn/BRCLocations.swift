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

    /// Where a bike / home / star pin lands when the user drops one.
    ///
    /// On playa the answer is the user: "my bike is where I'm standing" is the whole point
    /// of the button. Off playa their GPS fix is a street address a few hundred miles away,
    /// and dropping the pin there put it somewhere they could neither see nor drag —
    /// planning from the couch silently produced a pin in the couch. So the off-playa
    /// fallback is the map they're actually looking at: the pin appears mid-screen, ready
    /// to be dragged onto the block they mean. Unconditional, because whatever is centered
    /// in the viewport is by definition on screen.
    ///
    /// Same 5-mile `burningManRegion` line as `mapFramingCoordinate(forUserLocation:)`.
    ///
    /// The viewport fallback is itself validated: `MLNMapView.centerCoordinate` projects the
    /// center of the map's bounds, and a map whose bounds are still degenerate (zero-sized,
    /// mid-transition, laid out but not yet sized) hands back NaN. A NaN pin coordinate
    /// reaches `CALayer.position` and crashes with `CALayerInvalidGeometry`, so when the
    /// viewport can't answer we fall back to the Man.
    ///
    /// - Parameters:
    ///   - location: The device's last known location, or nil if there isn't one.
    ///   - viewportCenter: The center of the map the user is looking at.
    @objc static func userMapPointCoordinate(
        forUserLocation location: CLLocation?,
        viewportCenter: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        guard let coordinate = location?.coordinate,
              CLLocationCoordinate2DIsValid(coordinate),
              burningManRegion.contains(coordinate) else {
            return isUsable(viewportCenter) ? viewportCenter : blackRockCityCenter
        }
        return coordinate
    }

    /// Whether a coordinate is safe to hand to MapLibre.
    ///
    /// `CLLocationCoordinate2DIsValid` already rejects NaN (every comparison against NaN is
    /// false, so the range check fails) but not obviously, and it says nothing about
    /// infinity beyond the range test. The explicit `isFinite` pair makes both intentional.
    @objc static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && CLLocationCoordinate2DIsValid(coordinate)
    }
}
