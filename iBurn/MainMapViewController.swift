//
//  MainMapViewController.swift
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
import PlayaGeocoder

public class MainMapViewController: BaseMapViewController {
    let uiConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    /// This contains the buttons for finding the nearest POIs e.g. bathrooms
    let sidebarButtons: SidebarButtonsView
    let geocoder = PlayaGeocoder.shared
    let search: SearchDisplayManager
    private var observer: NSObjectProtocol?
    var userMapViewAdapter: UserMapViewAdapter? {
        return mapViewAdapter as? UserMapViewAdapter
    }
    private var geocoderTimer: Timer? {
        didSet {
            oldValue?.invalidate()
            geocoderTimer?.tolerance = 1
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        geocoderTimer?.invalidate()
    }
    
    public init() {
        uiConnection = BRCDatabaseManager.shared.uiConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        sidebarButtons = SidebarButtonsView()
        search = SearchDisplayManager(viewName: BRCDatabaseManager.shared.searchEverythingView)
        search.tableViewAdapter.groupTransformer = GroupTransformers.searchGroup
        let userSource = YapCollectionAnnotationDataSource(collection: BRCUserMapPoint.yapCollection)
        userSource.allowedClass = BRCUserMapPoint.self
        let mapView = MLNMapView.brcMapView()
        let favoritesSource = YapViewAnnotationDataSource(viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.everythingFilteredByFavorite))
        let dataSource = AggregateAnnotationDataSource(dataSources: [userSource, favoritesSource])
        let mapViewAdapter = UserMapViewAdapter(mapView: mapView, dataSource: dataSource)
        super.init(mapViewAdapter: mapViewAdapter)
        title = NSLocalizedString("Map", comment: "title for map view")
        setupUserGuide()
        
        self.observer = NotificationCenter.default.addObserver(forName: .BRCDatabaseExtensionRegistered,
                                                               object: BRCDatabaseManager.shared,
                                                               queue: .main,
                                                               using: { [weak self] (notification) in
                                                                self?.extensionRegisteredNotification(notification: notification)
        })
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
        mapViewAdapter.reloadAnnotations()
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.geocodeNavigationBar()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.tabBarController?.tabBar.isHidden = false
        self.tabBarController?.tabBar.alpha = 1.0
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.sidebarButtons.isHidden = false
        geocoderTimer = nil
    }
}

private extension MainMapViewController {
    
    func extensionRegisteredNotification(notification: Notification) {
        guard let extensionName = notification.userInfo?["extensionName"] as? String,
            extensionName == BRCDatabaseManager.shared.everythingFilteredByFavorite else { return }
        self.mapViewAdapter.reloadAnnotations()
    }
    
    // MARK: - Annotations
    
    func setupUserGuide() {
        sidebarButtons.findNearestAction = { [weak self] mapPointType, sender in
            guard let location = self?.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            self?.uiConnection.read { transaction in
                if let point = UserGuidance.findNearest(userLocation: location, mapPointType: mapPointType, transaction: transaction) {
                    DDLogInfo("Found closest point: \(point)")
                    self?.mapView.selectAnnotation(point, animated: true, completionHandler: nil)
                } else if mapPointType == .userBike || mapPointType == .userHome {
                    // If we can't find your bike or home, let's make a new one
                    self?.addUserMapPoint(type: mapPointType)
                }
            }
        }
        sidebarButtons.placePinAction = { [weak self] sender in
            self?.addUserMapPoint(type: .userStar)
        }
        sidebarButtons.searchAction = { [weak self] sender in
            self?.searchButtonPressed(sender)
        }
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
        let mapPoint = BRCUserMapPoint(title: nil, coordinate: coordinate, type: type)
        userMapViewAdapter?.editMapPoint(mapPoint)
    }
}

extension MainMapViewController: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let nav = presentingViewController?.navigationController ??
            navigationController
        let detail = BRCDetailViewController(dataObject: object.object)
        nav?.pushViewController(detail, animated: true)
    }
}

extension MainMapViewController: SearchCooordinator {
    var searchController: UISearchController {
        return search.searchController
    }
}
