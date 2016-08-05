//
//  BRCAudioTourViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/3/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

import UIKit

class BRCAudioTourViewController: BRCSortedViewController {

    override func refreshTableItems(completion: dispatch_block_t) {
        var art: [BRCArtObject] = []
        BRCDatabaseManager.sharedInstance().readConnection.asyncReadWithBlock({ (transaction: YapDatabaseReadTransaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroupsUsingBlock({ (group: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    viewTransaction.enumerateKeysAndObjectsInGroup(group, usingBlock: { (collection: String!, key: String!, object: AnyObject!, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                        if let dataObject = object as? BRCArtObject {
                            art.append(dataObject)
                        }
                    })
                })
            }
            }, completionBlock: { () -> Void in
                NSLog("Audio Tour count: %d", art.count)
                BRCDataSorter.sortDataObjects(art, options: nil, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                    self.processSortedData(events, art: art, camps: camps, completion: completion)
                })
        })
    }

}
