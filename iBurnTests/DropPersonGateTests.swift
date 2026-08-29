//
//  DropPersonGateTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers `DropPersonGate`: which long presses on the main map are allowed to stand the
//  person somewhere, and which belong to a user pin's own drag/edit UX instead.
//

import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn

final class DropPersonGateTests: XCTestCase {

    // MARK: - The rule

    func testBareMapDropsThePerson() {
        XCTAssertTrue(DropPersonGate.shouldDropPerson(target: .map, isEditingUserPin: false))
    }

    func testUserPinVetoesTheDrop() {
        XCTAssertFalse(DropPersonGate.shouldDropPerson(target: .userPin, isEditingUserPin: false),
                       "A long press on a home/bike/favourite pin picks the pin up instead")
    }

    func testOtherAnnotationsStillDropThePerson() {
        XCTAssertTrue(DropPersonGate.shouldDropPerson(target: .otherAnnotation, isEditingUserPin: false),
                      "Camp/art pins claim no long press, and this is UI automation's only drop lever")
    }

    func testEditingAPinVetoesTheDropAnywhereOnTheMap() {
        for target in [DropPersonTouchTarget.map, .userPin, .otherAnnotation] {
            XCTAssertFalse(DropPersonGate.shouldDropPerson(target: target, isEditingUserPin: true),
                           "Mid-edit the whole map belongs to the pin being moved (\(target))")
        }
    }

    // MARK: - Hit-test walk

    /// The touch lands on the image view *inside* an annotation view, so classifying only the
    /// hit view itself would miss every pin.
    func testWalkFindsAnAnnotationViewAboveTheHitView() {
        let annotationView = UIView()
        let inner = UIView()
        annotationView.addSubview(inner)

        let target = DropPersonGate.target(forHitView: inner) { view in
            view === annotationView ? .userPin : nil
        }
        XCTAssertEqual(target, .userPin)
    }

    func testWalkStopsAtTheNearestAnnotationView() {
        let outer = UIView()
        let inner = UIView()
        let leaf = UIView()
        outer.addSubview(inner)
        inner.addSubview(leaf)

        let target = DropPersonGate.target(forHitView: leaf) { view in
            if view === inner { return .userPin }
            if view === outer { return .otherAnnotation }
            return nil
        }
        XCTAssertEqual(target, .userPin, "The innermost annotation view owns the touch")
    }

    func testChainWithNoAnnotationViewIsBareMap() {
        let mapView = UIView()
        let child = UIView()
        mapView.addSubview(child)

        XCTAssertEqual(DropPersonGate.target(forHitView: child) { _ in nil }, .map)
    }

    func testNilHitViewIsBareMap() {
        XCTAssertEqual(DropPersonGate.target(forHitView: nil) { _ in nil }, .map)
    }

    // MARK: - Classification

    func testPlainViewsAreNotAnnotations() {
        XCTAssertNil(DropPersonGate.annotationTarget(for: UIView()))
    }

    /// `isDraggable` is exactly what `UserMapViewAdapter` sets on `BRCUserMapPoint` views and
    /// on nothing else, so it is the discriminator between "the user's pin" and "a pin".
    func testDraggableAnnotationViewsAreUserPins() {
        let draggable = MLNAnnotationView(reuseIdentifier: "draggable")
        draggable.isDraggable = true
        XCTAssertEqual(DropPersonGate.annotationTarget(for: draggable), .userPin)

        let fixed = MLNAnnotationView(reuseIdentifier: "fixed")
        fixed.isDraggable = false
        XCTAssertEqual(DropPersonGate.annotationTarget(for: fixed), .otherAnnotation)
    }

    /// End to end through the real classifier: an image view inside a draggable annotation
    /// view — the exact shape of `ImageAnnotationView` — vetoes the drop.
    func testUserPinSubviewVetoesTheDropThroughTheRealClassifier() {
        let annotationView = MLNAnnotationView(reuseIdentifier: "pin")
        annotationView.isDraggable = true
        let imageView = UIImageView()
        annotationView.addSubview(imageView)

        let target = DropPersonGate.target(forHitView: imageView)
        XCTAssertEqual(target, .userPin)
        XCTAssertFalse(DropPersonGate.shouldDropPerson(target: target, isEditingUserPin: false))
    }
}
