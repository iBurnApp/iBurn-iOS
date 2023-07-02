//
//  LabelAnnotationView.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/11/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import Anchorage

final class LabelAnnotationView: MGLAnnotationView {

    // MARK: Properties
    
    static let reuseIdentifier = "LabelAnnotationView"
    
    
    let label = UILabel()
    let imageView = UIImageView()
    
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
        // Replace this with dynamic color when we support dark theme for the map itself
        label.textColor = .darkText
        
        imageView.centerAnchors == centerAnchors
        label.topAnchor == imageView.bottomAnchor - 10
        label.horizontalAnchors == horizontalAnchors

        frame = CGRect(x: 0, y: 0, width: 100, height: 40)
    }
    
    // MARK: Overrides
    
    override func prepareForReuse() {
        imageView.image = nil
        label.text = nil
    }
}
