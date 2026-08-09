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
/// overlap is text stacked on identical text. This type owns the split that prevents it:
/// the style layer draws camp names over a zoom range, camp pins take over above it, and
/// `campNamesDrawnByStyleLayer` reports which side is live at the zoom passed in — so the
/// two can never both draw, nor both stay silent.
struct CampLayerVisibility: Equatable {
    /// `camp-labels-big`'s `minzoom` in the shipped style JSON. The layer draws nothing
    /// below this, so camp pins below it must label themselves.
    static let labelsMinimumZoom: Float = 15

    /// MapLibre's own zoom ceiling — what an uncapped layer's `maxzoom` amounts to.
    static let styleMaximumZoom: Float = 24

    var boundariesVisible: Bool
    /// nil when the boundaries layer is hidden (minzoom is left untouched)
    var boundariesMinimumZoom: Float?
    var labelsVisible: Bool
    /// Upper bound for `camp-labels-big`, capping it at the zoom where camp pins start
    /// drawing the same names. `styleMaximumZoom` when nothing takes over.
    var labelsMaximumZoom: Float
    /// True when the style layer is actually painting camp names at the resolved zoom, so
    /// a camp pin's own label must stay hidden to avoid drawing the name a second time.
    var campNamesDrawnByStyleLayer: Bool

    /// - Parameters:
    ///   - showCampBoundaries: `UserSettings.showCampBoundaries`.
    ///   - showCampBoundariesAlways: `UserSettings.showCampBoundariesAlways`.
    ///   - showBigCampNames: `UserSettings.showBigCampNames`.
    ///   - showCampsOnlyZoomedIn: `UserSettings.showCampsOnlyZoomedIn` — the Map Filter
    ///     toggle that lets the region path drop camp pins in above
    ///     `MapRegionAnnotationFilter.campMinimumZoom`. With it off no zoom hands the
    ///     names to pins, so the style layer keeps them all the way in.
    ///   - embargoAllowsCamps: `BRCEmbargo.canShowCampLocations()`. The camp geojson ships
    ///     in the app bundle, so until the camp tier clears both layers stay hidden
    ///     regardless of settings.
    ///   - zoomLevel: the map's current zoom, for `campNamesDrawnByStyleLayer`.
    static func resolve(showCampBoundaries: Bool,
                        showCampBoundariesAlways: Bool,
                        showBigCampNames: Bool,
                        showCampsOnlyZoomedIn: Bool,
                        embargoAllowsCamps: Bool,
                        zoomLevel: Double) -> CampLayerVisibility {
        let boundariesVisible = showCampBoundaries && embargoAllowsCamps
        let labelsVisible = showBigCampNames && embargoAllowsCamps
        // Camp pins and the style layer draw the same text at the same coordinate, so the
        // layer stops exactly where the pins start. `campMinimumZoom` is a lower bound the
        // pins are eligible *at*, and `maxzoom` hides a layer *at* its value, so the two
        // ranges abut with neither a gap nor an overlap.
        let labelsMaximumZoom = showCampsOnlyZoomedIn
            ? Float(MapRegionAnnotationFilter.campMinimumZoom)
            : styleMaximumZoom
        return CampLayerVisibility(
            boundariesVisible: boundariesVisible,
            boundariesMinimumZoom: boundariesVisible ? (showCampBoundariesAlways ? 0 : 15) : nil,
            labelsVisible: labelsVisible,
            labelsMaximumZoom: labelsMaximumZoom,
            campNamesDrawnByStyleLayer: labelsVisible
                && zoomLevel >= Double(labelsMinimumZoom)
                && zoomLevel < Double(labelsMaximumZoom)
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
                showCampsOnlyZoomedIn: UserSettings.showCampsOnlyZoomedIn,
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

    /// Last cap written to `camp-labels-big`, to spot the raises that need a re-parse.
    /// Starts at the style JSON's own (absent) upper bound.
    private var lastAppliedLabelsMaximumZoom = CampLayerVisibility.styleMaximumZoom

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

        if let labelsLayer = style.layer(withIdentifier: "camp-labels-big") {
            labelsLayer.isVisible = visibility.labelsVisible
            // Always assigned, never conditionally skipped: turning the "Camps (Zoomed)"
            // filter back off has to lift the cap again, not leave the last one in place.
            let capWasRaised = visibility.labelsMaximumZoom > lastAppliedLabelsMaximumZoom
            labelsLayer.maximumZoomLevel = visibility.labelsMaximumZoom
            lastAppliedLabelsMaximumZoom = visibility.labelsMaximumZoom
            // Lowering the cap hides the layer immediately, but raising it does not bring
            // it back: the tiles on screen were parsed while the layer was out of range,
            // and MapLibre only re-parses them when the camera moves — toggling the
            // layer's own properties (including `visibility`) does not ask for it. So a
            // filter change at a standing camera would leave camps unlabelled until the
            // user happened to pan. Reloading the style is the one lever that does
            // re-parse; it is cheap here (the style is a bundled asset, annotations are
            // not part of it) and only fires on the rare raise. The reload's own
            // `onStyleLoaded` calls back into this method, but by then the recorded cap
            // already matches, so it cannot recurse.
            if capWasRaised && visibility.labelsVisible {
                mapView.reloadStyle(nil)
            }
        }
    }

    /// Updates all managed layers
    func updateAllLayers() {
        updateCampLayerVisibility()
    }
}
