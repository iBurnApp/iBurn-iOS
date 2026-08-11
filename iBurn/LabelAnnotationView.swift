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

    func commonInit() {
        addSubview(imageView)
        addSubview(label)
        imageView.contentMode = .scaleAspectFit
        imageView.sizeAnchors == CGSize(width: Self.imageSide, height: Self.imageSide)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .label
        
        imageView.centerAnchors == centerAnchors
        label.topAnchor == imageView.bottomAnchor  // No spacing between emoji and label
        label.horizontalAnchors == horizontalAnchors

        frame = CGRect(x: 0, y: 0, width: 100, height: 45)  // Adjusted height
        centerOffset = Self.tipAnchoringCenterOffset
    }

    /// Lifts the view so the teardrop's **tip** sits on the coordinate instead of the pin's
    /// midriff — which is how a teardrop is meant to point, and what gets a favourited camp's
    /// pin off the top of the `camp-labels-big` style label drawn at that same coordinate (a
    /// camp's GPS is its polygon centroid, which is exactly where the layer sets its text).
    ///
    /// The image box's bottom edge is `imageSide / 2` below the view's center, so shifting the
    /// center up by that much puts the tip on the point. Nothing lands on the style text in
    /// its place: for style-labeled camps `PinLabelVisibility` has already hidden this view's
    /// own `label`, and camps the layer has no feature for have no style text to collide with.
    static let tipAnchoringCenterOffset = CGVector(dx: 0, dy: -imageSide / 2)

    // MARK: Overrides
    
    override func prepareForReuse() {
        imageView.image = nil
        label.text = nil
        label.isHidden = false
        campUID = nil
    }
}
