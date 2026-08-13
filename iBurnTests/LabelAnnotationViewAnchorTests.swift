//
//  LabelAnnotationViewAnchorTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers where a teardrop pin and its name label sit relative to the coordinate. A camp's
//  GPS is its polygon centroid, which is also where the `camp-labels-big` style layer sets
//  that camp's name — so a pin centred on the coordinate lands on the letters, and a label
//  starting at the coordinate lands on them too.
//

import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn

final class LabelAnnotationViewAnchorTests: XCTestCase {

    /// Where a point in the view's own coordinate space ends up relative to the annotation's
    /// geographic coordinate, once MapLibre has applied `centerOffset`.
    ///
    /// MapLibre places the view's *centre* at the coordinate plus the offset, so a local `y`
    /// lands `offset.dy + y - height/2` below the coordinate. Positive is below.
    private func offsetBelowCoordinate(ofLocalY y: CGFloat, in view: LabelAnnotationView) -> CGFloat {
        view.centerOffset.dy + y - view.bounds.height / 2
    }

    private func laidOutView() -> LabelAnnotationView {
        let view = LabelAnnotationView(reuseIdentifier: LabelAnnotationView.reuseIdentifier)
        view.imageView.image = UIImage(named: "BRCPurplePin")
        view.label.text = "Morning Beats & Brunch"
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return view
    }

    /// The teardrop's tip, not its middle, sits on the coordinate.
    func testLabelPinsAreAnchoredByTheirTip() {
        let view = laidOutView()
        XCTAssertEqual(view.centerOffset.dx, 0, accuracy: 0.001,
                       "Nothing about the anchoring is horizontal")
        XCTAssertEqual(offsetBelowCoordinate(ofLocalY: view.imageView.frame.maxY, in: view),
                       0,
                       accuracy: 0.001,
                       "The bottom edge of the pin artwork — its tip — belongs on the coordinate")
    }

    /// …and the pin's own name label hangs directly off the tip. A gap here reads as a caption
    /// floating loose in the desert rather than as this pin's name, which is the regression
    /// the 18 pt version shipped; duplicate camp names are suppressed by `PinLabelVisibility`
    /// instead.
    func testNameLabelHangsDirectlyOffTheTip() {
        let view = laidOutView()
        XCTAssertEqual(offsetBelowCoordinate(ofLocalY: view.label.frame.minY, in: view),
                       LabelAnnotationView.labelTopGap,
                       accuracy: 0.001,
                       "The label's top edge sits exactly `labelTopGap` below the coordinate")
        XCTAssertLessThanOrEqual(LabelAnnotationView.labelTopGap, 4,
                                 "A bigger gap separates the label from the pin it names")
    }

    /// The label has to fit inside the frame rather than spilling past its bottom.
    func testFrameIsTallEnoughForTheLabel() {
        let view = laidOutView()
        XCTAssertEqual(view.bounds.size, LabelAnnotationView.frameSize)
        XCTAssertLessThanOrEqual(view.label.frame.maxY, view.bounds.height + 0.5,
                                 "Label overflows the annotation view's bounds")
    }

    func testCommonInitAppliesTheOffset() {
        let view = LabelAnnotationView(reuseIdentifier: LabelAnnotationView.reuseIdentifier)
        XCTAssertEqual(view.centerOffset.dy, LabelAnnotationView.tipAnchoringCenterOffset.dy,
                       accuracy: 0.001)
        XCTAssertEqual(view.centerOffset.dx, 0, accuracy: 0.001)
    }

    /// Reuse must not quietly drop the anchoring — `prepareForReuse` resets image, text and
    /// `campUID`, and a future edit there is the likely way this would regress.
    func testOffsetSurvivesReuse() {
        let view = LabelAnnotationView(reuseIdentifier: LabelAnnotationView.reuseIdentifier)
        view.prepareForReuse()
        XCTAssertEqual(view.centerOffset.dy, LabelAnnotationView.tipAnchoringCenterOffset.dy,
                       accuracy: 0.001)
    }
}
