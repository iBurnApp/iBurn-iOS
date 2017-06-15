//
//  MapViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase
import CoreLocation
import BButton
import CocoaLumberjack

class UserGuide {
    
    struct DistanceEntry {
        let point: BRCMapPoint
        let distance: CLLocationDistance
    }
    
    static func findNearest(userLocation: CLLocation,
                            mapPointType: BRCMapPointType,
                            transaction: YapDatabaseReadTransaction) -> BRCMapPoint? {
        let yapCollection = BRCMapPoint.yapCollection(for: mapPointType)
        var distances: [DistanceEntry] = []
        transaction.enumerateKeysAndObjects(inCollection: yapCollection) { (key, object, stop) in
            guard let point = object as? BRCMapPoint,
                point.type == mapPointType,
                let location = point.location() else { return }
            let distance = userLocation.distance(from: location)
            let entry = DistanceEntry(point: point, distance: distance)
            distances.append(entry)
        }
        distances.sort { $0.distance > $1.distance }
        return distances.first?.point
    }
}

public class MapViewController: BaseMapViewController {
    let readConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    let sidebarButtons: SidebarButtonsView
    
    public override init() {
        readConnection = BRCDatabaseManager.shared.readConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        sidebarButtons = SidebarButtonsView()
        super.init()
        title = NSLocalizedString("Map", comment: "title for map view")
        setupUserGuide()
    }
    
    private func setupUserGuide() {
        sidebarButtons.findNearest = { [weak self] mapPointType, sender in
            guard let location = self?.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            self?.readConnection.read { transaction in
                let point = UserGuide.findNearest(userLocation: location, mapPointType: mapPointType, transaction: transaction)
                DDLogInfo("Found closest point: \(String(describing: point))")
            }
        }
        sidebarButtons.placePin = { [weak self] sender in
            guard let location = self?.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            DDLogInfo("Place user pin here \(location)")
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(sidebarButtons)
        let bottom = sidebarButtons.autoPinEdge(toSuperviewMargin: .bottom)
        bottom.constant = -50
        sidebarButtons.autoPinEdge(toSuperviewMargin: .left)
        sidebarButtons.autoSetDimensions(to: CGSize(width: 40, height: 200))
    }

}
