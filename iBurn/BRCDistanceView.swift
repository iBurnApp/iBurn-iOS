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
        addSubview(distanceLabel)
        distanceLabel.autoPinEdgesToSuperviewEdgesWithInsets(UIEdgeInsetsZero)
        backgroundColor = UIColor.clearColor()
        distanceLabel.backgroundColor = UIColor.clearColor()
    }
    
    public func updateDistanceFromLocation(fromLocation: CLLocation) {
        let distance = destination.distanceFromLocation(fromLocation)
        let distanceString = TTTLocationFormatter.brc_humanizedStringForDistance(distance)
        distanceLabel.attributedText = distanceString
        distanceLabel.sizeToFit()
        self.frame = CGRectMake(frame.origin.x, frame.origin.y, distanceLabel.frame.size.width, distanceLabel.frame.size.height)
    }

    required public init(coder aDecoder: NSCoder) {
        destination = CLLocation()
        super.init(coder: aDecoder)
    }
    
}
