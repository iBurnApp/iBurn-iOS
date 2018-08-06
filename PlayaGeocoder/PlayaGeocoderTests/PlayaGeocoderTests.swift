//
//  PlayaGeocoderTests.swift
//  PlayaGeocoderTests
//
//  Created by Chris Ballinger on 8/5/18.
//

import XCTest
import CoreLocation
@testable import PlayaGeocoder

class PlayaGeocoderTests: XCTestCase {
    
    var geocoder: PlayaGeocoder!
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        geocoder = PlayaGeocoder()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testReverseGeocoder() {
        let coordinate = CLLocationCoordinate2D(latitude: 40.7901, longitude: -119.2199)
        let address = geocoder.syncReverseLookup(coordinate)
        XCTAssertNotNil(address)
    }
    
    func testForwardGeocoder() {
        let address1 = "6:15 & A"
        let location1 = geocoder.syncForwardLookup(address1)
        XCTAssert(CLLocationCoordinate2DIsValid(location1))
        let address2 = "A & 6:15"
        let location2 = geocoder.syncForwardLookup(address2)
        XCTAssert(CLLocationCoordinate2DIsValid(location2))
        XCTAssertEqual(location1.latitude, location2.latitude)
        XCTAssertEqual(location1.longitude, location2.longitude)
        
        let address3 = "Center Camp Plaza @ 7:30"
        let location3 = geocoder.syncForwardLookup(address3)
        XCTAssert(CLLocationCoordinate2DIsValid(location3))
    }
}
