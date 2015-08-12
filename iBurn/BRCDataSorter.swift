//
//  BRCDataSorter.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/11/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit

public class BRCDataSorterOptions {
    public init () {
        showExpiredEvents = false
        showFutureEvents = false
    }
    var showExpiredEvents: Bool
    var showFutureEvents: Bool
}

/**
 * For "smart sorting" big arrays of BRCDataObjects into events, art, and camps.
 * Used by Nearby and Favorites screen.
 */
public class BRCDataSorter: NSObject {
    public static func sortDataObjects(
        objects: [BRCDataObject],
        options: BRCDataSorterOptions?,
        completionQueue: dispatch_queue_t?,
        callbackBlock: (events: [BRCEventObject],
        art: [BRCArtObject], camps: [BRCCampObject]) -> (Void)) {
            var events: [BRCEventObject] = []
            var art: [BRCArtObject] = []
            var camps: [BRCCampObject] = []
            for object in objects {
                if let event = object as? BRCEventObject {
                    events.append(event)
                }
                if let artObject = object as? BRCArtObject {
                    art.append(artObject)
                }
                if let camp = object as? BRCCampObject {
                    camps.append(camp)
                }
            }
            
            callbackBlock(events: events, art: art, camps: camps)
    }
}
