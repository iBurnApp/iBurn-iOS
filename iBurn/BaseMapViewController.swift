//
//  BaseMapViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre
import PureLayout
import CocoaLumberjack

public class BaseMapViewController: UIViewController {
    
    var mapView: MLNMapView {
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
        let mapView = MLNMapView.brcMapView()
        self.mapViewAdapter = MapViewAdapter(mapView: mapView, dataSource: dataSource)
        super.init(nibName: nil, bundle: nil)
        self.mapViewAdapter.parent = self
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        let mapView = MLNMapView.brcMapView()
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
        view.tintColor = Appearance.currentColors.primaryColor
        mapView.autoPinEdgesToSuperviewEdges()
        setupTrackingButton(mapView: mapView)
        setupMapView(mapView)
        mapViewAdapter.reloadAnnotations()
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateDidChange(notification:)), name: .NSProcessInfoPowerStateDidChange, object: nil)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshNavigationBarColors(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        updateIdleTimer()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        updateIdleTimer()
    }
    
    // MARK: - Public API
    
    @objc public func centerMapAtManCoordinatesAnimated(_ animated: Bool) {
        mapView.brc_moveToBlackRockCityCenter(animated: animated)
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        navigationItem.rightBarButtonItem?.tintColor = view.tintColor
    }
}

// MARK: - Private

private extension BaseMapViewController {
    @objc func powerStateDidChange(notification: Notification) {
        DispatchQueue.main.async {
            self.updateIdleTimer()
        }
    }
    
    /// keeps the screen on for folks navigating in vehicles
    func updateIdleTimer() {
        if !UserDefaults.isNavigationModeDisabled,
           !ProcessInfo.processInfo.isLowPowerModeEnabled,
           isVisible {
            UIApplication.shared.isIdleTimerDisabled = true
            print("Navigation mode enabled, map screen will stay on.")
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
            print("Navigation mode disabled, map screen will dim as usual.")
        }
    }
    
    func setupMapView(_ mapView: MLNMapView) {
        mapView.brc_setDefaults()
        centerMapAtManCoordinatesAnimated(false)
    }
    
    func setupTrackingButton(mapView: MLNMapView) {
        let button = BRCUserTrackingBarButtonItem(mapView: mapView)
        button.tintColor = view.tintColor
        navigationItem.rightBarButtonItem = button
    }
}
