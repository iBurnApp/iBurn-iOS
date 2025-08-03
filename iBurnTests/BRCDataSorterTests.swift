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

class BRCDataSorterTests: XCTestCase {
    
    // MARK: - Properties
    private var databaseHelper: BRCTestDatabaseHelper!
    
    var database: YapDatabase! { databaseHelper.database }
    var connection: YapDatabaseConnection! { databaseHelper.connection }
    var importer: BRCDataImporter! { databaseHelper.importer }
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        databaseHelper = BRCTestDatabaseHelper()
        databaseHelper.setUp()
    }
    
    override func tearDown() {
        databaseHelper.tearDown()
        databaseHelper = nil
        super.tearDown()
    }
    
    // MARK: - Utility Methods
    
    func testDataURL(forDirectory directory: String) -> URL? {
        return databaseHelper.testDataURL(forDirectory: directory)
    }

    func testSortData() throws {
        let expectation = self.expectation(description: "sort data")
        
        let testDataURL = try XCTUnwrap(testDataURL(forDirectory: "initial_data"))
        importer.loadUpdates(from: testDataURL, fetchResultBlock: { (fetchResult: UIBackgroundFetchResult) -> Void in
            self.importer.waitForDataUpdatesToFinish()
            var dataObjects: [BRCDataObject] = []
            self.connection.read { transaction in
                transaction.allCollections()
                    .forEach {
                        let keys = transaction.allKeys(inCollection: $0)
                        transaction.enumerateObjects(forKeys: keys, inCollection: $0) { row, object, stop in
                            if let dataObject = object as? BRCDataObject {
                                dataObjects.append(dataObject)
                            }
                        }
                    }
            }
            NSLog("Found %d objects", dataObjects.count)
            XCTAssert(dataObjects.count > 0 , "Incorrect object count!")
            
            let dateFormatter = DateFormatter.brc_playaEventsAPI
            let options = BRCDataSorterOptions()
            let now = dateFormatter.date(from: "2025-08-27T12:30:00-07:00")!
            options.now = now
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
                
                let now = dateFormatter.date(from: "2025-08-24T12:00:00-07:00")!
                options.now = now
                options.showExpiredEvents = false
                options.showFutureEvents = false
                BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                    let filteredEventCount = events.count
                    NSLog("Found %d filtered events", filteredEventCount)
                    XCTAssert(filteredEventCount > 0 && eventCount > filteredEventCount, "Wrong filered count")
                    
                    let now = dateFormatter.date(from: "2025-08-25T15:00:00-07:00")!
                    options.now = now
                    options.showFutureEvents = true
                    BRCDataSorter.sortDataObjects(dataObjects, options: options, completionQueue: nil, callbackBlock: { (events, art, camps) -> (Void) in
                        let eventCount = events.count
                        NSLog("Found %d filtered events", eventCount)
                        XCTAssert(eventCount > 0, "Wrong filered count")
                        expectation.fulfill()
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
