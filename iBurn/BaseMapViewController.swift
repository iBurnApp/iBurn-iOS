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
    
    var mapView: MGLMapView {
        return mapViewAdapter.mapView
    }
    var mapViewAdapter: MapViewAdapter
    @objc public var isVisible = false
    
    // MARK: - Init
    
    /// Use custom MapViewAdapter
    public init(mapViewAdapter: MapViewAdapter) {
        self.mapViewAdapter = mapViewAdapter
        super.init(nibName: nil, bundle: nil)
        self.mapViewAdapter.parent = self
    }
    
    /// Using default MapViewAdapter
    public init(dataSource: AnnotationDataSource? = nil) {
        let mapView = MGLMapView()
        self.mapViewAdapter = MapViewAdapter(mapView: mapView, dataSource: dataSource)
        super.init(nibName: nil, bundle: nil)
        self.mapViewAdapter.parent = self
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let mapView = MGLMapView()
        self.mapViewAdapter = MapViewAdapter(mapView: mapView, dataSource: nil)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.mapViewAdapter.parent = self
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
        mapViewAdapter.reloadAnnotations()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
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
