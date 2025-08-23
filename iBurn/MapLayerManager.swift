//
//  MapLayerManager.swift
//  iBurn
//
//  Created by Assistant on 2025-08-23.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre

/// Manages runtime visibility of map style layers
class MapLayerManager {
    private weak var mapView: MLNMapView?
    
    private let campLayerIdentifiers = [
        "camp-boundaries",
        "camp-labels-big"
    ]
    
    init(mapView: MLNMapView) {
        self.mapView = mapView
    }
    
    /// Updates the visibility of camp-related layers based on user settings
    func updateCampLayerVisibility() {
        guard let style = mapView?.style else { return }
        
        // Camp Boundaries - handle visibility and minzoom
        if let boundariesLayer = style.layer(withIdentifier: "camp-boundaries") {
            boundariesLayer.isVisible = UserSettings.showCampBoundaries
            
            // Dynamic minzoom control
            if UserSettings.showCampBoundaries {
                if UserSettings.showCampBoundariesAlways {
                    // Remove minzoom restriction to show at all zoom levels
                    boundariesLayer.minimumZoomLevel = 0
                } else {
                    // Apply zoom 15+ restriction
                    boundariesLayer.minimumZoomLevel = 15
                }
            }
        }
        
        // Big Camp Labels
        if let labelsLayer = style.layer(withIdentifier: "camp-labels-big") {
            labelsLayer.isVisible = UserSettings.showBigCampNames
        }
    }
    
    /// Updates all managed layers
    func updateAllLayers() {
        updateCampLayerVisibility()
    }
}