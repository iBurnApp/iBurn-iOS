//
//  CampStyleLabelIndex.swift
//  iBurn
//
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CocoaLumberjack

/// Which camps the `camp-labels-big` style layer already draws a name for.
///
/// The layer is fed by `camp_labels.geojson` inside `Map.bundle` — one Point per camp the
/// placement data gave a footprint, carrying that camp's `uid`. Since the style layer is the
/// authoritative name renderer, a camp listed in that file needs no name under its pin, and
/// one that is *missing* from it (8 of 1191 camps in 2026, and every camp in a year whose
/// placement has not dropped yet) still has to label itself or it goes nameless.
///
/// Read the file rather than assuming: "does the shipped geojson name this camp" is exactly
/// the question, and any answer derived from something else drifts as the data changes.
///
/// Main-thread confined. `load(then:)` does the parse on a background queue and calls back on
/// the main queue; until it lands `labeledCampUIDs` is `nil`, which
/// `PinLabelVisibility.labelIsHidden` reads as "assume the layer has it" — the right guess for
/// all but a handful of camps, and the one that avoids a flash of doubled names at launch.
final class CampStyleLabelIndex {

    static let shared = CampStyleLabelIndex()

    /// `nil` until the file has been read. Empty when there is no such file, or it names no
    /// camps — a pre-placement year, where every pin labels itself.
    private(set) var labeledCampUIDs: Set<String>?

    private let fileURL: URL?
    private var isLoading = false
    private var pending: [() -> Void] = []

    /// - Parameter fileURL: the geojson to read. Defaults to the bundled file the shipped
    ///   style layer points `asset://…/Map.bundle/camp_labels.geojson` at, so the index and
    ///   the layer can only ever be reading the same data.
    init(fileURL: URL? = Bundle.brc_mapBundle.url(forResource: "camp_labels", withExtension: "geojson")) {
        self.fileURL = fileURL
    }

    /// Loads the index if it hasn't been loaded, then runs `completion` on the main queue.
    ///
    /// `completion` runs on every call — immediately when the index is already loaded — so
    /// callers can use it as "apply the current answer" without tracking load state.
    func load(then completion: (() -> Void)? = nil) {
        if labeledCampUIDs != nil {
            completion?()
            return
        }
        if let completion {
            pending.append(completion)
        }
        guard !isLoading else { return }
        isLoading = true
        let fileURL = self.fileURL
        DispatchQueue.global(qos: .userInitiated).async {
            let uids = CampStyleLabelIndex.parse(contentsOf: fileURL)
            DispatchQueue.main.async {
                self.labeledCampUIDs = uids
                self.isLoading = false
                let callbacks = self.pending
                self.pending = []
                callbacks.forEach { $0() }
            }
        }
    }

    // MARK: - Parsing

    /// Only the `uid` of each feature's properties — the geometry is the style layer's
    /// business, and skipping it keeps a 300 KB file cheap to read.
    private struct LabelCollection: Decodable {
        struct Feature: Decodable {
            struct Properties: Decodable {
                let uid: String?
            }
            let properties: Properties?
        }
        let features: [Feature]?
    }

    static func parse(contentsOf fileURL: URL?) -> Set<String> {
        guard let fileURL, let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            DDLogWarn("camp_labels.geojson missing; camp pins will label themselves")
            return []
        }
        return parse(data)
    }

    static func parse(_ data: Data) -> Set<String> {
        do {
            let collection = try JSONDecoder().decode(LabelCollection.self, from: data)
            let uids = (collection.features ?? []).compactMap { $0.properties?.uid }
            return Set(uids)
        } catch {
            DDLogError("Could not parse camp_labels.geojson: \(error)")
            return []
        }
    }
}

/// Whether the name label a map pin carries is drawn or hidden.
///
/// Pure, so the two-mechanism split can be reasoned about (and tested) without a map view.
/// Two rules, in order:
///
///  1. far enough out, every pin's name is unreadable clutter and stays hidden;
///  2. a camp the `camp-labels-big` style layer names has no business naming itself — that is
///     the same text at the same coordinate, since a camp's GPS *is* the point its style label
///     is drawn at.
///
/// Everything else — art, events, map points, and camps the style layer has no feature for —
/// labels itself as it always did.
enum PinLabelVisibility {

    /// - Parameters:
    ///   - zoomLevel: the map's current zoom.
    ///   - hiddenAtOrBelowZoom: `MapViewAdapter.pinLabelHiddenAtOrBelowZoom`.
    ///   - campUID: the camp's uid, or `nil` when the pin isn't a camp.
    ///   - styleDrawsCampNames: `CampLayerVisibility.campNamesDrawnByStyleLayer` — false when
    ///     the layer is off, embargoed, or below its own minzoom, in which case a camp has to
    ///     label itself whatever the geojson says.
    ///   - styleLabeledCampUIDs: `CampStyleLabelIndex.labeledCampUIDs`; `nil` while it is still
    ///     loading, read as "the layer has this camp".
    static func labelIsHidden(zoomLevel: Double,
                              hiddenAtOrBelowZoom: Double,
                              campUID: String?,
                              styleDrawsCampNames: Bool,
                              styleLabeledCampUIDs: Set<String>?) -> Bool {
        if zoomLevel <= hiddenAtOrBelowZoom { return true }
        guard let campUID, styleDrawsCampNames else { return false }
        guard let styleLabeledCampUIDs else { return true }
        return styleLabeledCampUIDs.contains(campUID)
    }
}
