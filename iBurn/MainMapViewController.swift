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
import SafariServices
import EventKitUI
import SwiftUI
import PlayaDB

public class MainMapViewController: BaseMapViewController, ListButtonHelper {
    let uiConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    /// This contains the buttons for finding the nearest POIs e.g. bathrooms
    let sidebarButtons: SidebarButtonsView
    let geocoder = PlayaGeocoder.shared
    private let globalSearchController: UISearchController
    private let globalSearchHostingController: GlobalSearchHostingController
    private let filteredDataSource: FilteredMapDataSource
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
        geocoderTimer?.invalidate()
    }

    public init() {
        let dependencies = BRCAppDelegate.shared.dependencies
        uiConnection = BRCDatabaseManager.shared.uiConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        sidebarButtons = SidebarButtonsView()

        // Set up PlayaDB-backed global search
        let searchHosting = dependencies.makeGlobalSearchHostingController()
        globalSearchHostingController = searchHosting
        globalSearchController = UISearchController(searchResultsController: searchHosting)
        globalSearchController.searchBar.barStyle = Appearance.currentBarStyle
        globalSearchController.obscuresBackgroundDuringPresentation = true
        globalSearchController.hidesNavigationBarDuringPresentation = false

        // PlayaDB-backed map annotations (replaces YapDB data sources)
        let dataSource = FilteredMapDataSource(playaDB: dependencies.playaDB)
        filteredDataSource = dataSource

        let mapView = MLNMapView.brcMapView()
        let mapViewAdapter = UserMapViewAdapter(mapView: mapView, dataSource: dataSource)
        super.init(mapViewAdapter: mapViewAdapter)

        // Reactive annotation updates from PlayaDB observations
        dataSource.onAnnotationsChanged = { [weak self] in
            self?.mapViewAdapter.reloadAnnotations()
        }

        // Route PlayaDB annotation info-button taps to detail views
        mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            guard let self else { return }
            let playaDB = dependencies.playaDB
            Task { @MainActor in
                let uid = anyID.uid
                var detailVC: UIViewController?
                switch anyID.objectType {
                case .art:
                    if let art = try? await playaDB.fetchArt(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
                    }
                case .camp:
                    if let camp = try? await playaDB.fetchCamp(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
                    }
                case .event:
                    if let event = try? await playaDB.fetchEvent(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
                    }
                case .mutantVehicle:
                    if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
                        detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
                    }
                }
                if let detailVC {
                    self.navigationController?.pushViewController(detailVC, animated: true)
                }
            }
        }

        globalSearchController.searchResultsUpdater = self
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
        setupListButton()
        setupFilterButton()
        definesPresentationContext = true
        
    }
    
    private func setupSidebarButtons() {
        view.addSubview(sidebarButtons)
        let bottom = sidebarButtons.autoPinEdge(toSuperviewMargin: .bottom)
        bottom.constant = -50
        sidebarButtons.autoPinEdge(toSuperviewMargin: .left)
        sidebarButtons.autoSetDimensions(to: CGSize(width: 40, height: 150))
    }
    
    func setupListButton() {
        let listImage = UIImage(systemName: "list.bullet")
        let listButton = UIBarButtonItem(image: listImage, style: .plain) { [weak self] button in
            self?.listButtonPressed(button)
        }
        navigationItem.leftBarButtonItem = listButton
    }
    
    func setupFilterButton() {
        let filterImage = UIImage(systemName: "line.horizontal.3.decrease.circle")
        let filterButton = UIBarButtonItem(image: filterImage, style: .plain) { [weak self] button in
            self?.filterButtonPressed(button)
        }
        navigationItem.leftBarButtonItems = [navigationItem.leftBarButtonItem, filterButton].compactMap { $0 }
    }
    
    @objc func filterButtonPressed(_ sender: Any?) {
        let filterVC = MapFilterViewController { [weak self] in
            guard let self else { return }
            // Update PlayaDB observations with new filter settings
            self.filteredDataSource.updateFilters()
            // Update map layers based on new filter settings
            self.mapLayerManager.updateAllLayers()
        }
        let nav = UINavigationController(rootViewController: filterVC)
        present(nav, animated: true)
    }
    
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navBar = navigationController?.navigationBar {
            Appearance.applyTransparentNavigationBarAppearance(navBar, colors: Appearance.currentColors, animated: animated)
        }
        if let tabBar = tabBarController?.tabBar {
            Appearance.applyTransparentTabBarAppearance(tabBar, colors: Appearance.currentColors)
        }
        mapViewAdapter.reloadAnnotations()
        geocodeNavigationBar()
        geocoderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.geocodeNavigationBar()
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let navBar = navigationController?.navigationBar {
            Appearance.applyNavigationBarAppearance(navBar, colors: Appearance.currentColors, animated: animated)
        }
        if let tabBar = tabBarController?.tabBar {
            Appearance.applyTabBarAppearance(tabBar, colors: Appearance.currentColors)
        }
        self.tabBarController?.tabBar.isHidden = false
        self.tabBarController?.tabBar.alpha = 1.0
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.sidebarButtons.isHidden = false
        geocoderTimer = nil
    }
}

private extension MainMapViewController {

    // MARK: - Annotations

    func setupUserGuide() {
        sidebarButtons.findNearestAction = { [weak self] mapPointType, sender in
            guard let self, let location = self.mapView.userLocation?.location else {
                DDLogWarn("User location not found!")
                return
            }
            let playaDB = BRCAppDelegate.shared.dependencies.playaDB
            Task { @MainActor in
                if let point = await UserGuidance.findNearest(userLocation: location, mapPointType: mapPointType, playaDB: playaDB) {
                    DDLogInfo("Found closest point: \(point)")
                    self.mapView.selectAnnotation(point, animated: true, completionHandler: nil)
                } else if mapPointType == .userBike || mapPointType == .userHome {
                    self.addUserMapPoint(type: mapPointType)
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

extension MainMapViewController: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        globalSearchHostingController.viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension MainMapViewController: SearchCooordinator {
    var searchController: UISearchController {
        return globalSearchController
    }
}
