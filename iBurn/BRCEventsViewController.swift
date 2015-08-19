//
//  BRCEventsViewController.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/18/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit

/** This is for showing a list of events hosted by camp/art */
class BRCEventsViewController: BRCSortedViewController {
    
    var relatedObject: BRCDataObject?

    /** You'll want to pass in the YapDatabaseRelationship extensionName. RelatedObject should be a BRCCampObject or BRCArtObject for event lookup. */
    init(style: UITableViewStyle, extensionName ext: String, relatedObject obj: BRCDataObject) {
        relatedObject = obj
        super.init(style: style, extensionName: ext)
        emptyDetailText = "Looks like there's no listed events."
    }
    
    required init!(coder aDecoder: NSCoder!) {
        super.init(coder: aDecoder)
    }

    required init(style: UITableViewStyle, extensionName ext: String) {
        super.init(style: style, extensionName: ext)
    }
    
    internal override func refreshTableItems() {
        var eventObjects: [BRCEventObject] = []
        BRCDatabaseManager.sharedInstance().readConnection.readWithBlock { (transaction: YapDatabaseReadTransaction) -> Void in
            if let object = self.relatedObject {
                eventObjects = object.eventsWithTransaction(transaction) as! [BRCEventObject]
            }
        }
        let options = BRCDataSorterOptions()
        options.showFutureEvents = true
        options.showExpiredEvents = true
        BRCDataSorter.sortDataObjects(eventObjects, options: options, completionQueue: dispatch_get_main_queue(), callbackBlock: { (events, art, camps) -> (Void) in
            self.processSortedData(events, art: art, camps: camps)
        })
    }
}
