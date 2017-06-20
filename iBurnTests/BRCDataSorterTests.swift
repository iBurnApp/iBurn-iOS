//
//  BRCDataSorterTests.swift
//  iBurn
//
//  Created by Christopher Ballinger on 8/11/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

import UIKit
import XCTest
import YapDatabase
@testable import iBurn

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
        expectation = expectation(description: "sort data")
        
        importer.loadUpdates(from: type(of: self).testDataURL(), fetchResultBlock: { (fetchResult: UIBackgroundFetchResult) -> Void in
            self.importer.waitForDataUpdatesToFinish()
            var dataObjects: [BRCDataObject] = []
            self.connection.read { (transaction: YapDatabaseReadTransaction) -> Void in
                transaction.enumerateKeysAndObjectsInAllCollections { (collection, key, object, stop) in
                    if let dataObject = object as? BRCDataObject {
                        dataObjects.append(dataObject)
                    }
                }
            }
            NSLog("Found %d objects", dataObjects.count)
            XCTAssert(dataObjects.count > 0 , "Incorrect object count!")
            
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
                XCTAssert(eventCount > 0, "Wrong event count")
                XCTAssert(campsCount > 0, "Wrong camp count")
                XCTAssert(artCount > 0, "Wrong art count")
                
                let dateFormatter = DateFormatter.brc_playaEventsAPI
                let now = dateFormatter.date(from: "2016-08-23T12:29:00-07:00")!
                options.now = now
                options.showExpiredEvents = false
                options.showFutureEvents = false
                BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                    let eventCount = events.count
                    NSLog("Found %d filtered events", eventCount)
                    XCTAssert(eventCount == 1, "Wrong filered count")
                    
                    let now = dateFormatter.date(from: "2016-08-22T12:29:00-07:00")!
                    options.now = now
                    options.showFutureEvents = true
                    BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                        let eventCount = events.count
                        NSLog("Found %d filtered events", eventCount)
                        XCTAssert(eventCount > 0, "Wrong filered count")
                        self.expectation.fulfill()
                    })
                })
            })
            
        })
        
        waitForExpectations(timeout: 30, handler: { error in
            if let error = error {
                debugPrint("Error sorting data \(error)")
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
