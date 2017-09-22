//
//  PlayaKitTests.swift
//  PlayaKitTests
//
//  Created by Chris Ballinger on 9/21/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import XCTest
import YapDatabase
@testable import PlayaKit

class CodableTest: NSObject, Codable {
    let name: String = "name"
    let test: String = "test"
}

class PlayaKitTests: XCTestCase {
    
    
    var database: YapDatabase!
    var connection: YapDatabaseConnection!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let dbPath = "\(NSTemporaryDirectory())/\(UUID().uuidString)"
        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()
        self.database = YapDatabase(path: dbPath, serializer: { (collection, key, object) -> Data in
            if let encodableObject = object as? YapObject {
                var data: Data? = nil
                do {
                    data = try encoder.encode(encodableObject)
                } catch let err {
                    fatalError("Could not encode object \(object) \(err)")
                }
                if let data = data {
                    return data
                }
            }
            fatalError("Could not encode object \(object)")
        }, deserializer: { (collection, key, data) -> Any? in
            var object: Any? = nil
            do {
                object = try decoder.decode(YapObject.self, from: data)
            } catch let err {
                fatalError("Could not decode object \(err)")
            }
            return object
        })
        self.connection = database.newConnection()
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // Verify that default collections are unique
    func testObjectCreation() {
        let art = ArtObject(name: "art")
        let camp = CampObject(name: "camp")
        let event = EventObject(name: "event")
        let objects: [APIObject] = [art, camp, event]
        for object in objects {
            XCTAssertEqual(object.yapCollection, type(of: object).defaultYapCollection)
            XCTAssertEqual(object.yapCollection, object.yapStorage.collection)
        }
        XCTAssertNotEqual(art.yapCollection, camp.yapCollection)
        XCTAssertNotEqual(art.yapCollection, event.yapCollection)
        XCTAssertNotEqual(camp.yapCollection, event.yapCollection)
    }
    
    func testObjectSaving() {
        let art = ArtObject(name: "art")
        let camp = CampObject(name: "camp")
        let event = EventObject(name: "event")
        let objects: [APIObject] = [art, camp, event]
        
        connection.readWrite { transaction in
            art.save(transaction, metadata: nil)
            if let refetch = art.refetch(transaction) {
                XCTAssertNotNil(refetch)
            }
            
            for object in objects {
                object.save(transaction, metadata: nil)
                let refetch = object.refetch(transaction)
                XCTAssertNotNil(refetch)
            }
            
            if let refetch = art.refetch(transaction) {
                XCTAssertNotNil(refetch)
            }
        }
    }
    
}
