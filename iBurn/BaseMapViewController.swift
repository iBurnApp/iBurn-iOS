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
    
    let mapView = MGLMapView()
    var mapViewAdapter: MapViewAdapter
    @objc public var isVisible = false
    
    // MARK: - Init
    
    public init() {
        mapViewAdapter = MapViewAdapter(mapView: mapView)
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(mapView)
        mapView.autoPinEdgesToSuperviewEdges()
        setupTrackingButton(mapView: mapView)
        setupMapView(mapView)
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
    
    // MARK: - Public API
    
    @objc public func centerMapAtManCoordinatesAnimated(_ animated: Bool) {
        mapView.brc_moveToBlackRockCityCenter(animated: animated)
    }
}

// MARK: - Private

private extension BaseMapViewController {
    func setupMapView(_ mapView: MGLMapView) {
        mapView.brc_setDefaults()
        centerMapAtManCoordinatesAnimated(false)
    }
    
    func setupTrackingButton(mapView: MGLMapView) {
        let button = BRCUserTrackingBarButtonItem(mapView: mapView)
        navigationItem.rightBarButtonItem = button
    }
}
