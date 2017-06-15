//
//  BRCAnnotationView.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/12/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import PureLayout

class BRCAnnotationView: MGLAnnotationView {
    
    let imageView = UIImageView()
    
    override func prepareForReuse() {
        imageView.image = nil
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
