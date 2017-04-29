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

open class BRCDistanceView: UIView {
    
    let distanceLabel: UILabel = UILabel()
    var destination: CLLocation
    
    public init(frame: CGRect, destination aDestination: CLLocation) {
        destination = aDestination
        super.init(frame: frame)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(distanceLabel)
        distanceLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        backgroundColor = UIColor.clear
        distanceLabel.backgroundColor = UIColor.clear
    }
    
    open func updateDistanceFromLocation(_ fromLocation: CLLocation) {
        let distance = destination.distance(from: fromLocation)
        let distanceString = TTTLocationFormatter.brc_humanizedString(forDistance: distance)
        distanceLabel.attributedText = distanceString
        distanceLabel.sizeToFit()
        self.frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: distanceLabel.frame.size.width, height: distanceLabel.frame.size.height)
    }

    required public init?(coder aDecoder: NSCoder) {
        destination = CLLocation()
        super.init(coder: aDecoder)
    }
    
}
