//
//  MapListViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/6/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation
import MapLibre
import UIKit


public class MapListViewController: BaseMapViewController {

    private var hasZoomedToCoordinates = false

    /// Edge padding for the ordinary many-pins fit. Just enough to keep a pin off the very
    /// edge of the map — the pins themselves describe the area worth looking at.
    private static let multiPinPadding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

    /// Edge padding for the two-point fit, which frames a single destination against a second
    /// point that can be a long way off. Generous where the chrome is: the navigation bar
    /// overlaps the top of the map (`edgesForExtendedLayout` is `.all`), and the sides and
    /// bottom carry the map's own controls. Matches the spirit of `brc_showDestination`'s
    /// callers, whose 45pt box assumes a map that isn't under a navigation bar.
    private static let destinationPadding = UIEdgeInsets(top: 120, left: 60, bottom: 45, right: 60)

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupListButton()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasZoomedToCoordinates else { return }
        hasZoomedToCoordinates = true

        // The user location annotation is the map's own, not one of ours; it must not count
        // towards "how many pins am I showing" (nor be framed twice on the two-point path).
        let coordinates = (mapView.annotations ?? [])
            .filter { !($0 is MLNUserLocation) }
            .map { $0.coordinate }
            .filter { CLLocationCoordinate2DIsValid($0) }
        guard !coordinates.isEmpty else { return }

        // One pin — this map was pushed from a detail screen — so fitting the annotations
        // alone would zoom all the way in on a single dot with nothing around it to place it.
        // Frame it against the user (on playa) or the Man (off playa) instead, exactly as the
        // detail screen's own small map does. Several pins already describe their own area.
        let isSingleDestination = coordinates.count == 1
        let framed = isSingleDestination
            ? coordinates + [BRCLocations.mapFramingCoordinate(forUserLocation: mapView.userLocation?.location)]
            : coordinates

        mapView.setVisibleCoordinates(
            framed,
            count: UInt(framed.count),
            edgePadding: isSingleDestination ? Self.destinationPadding : Self.multiPinPadding,
            animated: animated
        )
    }
}

// MARK: - ListButtonHelper

extension MapListViewController: ListButtonHelper {
    // Using default implementation from protocol extension
}
