//
//  DataViewModelTests.swift
//  iBurn
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import XCTest
@testable import iBurn

final class DataViewModelTests: XCTestCase {

    // MARK: locationDescription
    func testLocationDescription_empty() {
        let data = MockData()
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertNil(result)
    }
    
    func testLocationDescription_empty_event() {
        let data = MockEvent()
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "Location Unknown")
    }
    
    func testLocationDescription_empty_event_hasLocation() {
        let data = MockEvent(
            locationName: "The Spot"
        )
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "Other Location")
    }
    
    func testLocationDescription_empty_embargo() {
        let data = MockData()
        let embargo = MockEmbargo(canShowLocation: false)
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "Location Restricted")
    }
    
    func testLocationDescription_playaOnly() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E"
        )
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "8 o'clock and E")
    }
    
    func testLocationDescription_playaOnly_embargo() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E"
        )
        let embargo = MockEmbargo(canShowLocation: false)
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "Location Restricted")
    }
    
    func testLocationDescription_noShort() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place"
        )
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "8 o'clock and E")
    }
    
    func testLocationDescription_noShort_embargo() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place"
        )
        let embargo = MockEmbargo(canShowLocation: false)
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "BurnerMap: A very nice place")
    }
    
    func testLocationDescription_all() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place",
            burnerMapShortAddressDescription: "Nice place"
        )
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "8 o'clock and E")
    }
    
    func testLocationDescription_all_embargo() {
        let data = MockData(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place",
            burnerMapShortAddressDescription: "Nice place"
        )
        let embargo = MockEmbargo(canShowLocation: false)
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "BurnerMap: Nice place")
    }
    
    func testLocationDescription_all_event() {
        let data = MockEvent(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place",
            burnerMapShortAddressDescription: "Nice place"
        )
        let embargo = MockEmbargo()
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "8 o'clock and E")
    }
    
    func testLocationDescription_all_event_embargo() {
        let data = MockEvent(
            playaLocationDescription: "8 o'clock and E",
            burnerMapLocationDescription: "A very nice place",
            burnerMapShortAddressDescription: "Nice place"
        )
        let embargo = MockEmbargo(canShowLocation: false)
        let result = EventViewModel.locationDescription(for: data, embargo: embargo)
        XCTAssertEqual(result, "BurnerMap: Nice place")
    }
}
