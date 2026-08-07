//
//  MapLayerManager.swift
//  iBurn
//
//  Created by Assistant on 2025-08-23.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre

/// Resolved visibility state for the camp boundary/label style layers.
/// Pure so the embargo/settings decision is unit-testable without MapLibre.
struct CampLayerVisibility: Equatable {
    var boundariesVisible: Bool
    /// nil when the boundaries layer is hidden (minzoom is left untouched)
    var boundariesMinimumZoom: Float?
    var labelsVisible: Bool

    /// The camp boundary geojson ships in the app bundle, so until the camp
    /// embargo tier clears the layers must stay hidden regardless of settings.
    static func resolve(showCampBoundaries: Bool,
                        showCampBoundariesAlways: Bool,
                        showBigCampNames: Bool,
                        embargoAllowsCamps: Bool) -> CampLayerVisibility {
        let boundariesVisible = showCampBoundaries && embargoAllowsCamps
        return CampLayerVisibility(
            boundariesVisible: boundariesVisible,
            boundariesMinimumZoom: boundariesVisible ? (showCampBoundariesAlways ? 0 : 15) : nil,
            labelsVisible: showBigCampNames && embargoAllowsCamps
        )
    }
}

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

    /// Updates the visibility of camp-related layers based on user settings and embargo state
    func updateCampLayerVisibility() {
        guard let style = mapView?.style else { return }

        let visibility = CampLayerVisibility.resolve(
            showCampBoundaries: UserSettings.showCampBoundaries,
            showCampBoundariesAlways: UserSettings.showCampBoundariesAlways,
            showBigCampNames: UserSettings.showBigCampNames,
            embargoAllowsCamps: BRCEmbargo.canShowCampLocations()
        )

        if let boundariesLayer = style.layer(withIdentifier: "camp-boundaries") {
            boundariesLayer.isVisible = visibility.boundariesVisible
            if let minimumZoom = visibility.boundariesMinimumZoom {
                boundariesLayer.minimumZoomLevel = minimumZoom
            }
        }

        if let labelsLayer = style.layer(withIdentifier: "camp-labels-big") {
            labelsLayer.isVisible = visibility.labelsVisible
        }
    }

    /// Updates all managed layers
    func updateAllLayers() {
        updateCampLayerVisibility()
    }
}
