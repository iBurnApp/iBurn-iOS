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
/// The two layers no longer share an embargo verdict: since 2026-08-28 (BMorg request) the
/// `camp-boundaries` footprint polygons are the one surface the staff passcode does **not**
/// unlock, so they resolve off `MapEmbargo.allowsCampBoundaryPolygons()` (region + gates, no
/// bypass) while `camp-labels-big` keeps `MapEmbargo.allowsBulkCampPlacement()`.
///
/// Since `apply_placement.js` started writing each camp's GPS from that same polygon
/// centroid, a camp pin sits on *exactly* the point its style label is drawn at, so any
/// overlap is text stacked on identical text. **The style layer wins that contest**: it
/// runs over its full zoom range, uncapped, and `campNamesDrawnByStyleLayer` tells the pins
/// when it is painting so they can stay bare glyphs. Which *camps* it paints is a per-camp
/// question the geojson answers — see `CampStyleLabelIndex` and `PinLabelVisibility`.
struct CampLayerVisibility: Equatable {
    /// The symbol layer that draws camp names, in both `iburn-light.json` and
    /// `iburn-dark.json`. Its features carry the camp's `uid`, which is what makes the drawn
    /// text a tap target — see `MapViewAdapter.campUID(forStyleLabelAt:)`.
    static let labelsLayerIdentifier = "camp-labels-big"

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
    ///   - embargoAllowsPlacement: `MapEmbargo.allowsBulkCampPlacement()` — the gates-open
    ///     tier, passcode included. Both layers are built from the BMorg placement drop and
    ///     both draw the whole city at once: the polygons are the footprints themselves, and
    ///     a name pinned to its placement centroid is that camp's exact position with a label
    ///     on it. Neither is the "one camp you looked up" the week-early camp release covers,
    ///     so both wait for gates. Both geojsons ship in the app bundle, so until then the
    ///     layers stay hidden regardless of settings. This governs `camp-labels-big`.
    ///   - embargoAllowsBoundaryPolygons: `MapEmbargo.allowsCampBoundaryPolygons()` — the
    ///     same gates-open instant, but **without** the passcode bypass (BMorg request,
    ///     2026-08-28: the staff passcode must no longer reveal the camp footprint polygons).
    ///     Governs `camp-boundaries` only; a passcode-only unlock leaves the polygons hidden
    ///     while the labels and bulk pins come back as before. Since it is never more
    ///     permissive than `embargoAllowsPlacement`, the polygons remain a subset of what the
    ///     rest of the placement layers show.
    ///   - zoomLevel: the map's current zoom, for `campNamesDrawnByStyleLayer`.
    static func resolve(showCampBoundaries: Bool,
                        showCampBoundariesAlways: Bool,
                        showBigCampNames: Bool,
                        embargoAllowsPlacement: Bool,
                        embargoAllowsBoundaryPolygons: Bool,
                        zoomLevel: Double) -> CampLayerVisibility {
        let boundariesVisible = showCampBoundaries && embargoAllowsBoundaryPolygons
        let labelsVisible = showBigCampNames && embargoAllowsPlacement
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
                embargoAllowsPlacement: MapEmbargo.allowsBulkCampPlacement(),
                embargoAllowsBoundaryPolygons: MapEmbargo.allowsCampBoundaryPolygons(),
                zoomLevel: zoomLevel)
    }
}

/// Manages runtime visibility of map style layers
class MapLayerManager {
    private weak var mapView: MLNMapView?

    private let campLayerIdentifiers = [
        "camp-boundaries",
        CampLayerVisibility.labelsLayerIdentifier
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
        if let labelsLayer = style.layer(withIdentifier: CampLayerVisibility.labelsLayerIdentifier) {
            labelsLayer.isVisible = visibility.labelsVisible
        }
    }

    /// Updates all managed layers
    func updateAllLayers() {
        updateCampLayerVisibility()
    }
}
