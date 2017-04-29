//
//  BRCFavoritesViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/17/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase

class BRCFavoritesViewController: BRCSortedViewController {

    required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Favorite things to see them here."
    }
    
    required init!(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func refreshTableItems(_ completion: @escaping ()->()) {
        var favorites: [BRCDataObject] = []
        BRCDatabaseManager.sharedInstance().readConnection.asyncRead({ (transaction) -> Void in
            if let viewTransaction = transaction.ext(self.extensionName) as? YapDatabaseViewTransaction {
                viewTransaction.enumerateGroups({ (group, stop) -> Void in
                    viewTransaction.enumerateKeysAndObjects(inGroup: group, with: [], using: { (collection: String, key: String, object: Any, index: UInt, stop: UnsafeMutablePointer<ObjCBool>) in
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
            BRCDataSorter.sortDataObjects(favorites, options: options, completionQueue: DispatchQueue.main, callbackBlock: { (events, art, camps) -> (Void) in
                self.processSortedData(events, art: art, camps: camps, completion: completion)
            })
        })
    }

}
