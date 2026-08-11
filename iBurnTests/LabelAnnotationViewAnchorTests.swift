//
//  LabelAnnotationViewAnchorTests.swift
//  iBurnTests
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Covers where a teardrop pin sits relative to its coordinate. A camp's GPS is its polygon
//  centroid, which is also where the `camp-labels-big` style layer sets that camp's name, so
//  a pin centred on the coordinate lands on the letters.
//

import Foundation
import MapLibre
import UIKit
import XCTest
@testable import iBurn

final class LabelAnnotationViewAnchorTests: XCTestCase {

    /// The teardrop's tip, not its middle, sits on the coordinate.
    func testLabelPinsAreAnchoredByTheirTip() {
        XCTAssertEqual(LabelAnnotationView.tipAnchoringCenterOffset.dx, 0,
                       "Nothing about the fix is horizontal")
        XCTAssertEqual(LabelAnnotationView.tipAnchoringCenterOffset.dy,
                       -LabelAnnotationView.imageSide / 2,
                       accuracy: 0.001,
                       "Lifting by half the image box puts its bottom edge on the coordinate")
        XCTAssertLessThan(LabelAnnotationView.tipAnchoringCenterOffset.dy, 0,
                          "A positive dy would push the pin down onto the label instead")
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
