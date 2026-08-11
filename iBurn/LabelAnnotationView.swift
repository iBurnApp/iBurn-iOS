//
//  LabelAnnotationView.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import Anchorage

final class LabelAnnotationView: MLNAnnotationView {

    // MARK: Properties
    
    static let reuseIdentifier = "LabelAnnotationView"
    
    
    let label = UILabel()
    let imageView = UIImageView()

    /// The camp's uid when `label` holds a camp's name, `nil` for everything else.
    ///
    /// `camp_labels.geojson` names most camps at the very coordinate their pin sits on (a
    /// camp's GPS is its polygon centroid), so `MapViewAdapter.updatePinLabelVisibility()`
    /// looks this uid up in `CampStyleLabelIndex` to decide whether this label would be a
    /// second copy. Reset on reuse like everything else this view carries.
    var campUID: String?

    // MARK: Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Side of the square the pin artwork is aspect-fitted into.
    ///
    /// `BRCPurplePin` and friends are 30×70 pt teardrops whose point is at the *bottom*, so
    /// fitted into this box they fill its full height: the box's bottom edge is the tip.
    static let imageSide: CGFloat = 30

    /// Clear air between the teardrop's tip — which sits *on* the coordinate — and the top of
    /// the pin's own name label.
    ///
    /// The `camp-labels-big` style layer draws a camp's name centred on that same coordinate
    /// at 9–14 pt with a 2 pt halo, so a label starting at the coordinate lands on top of the
    /// letters (an event pin at a camp: "Morning Beats & B…" over "Camp TeaPunk"). 18 pt
    /// clears a single line of style text at every zoom the layer draws at, and still clears
    /// most of a wrapped two-line name, without floating the label away from its pin.
    static let labelTopGap: CGFloat = 18

    /// Height reserved for the one-line name label (10 pt system font ≈ 12 pt line box).
    static let labelHeight: CGFloat = 14

    /// The annotation view's fixed size. Tall enough that the label — pushed down by
    /// `labelTopGap` — still lies inside the bounds rather than spilling past them.
    static let frameSize = CGSize(width: 100, height: imageSide + labelTopGap + labelHeight)

    func commonInit() {
        addSubview(imageView)
        addSubview(label)
        imageView.contentMode = .scaleAspectFit
        imageView.sizeAnchors == CGSize(width: Self.imageSide, height: Self.imageSide)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .label

        // Top-anchored, not centre-anchored: the tip's distance from the view's top edge is
        // then a constant (`imageSide`) that `tipAnchoringCenterOffset` can be derived from,
        // and the frame can grow downwards to fit the label without moving the pin.
        imageView.topAnchor == topAnchor
        imageView.centerXAnchor == centerXAnchor
        label.topAnchor == imageView.bottomAnchor + Self.labelTopGap
        label.horizontalAnchors == horizontalAnchors

        frame = CGRect(origin: .zero, size: Self.frameSize)
        centerOffset = Self.tipAnchoringCenterOffset
    }

    /// Lifts the view so the teardrop's **tip** sits on the coordinate instead of the pin's
    /// midriff — which is how a teardrop is meant to point, and what gets a favourited camp's
    /// pin off the top of the `camp-labels-big` style label drawn at that same coordinate (a
    /// camp's GPS is its polygon centroid, which is exactly where the layer sets its text).
    ///
    /// MapLibre places the view's *centre* at the coordinate plus this offset, and the tip is
    /// `imageSide` below the view's top edge, i.e. `imageSide - height/2` below the centre —
    /// so shifting the centre up by exactly that much lands the tip on the point. Nothing
    /// takes its place on the style text: for style-labeled camps `PinLabelVisibility` has
    /// already hidden this view's own `label`, and the `labelTopGap` keeps every other pin's
    /// label below whatever the layer drew.
    static let tipAnchoringCenterOffset = CGVector(dx: 0, dy: frameSize.height / 2 - imageSide)

    // MARK: Overrides
    
    override func prepareForReuse() {
        imageView.image = nil
        label.text = nil
        label.isHidden = false
        campUID = nil
    }
}
