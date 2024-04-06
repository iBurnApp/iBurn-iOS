//
//  UIBarButtonItem+Blocks.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

// https://gist.github.com/BeauNouvelle/442718f778db4edf52f9b688308be081#file-uibarbuttonitem-closure-1-swift

/// Typealias for UIBarButtonItem closure.
typealias UIBarButtonItemTargetClosure = (UIBarButtonItem) -> ()

private class UIBarButtonItemClosureWrapper: NSObject {
    let closure: UIBarButtonItemTargetClosure
    init(_ closure: @escaping UIBarButtonItemTargetClosure) {
        self.closure = closure
    }
}

extension UIBarButtonItem {
    
    private struct AssociatedKeys {
        static var targetClosure = "targetClosure"
    }
    
    private var targetClosure: UIBarButtonItemTargetClosure? {
        get {
            withUnsafePointer(to: AssociatedKeys.targetClosure) {
                guard let closureWrapper = objc_getAssociatedObject(self, $0) as? UIBarButtonItemClosureWrapper else { return nil }
                return closureWrapper.closure
            }
        }
        set(newValue) {
            guard let newValue = newValue else { return }
            withUnsafePointer(to: AssociatedKeys.targetClosure) {
                objc_setAssociatedObject(self, $0, UIBarButtonItemClosureWrapper(newValue), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    convenience init(title: String?, style: UIBarButtonItem.Style, closure: @escaping UIBarButtonItemTargetClosure) {
        self.init(title: title, style: style, target: nil, action: nil)
        targetClosure = closure
        action = #selector(UIBarButtonItem.closureAction)
    }
    
    convenience init(barButtonSystemItem: UIBarButtonItem.SystemItem, closure: @escaping UIBarButtonItemTargetClosure) {
        self.init(barButtonSystemItem: barButtonSystemItem, target: nil, action: nil)
        targetClosure = closure
        action = #selector(UIBarButtonItem.closureAction)
    }
    
    @objc func closureAction() {
        guard let targetClosure = targetClosure else { return }
        targetClosure(self)
    }
}
