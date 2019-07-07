//
//  PlayaKitTests.swift
//  PlayaKitTests
//
//  Created by Chris Ballinger on 4/3/19.
//

import XCTest
@testable import PlayaKit

class TestFixtures {
    
    private static let decoder = JSONDecoder()

    static func decodeObjects<T: Decodable>(resource: String) throws -> [T] {
        let testBundle = Bundle(for: TestFixtures.self)
        let jsonBundleURL = testBundle.url(forResource: "2019", withExtension: nil)!
        let jsonBundle = Bundle(url: jsonBundleURL)!
        let resourceURL = jsonBundle.url(forResource: resource, withExtension: "js")!
        let jsonData = try Data(contentsOf: resourceURL)
        let objects: [T] = try decoder.decode([T].self, from: jsonData)
        return objects
    }
}

class PlayaKitTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testArt() {
        do {
            let objects: [Art] = try TestFixtures.decodeObjects(resource: "art.json")
            XCTAssert(objects.count > 0)
        } catch {
            XCTFail("Failed \(error)")
        }
    }
    
    func testCamp() {
        do {
            let objects: [Camp] = try TestFixtures.decodeObjects(resource: "camps.json")
            XCTAssert(objects.count > 0)
        } catch {
            XCTFail("Failed \(error)")
        }
    }
    
    func testEvents() {
        do {
            let objects: [Event] = try TestFixtures.decodeObjects(resource: "events.json")
            XCTAssert(objects.count > 0)
        } catch {
            XCTFail("Failed \(error)")
        }
    }
}
