//
//  MapListViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/6/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre
import UIKit


public class MapListViewController: BaseMapViewController {
    
    private var hasZoomedToCoordinates = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupListButton()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasZoomedToCoordinates {
            let coordinates = mapView.annotations?.map { $0.coordinate } ?? []
            mapView.setVisibleCoordinates(coordinates, count: UInt(coordinates.count), edgePadding: UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10), animated: animated)
            hasZoomedToCoordinates = true
        }
    }
}

// MARK: - ListButtonHelper

extension MapListViewController: ListButtonHelper {
    @objc func listButtonPressed(_ sender: Any?) {
        let visibleAnnotations = mapView.annotations ?? []
        let visibleBounds = mapView.visibleCoordinateBounds
        let listVC = MapPinListViewController(visibleAnnotations: visibleAnnotations, visibleBounds: visibleBounds)
        navigationController?.pushViewController(listVC, animated: true)
    }
}
