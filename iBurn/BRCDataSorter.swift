//
//  BRCDataSorter.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/11/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit

public class BRCDataSorterOptions {
    public var showExpiredEvents: Bool
    public var showFutureEvents: Bool
    /** Default true. Puts expired events at bottom. */
    public var sortEventsWithExpiration: Bool
    public var now: NSDate
    public init () {
        showExpiredEvents = false
        showFutureEvents = false
        sortEventsWithExpiration = true
        now = NSDate()
    }
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
            let queue = completionQueue ?? dispatch_get_main_queue()
            let opt = options ?? BRCDataSorterOptions()
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), { () -> Void in
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
                if !opt.showExpiredEvents {
                    events = events.filter { !$0.hasEnded(opt.now) }
                }
                if !opt.showFutureEvents {
                    events = events.filter { $0.isStartingSoon(opt.now) }
                }
                if opt.sortEventsWithExpiration {
                    var expiredEvents = events.filter { $0.hasEnded(opt.now) }
                    var nonExpired = events.filter { !$0.hasEnded(opt.now) }
                    expiredEvents.sortInPlace {
                        $0.startDate.timeIntervalSinceNow < $1.startDate.timeIntervalSinceNow
                    }
                    nonExpired.sortInPlace {
                        $0.startDate.timeIntervalSinceNow < $1.startDate.timeIntervalSinceNow
                    }
                    events = nonExpired + expiredEvents
                } else {
                    events.sortInPlace {
                        $0.startDate.timeIntervalSinceNow < $1.startDate.timeIntervalSinceNow
                    }
                }
                camps.sortInPlace { $0.title < $1.title }
                art.sortInPlace { $0.title < $1.title }
                dispatch_async(queue!, { () -> Void in
                    callbackBlock(events: events, art: art, camps: camps)
                })
            });
            
    }
}
