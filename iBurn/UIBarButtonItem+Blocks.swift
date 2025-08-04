//
//  UIBarButtonItem+Blocks.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

typealias UIBarButtonItemTargetClosure = (_ sender: Any?) -> ()

extension UIBarButtonItem {
    convenience init(title: String?, style: UIBarButtonItem.Style, closure: @escaping UIBarButtonItemTargetClosure) {
        self.init(title: title, primaryAction: .init(handler: { action in
            closure(action.sender)
        }))
    }
    
    convenience init(barButtonSystemItem: UIBarButtonItem.SystemItem, closure: @escaping UIBarButtonItemTargetClosure) {
        self.init(systemItem: barButtonSystemItem, primaryAction: .init(handler: { action in
            closure(action.sender)
        }))
    }
    
    convenience init(image: UIImage?, style: UIBarButtonItem.Style, closure: @escaping UIBarButtonItemTargetClosure) {
        self.init(image: image, primaryAction: .init(handler: { action in
            closure(action.sender)
        }))
    }
}
