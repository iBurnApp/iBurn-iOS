//
//  MapLayerManager.swift
//  iBurn
//
//  Created by Assistant on 2025-08-23.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre

/// Resolved visibility state for the camp boundary/label style layers, and the matching
/// verdict for the name labels camp *pins* carry.
///
/// Pure so the embargo/settings decision is unit-testable without MapLibre.
///
/// Two independent mechanisms can put a camp's name on the map:
///
///  1. the `camp-labels-big` style layer, drawing `camp_labels.geojson` at each camp's
///     polygon centroid, and
///  2. the `LabelAnnotationView` under every camp pin, drawing the annotation's title.
///
/// Since `apply_placement.js` started writing each camp's GPS from that same polygon
/// centroid, a camp pin sits on *exactly* the point its style label is drawn at, so any
/// overlap is text stacked on identical text. **The style layer wins that contest**: it
/// runs over its full zoom range, uncapped, and `campNamesDrawnByStyleLayer` tells the pins
/// when it is painting so they can stay bare glyphs. Which *camps* it paints is a per-camp
/// question the geojson answers — see `CampStyleLabelIndex` and `PinLabelVisibility`.
struct CampLayerVisibility: Equatable {
    /// `camp-labels-big`'s `minzoom` in the shipped style JSON. The layer draws nothing
    /// below this, so camp pins below it must label themselves.
    static let labelsMinimumZoom: Float = 15

    var boundariesVisible: Bool
    /// nil when the boundaries layer is hidden (minzoom is left untouched)
    var boundariesMinimumZoom: Float?
    var labelsVisible: Bool
    /// True when the style layer is painting camp names at the resolved zoom, so any camp
    /// pin whose camp it has a label for must keep its own label hidden.
    var campNamesDrawnByStyleLayer: Bool

    /// - Parameters:
    ///   - showCampBoundaries: `UserSettings.showCampBoundaries`.
    ///   - showCampBoundariesAlways: `UserSettings.showCampBoundariesAlways`.
    ///   - showBigCampNames: `UserSettings.showBigCampNames`.
    ///   - embargoAllowsCamps: `BRCEmbargo.canShowCampLocations()`. The camp geojson ships
    ///     in the app bundle, so until the camp tier clears both layers stay hidden
    ///     regardless of settings.
    ///   - zoomLevel: the map's current zoom, for `campNamesDrawnByStyleLayer`.
    static func resolve(showCampBoundaries: Bool,
                        showCampBoundariesAlways: Bool,
                        showBigCampNames: Bool,
                        embargoAllowsCamps: Bool,
                        zoomLevel: Double) -> CampLayerVisibility {
        let boundariesVisible = showCampBoundaries && embargoAllowsCamps
        let labelsVisible = showBigCampNames && embargoAllowsCamps
        return CampLayerVisibility(
            boundariesVisible: boundariesVisible,
            boundariesMinimumZoom: boundariesVisible ? (showCampBoundariesAlways ? 0 : 15) : nil,
            labelsVisible: labelsVisible,
            campNamesDrawnByStyleLayer: labelsVisible && zoomLevel >= Double(labelsMinimumZoom)
        )
    }

    /// Resolves against the live settings and embargo state.
    ///
    /// Both consumers — `MapLayerManager` for the style layers and `MapViewAdapter` for the
    /// pin labels — go through here, so they can't disagree about which side is drawing.
    static func current(zoomLevel: Double) -> CampLayerVisibility {
        resolve(showCampBoundaries: UserSettings.showCampBoundaries,
                showCampBoundariesAlways: UserSettings.showCampBoundariesAlways,
                showBigCampNames: UserSettings.showBigCampNames,
                embargoAllowsCamps: BRCEmbargo.canShowCampLocations(),
                zoomLevel: zoomLevel)
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
        guard let mapView, let style = mapView.style else { return }

        let visibility = CampLayerVisibility.current(zoomLevel: mapView.zoomLevel)

        if let boundariesLayer = style.layer(withIdentifier: "camp-boundaries") {
            boundariesLayer.isVisible = visibility.boundariesVisible
            if let minimumZoom = visibility.boundariesMinimumZoom {
                boundariesLayer.minimumZoomLevel = minimumZoom
            }
        }

        // Visibility only: the layer's zoom range is the style JSON's own and is never
        // narrowed at runtime. Capping it used to be how camp pins took over the naming
        // above z17, and it needed a `reloadStyle` to undo — MapLibre will not re-parse
        // tiles it built while a layer was out of range. Camp pins now yield to this layer
        // instead of the other way round, so the cap and that workaround are both gone.
        if let labelsLayer = style.layer(withIdentifier: "camp-labels-big") {
            labelsLayer.isVisible = visibility.labelsVisible
        }
    }

    /// Updates all managed layers
    func updateAllLayers() {
        updateCampLayerVisibility()
    }
}
