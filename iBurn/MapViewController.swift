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



public class MapViewController: BaseMapViewController {
    let readConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    /// This contains the buttons for finding the nearest POIs e.g. bathrooms
    let sidebarButtons: SidebarButtonsView
    let geocoder: BRCGeocoder
    var userAnnotations: [BRCUserMapPoint] = []
    let search: SearchDisplayManager
    
    public override init() {
        readConnection = BRCDatabaseManager.shared.readConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        sidebarButtons = SidebarButtonsView()
        geocoder = BRCGeocoder.shared
        search = SearchDisplayManager(viewName: BRCDatabaseManager.shared.searchCampsView)
        super.init()
        title = NSLocalizedString("Map", comment: "title for map view")
        setupUserGuide()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(sidebarButtons)
        let bottom = sidebarButtons.autoPinEdge(toSuperviewMargin: .bottom)
        bottom.constant = -50
        sidebarButtons.autoPinEdge(toSuperviewMargin: .left)
        sidebarButtons.autoSetDimensions(to: CGSize(width: 40, height: 200))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Search", style: .plain, target: self, action: #selector(searchButtonPressed(_:)))
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadUserAnnotations()
    }
    
    // MARK: - User Interaction
    
    func searchButtonPressed(_ sender: Any) {
        present(search.searchController, animated: true, completion: nil)
    }
    
    // MARK: - Annotations
    
    private func setupUserGuide() {
        sidebarButtons.findNearest = { [weak self] mapPointType, sender in
            guard let location = self?.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            self?.readConnection.read { transaction in
                let point = UserGuidance.findNearest(userLocation: location, mapPointType: mapPointType, transaction: transaction)
                DDLogInfo("Found closest point: \(String(describing: point))")
                // If we can't find your bike or home, let's make a new one
                if point == nil,
                    mapPointType == .userBike || mapPointType == .userHome {
                   self?.addUserMapPoint(type: mapPointType)
                }
            }
        }
        sidebarButtons.placePin = { [weak self] sender in
            self?.addUserMapPoint(type: .userStar)
        }
        mapViewDelegate.saveMapPoint = { [weak self] mapPoint in
            self?.writeConnection.readWrite { transaction in
                let key = mapPoint.uuid
                let collection = type(of: mapPoint).collection
                transaction.setObject(mapPoint, forKey: key, inCollection: collection)
            }
            self?.mapViewDelegate.editingAnnotation = nil
            self?.mapView.removeAnnotation(mapPoint)
            DDLogInfo("Saved user annotation: \(mapPoint)")
            self?.reloadUserAnnotations()
        }
    }
    
    private func reloadUserAnnotations() {
        mapView.removeAnnotations(userAnnotations)
        userAnnotations = []
        readConnection.asyncRead({ transaction in
            transaction.enumerateKeysAndObjects(inCollection: BRCUserMapPoint.collection, using: { (key, object, stop) in
                if let mapPoint = object as? BRCUserMapPoint {
                    self.userAnnotations.append(mapPoint)
                }
            })
        }, completionBlock: {
            self.mapView.addAnnotations(self.userAnnotations)
        })
    }
    
    private func addUserMapPoint(type: BRCMapPointType) {
        var coordinate = BRCLocations.blackRockCityCenter
        if let userLocation = self.mapView.userLocation?.location {
            coordinate = userLocation.coordinate
        }
        // don't drop user-location pins if youre not at BM
        if !BRCLocations.burningManRegion.contains(coordinate) ||
            !CLLocationCoordinate2DIsValid(coordinate) {
            coordinate = BRCLocations.blackRockCityCenter
        }
        let mapPoint = BRCUserMapPoint(title: NSLocalizedString("Favorite", comment:"favorite marked on map"), coordinate: coordinate, type: type)
        if let existingMapPoint = mapViewDelegate.editingAnnotation {
            mapView.removeAnnotation(existingMapPoint)
        }
        mapViewDelegate.editingAnnotation = mapPoint
        mapView.addAnnotation(mapPoint)
    }
    
    

}
