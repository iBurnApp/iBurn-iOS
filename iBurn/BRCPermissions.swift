//
//  BRCPermissions.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/14/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import PermissionScope

/** Wrapper around swift-only PermissionScope */
public class BRCPermissions: NSObject {
    
    /** Show location permissions prompt */
    public static func promptForLocation(completion: dispatch_block_t) {
        let pscope = PermissionScope()
        pscope.headerLabel.text = "Location"
        pscope.bodyLabel.text = "iBurn is best with location!"
        pscope.addPermission(PermissionConfig(type: .LocationInUse, demands: .Required, message: "Seriously, it's the way to go."))
        pscope.show(authChange: { (finished, results) -> Void in
            completion()
            println("got results \(results)")
        }) { (results) -> Void in
            println("thing was cancelled")
        }
    }
    
    /** Show notification permissions prompt */
    public static func promptForPush(completion: dispatch_block_t) {
        let pscope = PermissionScope()
        pscope.headerLabel.text = "Reminders"
        pscope.bodyLabel.text = "Don't you want reminders?"
        pscope.addPermission(PermissionConfig(type: .Notifications, demands: .Required, message: "Don't forget to live in the moment."))
        pscope.show(authChange: { (finished, results) -> Void in
            println("got results \(results)")
            completion()
            }) { (results) -> Void in
            println("thing was cancelled")
        }
    }
}
