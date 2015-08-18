//
//  BRCFavoritesViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit

class BRCFavoritesViewController: BRCSortedViewController {

    required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Favorite things to see them here."
    }
    
    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }
    
    override func refreshTableItems() {
        var favorites: [BRCDataObject] = []
        BRCDatabaseManager.sharedInstance().readConnection.asyncReadWithBlock({ (transaction: YapDatabaseReadTransaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroupsUsingBlock({ (group: String!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    viewTransaction.enumerateKeysAndObjectsInGroup(group, usingBlock: { (collection: String!, key: String!, object: AnyObject!, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                        if let dataObject = object as? BRCDataObject {
                            favorites.append(dataObject)
                        }
                    })
                })
            }
        }, completionBlock: { () -> Void in
            let options = BRCDataSorterOptions()
            options.showFutureEvents = true
            options.showExpiredEvents = true
            BRCDataSorter.sortDataObjects(favorites, options: options, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
                self.processSortedData(events, art: art, camps: camps)
            })
        })
    }

}
