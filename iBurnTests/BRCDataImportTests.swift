//
//  BRCDataImportTests.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/23/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import XCTest
@testable import iBurn
import YapDatabase

@MainActor
class BRCDataImportTestsSwift: XCTestCase {
    
    // MARK: - Properties
    private var database: YapDatabase!
    private var connection: YapDatabaseConnection!
    private var importer: BRCDataImporter!
    private let relationshipsName = "relationships"
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupDatabase()
        setupDataImporter()
    }
    
    override func tearDown() {
        cleanupDatabase()
        super.tearDown()
    }
    
    private func setupDatabase() {
        // Create unique database name
        let dbName = UUID().uuidString + ".sqlite"
        let tmpDbPath = NSTemporaryDirectory().appending(dbName)
        
        // Remove existing file if present
        if FileManager.default.fileExists(atPath: tmpDbPath) {
            try? FileManager.default.removeItem(atPath: tmpDbPath)
        }
        
        // Create database
        let options = YapDatabaseOptions()
        options.corruptAction = .fail
        let dbURL = URL(fileURLWithPath: tmpDbPath)
        
        database = YapDatabase(url: dbURL, options: options)
        XCTAssertNotNil(database, "Failed to create YapDatabase")
        
        connection = database.newConnection()
        XCTAssertNotNil(connection, "Failed to create YapDatabaseConnection")
        
        // Register relationships extension
        let success = database.register(YapDatabaseRelationship(), withName: relationshipsName)
        XCTAssertTrue(success, "Failed to register relationships extension")
        print("Registered \(relationshipsName): \(success)")
    }
    
    private func setupDataImporter() {
        let sessionConfig = URLSessionConfiguration.ephemeral
        importer = BRCDataImporter(readWrite: connection, sessionConfiguration: sessionConfig)
        XCTAssertNotNil(importer, "Failed to create BRCDataImporter")
        
        importer.callbackQueue = DispatchQueue(label: "data.import.test.queue")
    }
    
    private func cleanupDatabase() {
        let dbURL = database?.databaseURL
        connection = nil
        importer = nil
        database = nil
        
        if let url = dbURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Utility Methods
    
    private func testDataURL(forDirectory directory: String) -> URL? {
        let bundle = TestBundleHelper.dataBundle()
        return bundle.url(forResource: "update", withExtension: "json", subdirectory: directory)
    }
    
    private func loadDataFromFile(_ fileName: String, dataClass: AnyClass) throws {
        // Create update info
        guard let updateInfo = BRCUpdateInfo() else {
            XCTFail("Failed to create BRCUpdateInfo")
            return
        }
        updateInfo.dataType = BRCUpdateInfo.dataType(for: dataClass)
        
        connection.readWrite { transaction in
            transaction.setObject(updateInfo, forKey: updateInfo.yapKey, inCollection: BRCUpdateInfo.yapCollection)
        }
        
        // Get test data URL
        let bundle = TestBundleHelper.dataBundle()
        guard let dataURL = bundle.url(forResource: fileName, withExtension: "json", subdirectory: "initial_data") else {
            XCTFail("Failed to find test data file: \(fileName).json")
            return
        }
        
        print("Loading data from: \(dataURL)")
        
        // Load JSON data
        let jsonData = try Data(contentsOf: dataURL)
        print("Loaded \(jsonData.count) bytes of JSON data")
        
        // Import data  
        let success = importer.loadDataFromJSONData(jsonData, dataClass: dataClass, updateInfo: updateInfo, error: nil)
        
        // Check success status instead of error
        if !success {
            XCTFail("Data import failed")
            return
        }
        
        // Verify data was loaded
        let collectionClass = (dataClass == BRCRecurringEventObject.self) ? BRCEventObject.self : dataClass
        
        connection.read { transaction in
            let collection = (collectionClass as! BRCYapDatabaseObject.Type).yapCollection
            let count = transaction.numberOfKeys(inCollection: collection)
            XCTAssertGreaterThan(count, 0, "No objects loaded for \(NSStringFromClass(dataClass))")
            print("Loaded \(count) \(NSStringFromClass(collectionClass)) objects")
        }
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadArt() throws {
        try loadDataFromFile("art", dataClass: BRCArtObject.self)
    }
    
    func testLoadCamps() throws {
        try loadDataFromFile("camp", dataClass: BRCCampObject.self)
    }
    
    func testLoadEvents() throws {
        try loadDataFromFile("event", dataClass: BRCRecurringEventObject.self)
        
        // Verify events have start/end dates
        connection.read { transaction in
            transaction.enumerateKeysAndObjectsInCollection(BRCEventObject.yapCollection, 
                                                       usingBlock: { (key: String, object: Any, stop: UnsafeMutablePointer<ObjCBool>) in
                if let event = object as? BRCEventObject {
                    XCTAssertNotNil(event.startDate, "Event \(key) missing start date")
                    XCTAssertNotNil(event.endDate, "Event \(key) missing end date")
                }
            })
        }
    }
    
    func testLoadPoints() throws {
        try loadDataFromFile("points", dataClass: BRCMapPoint.self)
        
        // Verify points have locations
        connection.read { transaction in
            let count = transaction.numberOfKeys(inCollection: BRCMapPoint.yapCollection)
            XCTAssertGreaterThan(count, 0, "No map points loaded")
            
            transaction.enumerateKeysAndObjectsInCollection(BRCMapPoint.yapCollection, 
                                                       usingBlock: { (key: String, object: Any, stop: UnsafeMutablePointer<ObjCBool>) in
                if let mapPoint = object as? BRCMapPoint {
                    XCTAssertNotNil(mapPoint.location, "Map point \(key) missing location")
                }
            })
        }
    }
    
    // MARK: - Update Tests
    
    func testLoadUpdates() async throws {
        guard let initialUpdateURL = testDataURL(forDirectory: "initial_data"),
              let updatedURL = testDataURL(forDirectory: "updated_data") else {
            XCTFail("Failed to get test data URLs")
            return
        }
        
        // First update - should get new data
        let firstResult = await loadUpdatesAsync(from: initialUpdateURL)
        XCTAssertEqual(firstResult, .newData, "First update should return new data")
        
        // Wait for update to finish
        await waitForUpdatesToFinish()
        
        // Second update with same URL - should get no data
        let secondResult = await loadUpdatesAsync(from: initialUpdateURL)
        XCTAssertEqual(secondResult, .noData, "Second update with same URL should return no data")
        
        // Wait for update to finish
        await waitForUpdatesToFinish()
        
        // Third update with different URL - should get new data
        let thirdResult = await loadUpdatesAsync(from: updatedURL)
        XCTAssertEqual(thirdResult, .newData, "Update with new URL should return new data")
        
        // Wait for update to finish
        await waitForUpdatesToFinish()
        
        // Fourth update with original URL - should get no data
        let fourthResult = await loadUpdatesAsync(from: initialUpdateURL)
        XCTAssertEqual(fourthResult, .noData, "Update with old URL should return no data")
    }
    
    func testUpdateData() async throws {
        guard let initialUpdateURL = testDataURL(forDirectory: "initial_data"),
              let updatedURL = testDataURL(forDirectory: "updated_data") else {
            XCTFail("Failed to get test data URLs")
            return
        }
        
        // First update - load initial data
        let firstResult = await loadUpdatesAsync(from: initialUpdateURL)
        XCTAssertEqual(firstResult, .newData, "First update should return new data")
        await waitForUpdatesToFinish()
        
        // Find and mark some objects as favorites
        var art1: BRCArtObject?
        var camp1: BRCCampObject?
        var events1: [BRCEventObject] = []
        
        connection.readWrite { transaction in
            // Find specific test objects
            art1 = transaction.object(forKey: "a2IVI000000yWeZ2AU", inCollection: BRCArtObject.yapCollection) as? BRCArtObject
            camp1 = transaction.object(forKey: "a1XVI000008yf262AA", inCollection: BRCCampObject.yapCollection) as? BRCCampObject
            
            // Mark art as favorite
            if let art = art1 {
                let artMetadata = art.artMetadata(with: transaction)
                artMetadata.isFavorite = true
                art.save(with: transaction, metadata: artMetadata)
            }
            
            // Mark camp as favorite
            if let camp = camp1 {
                if let campMetadata = camp.campMetadata(with: transaction) {
                    campMetadata.isFavorite = true
                    camp.save(with: transaction, metadata: campMetadata)
                }
                
                // Get camp events and mark them as favorites
                events1 = camp.events(with: transaction)
                for event in events1 {
                    let eventMetadata = event.eventMetadata(with: transaction)
                    eventMetadata.isFavorite = true
                    event.save(with: transaction, metadata: eventMetadata)
                }
            }
        }
        
        // Verify initial state
        XCTAssertNotNil(art1, "Art object should exist")
        XCTAssertNotNil(camp1, "Camp object should exist")
        XCTAssertNil(art1?.location, "Art should not have location initially")
        XCTAssertNil(camp1?.location, "Camp should not have location initially")
        XCTAssertGreaterThan(events1.count, 0, "Camp should have events")
        
        // Verify events don't have locations initially
        for event in events1 {
            XCTAssertNil(event.location, "Event should not have location initially")
        }
        
        print("Initial objects loaded and marked as favorites")
        
        // Second update - load updated data
        let secondResult = await loadUpdatesAsync(from: updatedURL)
        XCTAssertEqual(secondResult, .newData, "Second update should return new data")
        await waitForUpdatesToFinish()
        
        // Verify updated data preserves favorites but adds location
        var art2: BRCArtObject?
        var camp2: BRCCampObject?
        var events2: [BRCEventObject] = []
        
        connection.read { transaction in
            art2 = transaction.object(forKey: "a2IVI000000yWeZ2AU", inCollection: BRCArtObject.yapCollection) as? BRCArtObject
            camp2 = transaction.object(forKey: "a1XVI000008yf262AA", inCollection: BRCCampObject.yapCollection) as? BRCCampObject
            
            if let camp = camp2 {
                events2 = camp.events(with: transaction)
            }
        }
        
        // Verify updated objects exist and have locations
        XCTAssertNotNil(art2, "Updated art object should exist")
        XCTAssertNotNil(camp2, "Updated camp object should exist")
        XCTAssertNotNil(art2?.location, "Updated art should have location")
        XCTAssertNotNil(camp2?.location, "Updated camp should have location")
        
        // Verify favorite status is preserved
        connection.read { transaction in
            if let art = art2 {
                let artMetadata = art.artMetadata(with: transaction)
                XCTAssertTrue(artMetadata.isFavorite, "Art favorite status should be preserved")
            }
            
            if let camp = camp2, let campMetadata = camp.campMetadata(with: transaction) {
                XCTAssertTrue(campMetadata.isFavorite, "Camp favorite status should be preserved")
            }
        }
        
        // Verify events have locations and preserve favorites
        XCTAssertGreaterThan(events2.count, 0, "Updated camp should have events")
        for event in events2 {
            XCTAssertNotNil(event.location, "Updated event should have location")
        }
        
        print("Updated objects verified with locations and preserved favorites")
    }
    
    // MARK: - Async Helper Methods
    
    private func loadUpdatesAsync(from url: URL) async -> UIBackgroundFetchResult {
        return await withCheckedContinuation { continuation in
            importer.loadUpdates(from: url) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    private func waitForUpdatesToFinish() async {
        // Since BRCDataImporter doesn't expose isUpdating, we'll use a different approach
        // Call the waitForDataUpdatesToFinish method and add additional delay
        importer.waitForDataUpdatesToFinish()
        
        // Add additional delay to ensure all operations complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
