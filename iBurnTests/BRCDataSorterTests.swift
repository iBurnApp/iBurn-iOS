//
//  BRCDataSorterTests.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/11/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import XCTest
import iBurn

class BRCDataSorterTests: BRCDataImportTests {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testSortData() {
        expectation = expectationWithDescription("sort data")
        
        importer.loadUpdatesFromURL(self.dynamicType.testDataURL(), fetchResultBlock: { (fetchResult: UIBackgroundFetchResult) -> Void in
            self.importer.waitForDataUpdatesToFinish()
            var dataObjects: [BRCDataObject] = []
            self.connection!.readWithBlock { (transaction: YapDatabaseReadTransaction) -> Void in
                transaction.enumerateKeysAndObjectsInAllCollectionsUsingBlock({ (collection: String, key: String, object: AnyObject, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    if let dataObject = object as? BRCDataObject {
                        dataObjects.append(dataObject)
                    }
                })
            }
            NSLog("Found %d objects", dataObjects.count)
            XCTAssert(dataObjects.count == 55, "Incorrect object count!")
            
            let options = BRCDataSorterOptions()
            options.showExpiredEvents = true
            options.showFutureEvents = true
            BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                let eventCount = events.count
                let artCount = art.count
                let campsCount = camps.count
                NSLog("Found %d events", eventCount)
                NSLog("Found %d art", artCount)
                NSLog("Found %d camps", campsCount)
                XCTAssert(eventCount == 40, "Wrong event count")
                XCTAssert(campsCount == 11, "Wrong camp count")
                XCTAssert(artCount == 4, "Wrong art count")
                
                let dateFormatter = NSDateFormatter.brc_playaEventsAPIDateFormatter()
                let now = dateFormatter.dateFromString("2015-09-04 12:59:00")!
                options.now = now
                options.showExpiredEvents = false
                options.showFutureEvents = false
                BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                    let eventCount = events.count
                    NSLog("Found %d filtered events", eventCount)
                    XCTAssert(eventCount == 1, "Wrong filered count")
                    
                    let now = dateFormatter.dateFromString("2015-09-02 14:25:00")!
                    options.now = now
                    options.showFutureEvents = true
                    BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                        let eventCount = events.count
                        NSLog("Found %d filtered events", eventCount)
                        XCTAssert(eventCount == 27, "Wrong filered count")
                        self.expectation!.fulfill()
                    })
                })
            })
            
        })
        
        waitForExpectationsWithTimeout(30, handler: { (error: NSError?) -> Void in
            if (error != nil) {
                NSLog("Error sorting data %@", error!)
            }
        })
    }

    /*
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }*/

}
