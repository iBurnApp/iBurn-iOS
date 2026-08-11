//
//  DropPersonGate.swift
//  iBurn
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Decides whether a long press on the main map is allowed to drop the person.
//
//  Two long presses live on the same map and used to fire together. The map-wide
//  `iBurn.dropPersonLongPress` (0.45 s, installed by `MainMapViewController`) drops the
//  person; the per-view one that `UserMapViewAdapter` puts on each user pin (0.5 s, see
//  `ImageAnnotationView.addLongPressGestureIfNeeded`) starts a pin drag, as does MapLibre's
//  own press-and-hold on a draggable annotation view. Pressing a home/bike/favourite pin
//  therefore both picked the pin up *and* stood a person on top of it.
//
//  A recognizer dependency (`require(toFail:)`) can't express this: the pin's recognizer is
//  attached to a view that may not exist yet when the map's is installed, and the two aren't
//  in a fail/succeed relationship anyway — the pin drag simply owns that touch. So the map's
//  recognizer asks this type, from `gestureRecognizerShouldBegin`, before it begins.
//

import MapLibre
import UIKit

/// What a long press on the main map landed on.
enum DropPersonTouchTarget: Equatable {
    /// Bare map — no annotation view under the touch.
    case map
    /// A user pin (home / bike / saved favourite): draggable, and its drag and edit UX owns
    /// the press.
    case userPin
    /// Any other annotation view — a camp/art/event pin, the "you are here" dot, or the
    /// dropped person itself. None of these do anything with a long press.
    case otherAnnotation
}

enum DropPersonGate {

    /// The rule, as a pure function.
    ///
    /// Only the user's own pins veto the drop. Long-pressing a camp or art pin still drops
    /// the person there — nothing else claims that gesture, it is a natural way to say "look
    /// from this camp", and it is the only lever UI automation has for choosing a drop
    /// coordinate (the map view itself is not an accessibility element).
    ///
    /// - Parameters:
    ///   - target: what the press hit. See `target(forHitView:)`.
    ///   - isEditingUserPin: `UserMapViewAdapter.isEditingUserPin` — true from the moment a
    ///     pin enters edit/drag state (callout pencil, callout long press) until it is saved
    ///     or deselected. While that is true the whole map is the pin's, wherever the finger
    ///     lands: a drop mid-edit would push a callout over the pin being moved.
    static func shouldDropPerson(target: DropPersonTouchTarget, isEditingUserPin: Bool) -> Bool {
        guard !isEditingUserPin else { return false }
        switch target {
        case .userPin: return false
        case .map, .otherAnnotation: return true
        }
    }

    /// Classifies the view the map hit-tested at the press point.
    ///
    /// Walks the superview chain rather than testing `view` alone: an annotation view's
    /// touch lands on the `UIImageView` (or label) inside it, never on the annotation view
    /// itself.
    ///
    /// - Parameter classify: the per-view verdict, injectable so the walk can be tested
    ///   without building MapLibre views. Defaults to `annotationTarget(for:)`.
    static func target(forHitView view: UIView?,
                       classify: (UIView) -> DropPersonTouchTarget? = DropPersonGate.annotationTarget) -> DropPersonTouchTarget {
        var candidate = view
        while let current = candidate {
            if let target = classify(current) { return target }
            candidate = current.superview
        }
        return .map
    }

    /// `nil` for anything that isn't an annotation view.
    ///
    /// `isDraggable` is the discriminator because it is exactly what `UserMapViewAdapter`
    /// sets on — and only on — `BRCUserMapPoint` views, the same views it hangs the
    /// pin-drag long press off.
    static func annotationTarget(for view: UIView) -> DropPersonTouchTarget? {
        guard let annotationView = view as? MLNAnnotationView else { return nil }
        return annotationView.isDraggable ? .userPin : .otherAnnotation
    }
}
