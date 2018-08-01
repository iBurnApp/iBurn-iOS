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
    let tapGesture = UITapGestureRecognizer()
    
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
        // TODO: make sidebar buttons work
        setupSidebarButtons()
        setupSearchButton()
        search.tableViewAdapter.delegate = self
        definesPresentationContext = true
        setupTapGesture()
    }
    
    private func setupSidebarButtons() {
        view.addSubview(sidebarButtons)
        let bottom = sidebarButtons.autoPinEdge(toSuperviewMargin: .bottom)
        bottom.constant = -50
        sidebarButtons.autoPinEdge(toSuperviewMargin: .left)
        sidebarButtons.autoSetDimensions(to: CGSize(width: 40, height: 150))
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadUserAnnotations()
        geocodeNavigationBar()
    }
}

private extension MapViewController {
    
    func setupTapGesture() {
        tapGesture.addTarget(self, action: #selector(singleTap(_:)))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - User Interaction
    
    @objc func singleTap(_ gesture: UITapGestureRecognizer) {
        guard let nav = self.navigationController else { return }
        let shouldHide = !nav.isNavigationBarHidden
        let newAlpha: CGFloat = shouldHide ? 0.0 : 1.0
        nav.setNavigationBarHidden(shouldHide, animated: true)
        if !shouldHide {
            self.tabBarController?.tabBar.isHidden = false
            self.sidebarButtons.isHidden = false
        }
        UIView.animate(withDuration: 0.5, animations: {
            self.sidebarButtons.alpha = newAlpha
            self.tabBarController?.tabBar.alpha = newAlpha
        }) { (finished) in
            if shouldHide {
                self.tabBarController?.tabBar.isHidden = true
                self.sidebarButtons.isHidden = true
            }
        }

    }
    
    // MARK: - Annotations
    
    func setupUserGuide() {
        sidebarButtons.findNearestAction = { [weak self] mapPointType, sender in
            guard let location = self?.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            self?.readConnection.read { transaction in
                if let point = UserGuidance.findNearest(userLocation: location, mapPointType: mapPointType, transaction: transaction) {
                    DDLogInfo("Found closest point: \(point)")
                } else if mapPointType == .userBike || mapPointType == .userHome {
                    // If we can't find your bike or home, let's make a new one
                    self?.addUserMapPoint(type: mapPointType)
                }
            }
        }
        sidebarButtons.placePinAction = { [weak self] sender in
            self?.addUserMapPoint(type: .userStar)
        }
        mapViewDelegate.saveMapPoint = { [weak self] mapPoint in
            self?.writeConnection.readWrite { transaction in
                mapPoint.save(with: transaction, metadata: nil)
            }
            self?.mapViewDelegate.editingAnnotation = nil
            self?.mapView.removeAnnotation(mapPoint)
            DDLogInfo("Saved user annotation: \(mapPoint)")
            self?.reloadUserAnnotations()
        }
        sidebarButtons.searchAction = { [weak self] sender in
            self?.searchButtonPressed(sender)
        }
    }
    
    func reloadUserAnnotations() {
        mapView.removeAnnotations(userAnnotations)
        userAnnotations = []
        readConnection.asyncRead({ transaction in
            transaction.enumerateKeysAndObjects(inCollection: BRCUserMapPoint.yapCollection, using: { (key, object, stop) in
                if let mapPoint = object as? BRCUserMapPoint {
                    self.userAnnotations.append(mapPoint)
                }
            })
        }, completionBlock: {
            self.mapView.addAnnotations(self.userAnnotations)
        })
    }
    
    func addUserMapPoint(type: BRCMapPointType) {
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

extension MapViewController: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let detail = BRCDetailViewController(dataObject: object.object)
        self.navigationController?.pushViewController(detail, animated: false)
        search.searchController.isActive = false
    }
}

extension MapViewController: SearchCooordinator {
    var searchController: UISearchController {
        return search.searchController
    }
}
