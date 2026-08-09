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

    /// True when `label` holds a camp's name, which the `camp-labels-big` style layer also
    /// draws — at the very same coordinate, since a camp's GPS is its polygon centroid.
    /// `MapViewAdapter.updatePinLabelVisibility()` uses this to keep exactly one of the two
    /// showing. Reset on reuse like everything else this view carries.
    var drawsCampName = false

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
    
    func commonInit() {
        addSubview(imageView)
        addSubview(label)
        imageView.contentMode = .scaleAspectFit
        imageView.sizeAnchors == CGSize(width: 30, height: 30)
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = .label
        
        imageView.centerAnchors == centerAnchors
        label.topAnchor == imageView.bottomAnchor  // No spacing between emoji and label
        label.horizontalAnchors == horizontalAnchors

        frame = CGRect(x: 0, y: 0, width: 100, height: 45)  // Adjusted height
    }
    
    // MARK: Overrides
    
    override func prepareForReuse() {
        imageView.image = nil
        label.text = nil
        label.isHidden = false
        drawsCampName = false
    }
}
