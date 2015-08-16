//
//  BRCDistanceView.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/15/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import BButton
import PureLayout

public class BRCDistanceView: UIView {
    
    let distanceLabel: UILabel = UILabel()
    var destination: CLLocation
    
    public init(frame: CGRect, destination aDestination: CLLocation) {
        destination = aDestination
        super.init(frame: frame)
        distanceLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        distanceLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        addSubview(distanceLabel)
        backgroundColor = UIColor(white: 1.0, alpha: 0.9)
    }
    
    public func updateDistanceFromLocation(fromLocation: CLLocation) {
        let distance = destination.distanceFromLocation(fromLocation)
        let text = NSMutableAttributedString()
        let distanceString = TTTLocationFormatter.brc_humanizedStringForDistance(distance)
        text.appendAttributedString(distanceString)
        text.appendAttributedString(NSAttributedString(string: " Away"))
        distanceLabel.attributedText = text
        setNeedsLayout()
    }

    required public init(coder aDecoder: NSCoder) {
        destination = CLLocation()
        super.init(coder: aDecoder)
    }
    
}
