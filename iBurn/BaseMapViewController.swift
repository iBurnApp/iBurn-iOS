//
//  BaseMapViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import Mapbox
import PureLayout
import CocoaLumberjack

public class BaseMapViewController: UIViewController {
    
    var mapView: MGLMapView
    let mapViewDelegate: MapViewDelegate
    @objc public var isVisible = false
    
    public init() {
        mapView = MGLMapView()
        mapViewDelegate = MapViewDelegate()
        super.init(nibName: nil, bundle: nil)
        setupMapView(mapView)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(mapTilesUpdated), name: NSNotification.Name.BRCDataImporterMapTilesUpdated, object: nil)
        view.addSubview(mapView)
        view.sendSubview(toBack: mapView)
        mapView.autoPinEdgesToSuperviewEdges()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        // There is maybe a bug in Mapbox?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.centerMapAtManCoordinatesAnimated(false)
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
    }
    
    private func setupMapView(_ mapView: MGLMapView) {
        mapView.brc_setDefaults()
        mapView.delegate = mapViewDelegate
        centerMapAtManCoordinatesAnimated(false)
        setupTrackingButton(mapView: mapView)
    }
    
    private func setupTrackingButton(mapView: MGLMapView) {
        let button = BRCUserTrackingBarButtonItem(mapView: mapView)
        navigationItem.rightBarButtonItem = button
    }
    
    @objc public func centerMapAtManCoordinatesAnimated(_ animated: Bool) {
        mapView.brc_moveToBlackRockCityCenter(animated: animated)
    }
    
    @objc private func mapTilesUpdated(notification: Notification) {
        DDLogInfo("Replacing map tiles via notification...")
        mapView.removeFromSuperview()
        mapView = MGLMapView()
        setupMapView(mapView)
    }
}
