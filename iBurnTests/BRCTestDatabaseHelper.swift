//
//  BRCTestDatabaseHelper.swift
//  iBurnTests
//
//  Created by Claude Code on 8/3/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import XCTest
@testable import iBurn
import YapDatabase

/// Shared utility for setting up test databases and data importers
/// Used by multiple test classes that need YapDatabase and BRCDataImporter functionality
class BRCTestDatabaseHelper {
    
    // MARK: - Properties
    private(set) var database: YapDatabase!
    private(set) var connection: YapDatabaseConnection!
    private(set) var importer: BRCDataImporter!
    private let relationshipsName = "relationships"
    
    // MARK: - Setup & Teardown
    
    func setUp() {
        setupDatabase()
        setupDataImporter()
    }
    
    func tearDown() {
        cleanupDatabase()
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
        guard database != nil else {
            XCTFail("Failed to create YapDatabase")
            return
        }
        
        connection = database.newConnection()
        guard connection != nil else {
            XCTFail("Failed to create YapDatabaseConnection")
            return
        }
        
        // Register relationships extension
        let success = database.register(YapDatabaseRelationship(), withName: relationshipsName)
        guard success else {
            XCTFail("Failed to register relationships extension")
            return
        }
        print("Registered \(relationshipsName): \(success)")
    }
    
    private func setupDataImporter() {
        let sessionConfig = URLSessionConfiguration.ephemeral
        importer = BRCDataImporter(readWrite: connection, sessionConfiguration: sessionConfig)
        guard importer != nil else {
            XCTFail("Failed to create BRCDataImporter")
            return
        }
        
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
    
    func testDataURL(forDirectory directory: String) -> URL? {
        let bundle = TestBundleHelper.dataBundle()
        return bundle.url(forResource: "update", withExtension: "json", subdirectory: directory)
    }
}