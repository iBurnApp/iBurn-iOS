//
//  MapAnnotationRegistry.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre

/// The adapter's record of which annotation object is on the map under which stable key.
///
/// Split out of `MapViewAdapter` because this is where user pins duplicate: several
/// sources hand the adapter *different instances of the same pin* (a pin the user just
/// placed, the copy `observeUserMapPins` rebuilds from the database on the next write,
/// the copy `UserGuidance` builds to answer "where's my bike"), and the map will happily
/// draw all of them stacked on one coordinate. Everything the adapter puts on or takes
/// off the map goes through here, and both directions are keyed *and identity-checked*,
/// so a pin can be on the map exactly once and only the instance that is actually up
/// there can give up its key.
///
/// Pure, so the rules can be tested without an `MLNMapView`.
struct MapAnnotationRegistry {

    /// Everything currently on the map that has a stable key, by key.
    private(set) var annotationsByID: [AnyHashable: MLNAnnotation] = [:]

    var count: Int { annotationsByID.count }

    // MARK: - Keys

    /// The stable identity of `annotation`, or nil for annotations that aren't tracked
    /// (the dropped-person marker, the user location) and are simply passed through.
    static func key(for annotation: MLNAnnotation) -> AnyHashable? {
        if let data = annotation as? DataObjectAnnotation {
            let className = String(describing: type(of: data.object))
            return AnyHashable("\(className):\(data.object.uniqueID)")
        } else if let playa = annotation as? PlayaObjectAnnotation {
            return AnyHashable(playa.id)
        } else if let userPin = annotation as? BRCUserMapPoint {
            // `yapKey` is a fresh random UUID every time the pin is rebuilt from PlayaDB,
            // so it can never de-duplicate. `pinId` is the stable PlayaDB row id.
            return AnyHashable("BRCUserMapPoint:\(userPin.pinId)")
        } else if let mapPoint = annotation as? BRCMapPoint {
            let className = String(describing: type(of: mapPoint))
            return AnyHashable("\(className):\(mapPoint.yapKey)")
        }
        return nil // Non-trackable annotations
    }

    // MARK: - Lookup

    /// The instance on the map holding `annotation`'s key — which may well be a different
    /// object than `annotation` itself. Nil when nothing holds that key.
    func annotation(matching annotation: MLNAnnotation) -> MLNAnnotation? {
        guard let key = Self.key(for: annotation) else { return nil }
        return annotationsByID[key]
    }

    /// Whether this exact object is the one on the map for its key.
    func isOnMap(_ candidate: MLNAnnotation) -> Bool {
        annotation(matching: candidate) === candidate
    }

    /// Whether any of `annotations` carries the same key as `candidate`.
    ///
    /// Used to decide when a locally placed pin can be handed over to the data source's
    /// copy of that same pin.
    static func contains(keyOf candidate: MLNAnnotation, in annotations: [MLNAnnotation]) -> Bool {
        guard let target = key(for: candidate) else { return false }
        return annotations.contains { key(for: $0) == target }
    }

    // MARK: - Mutation

    /// Registers `annotations` and returns the ones the caller should actually add to the
    /// map: the untracked pass-throughs, plus the tracked ones whose key was free.
    mutating func add(_ annotations: [MLNAnnotation]) -> [MLNAnnotation] {
        annotations.filter { annotation in
            guard let key = Self.key(for: annotation) else {
                return true // Non-trackable always added
            }
            guard annotationsByID[key] == nil else {
                return false // Something is already on the map under this key
            }
            annotationsByID[key] = annotation
            return true
        }
    }

    /// Deregisters `annotations` and returns the ones the caller should take off the map.
    ///
    /// An annotation whose key is held by a *different* instance is dropped from the
    /// result rather than deregistered: it was de-duplicated away when it was added, so
    /// it was never on the map, and letting it clear the key would strand the pin that is
    /// (which is how a reload used to leave an untracked duplicate behind).
    mutating func remove(_ annotations: [MLNAnnotation]) -> [MLNAnnotation] {
        annotations.filter { annotation in
            guard let key = Self.key(for: annotation) else {
                return true // Non-trackable: nothing to deregister, just take it off
            }
            guard let tracked = annotationsByID[key], tracked === annotation else {
                return false
            }
            annotationsByID.removeValue(forKey: key)
            return true
        }
    }
}
