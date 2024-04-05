//
//  EventViewModelTests.swift
//  iBurnTests
//
//  Created by Brice Pollock on 4/5/24.
//  Copyright © 2024 iBurn. All rights reserved.
//

import XCTest
@testable import iBurn

final class EventViewModelTests: XCTestCase {  
    static let noEmbargo = MockEmbargo()
    func testInit() async throws {
        let data = MockEvent()
        let viewModel = try XCTUnwrap(EventViewModel(data: data, metadata: MockMetadata(), embargo: Self.noEmbargo))
        XCTAssertEqual(viewModel.timeDescription, "Wed 4:00PM (0m)")
        XCTAssertEqual(viewModel.statusColor, .green)
        XCTAssertEqual(viewModel.eventTypeDescription, "🔮 Ritual/Ceremony")
        XCTAssertNil(viewModel.hostName)
        XCTAssertNil(viewModel.locationDescription)
        
        await viewModel.appear()
        XCTAssertNil(viewModel.hostName)
        XCTAssertEqual(viewModel.locationDescription, "Location Unknown")
    }
    
    func testInit_locationName() async throws {
        let data = MockEvent(
            playaLocationDescription: "Event Location",
            locationName: "A fine place"
        )
        let viewModel = try XCTUnwrap(EventViewModel(data: data, metadata: MockMetadata(), embargo: Self.noEmbargo))
        XCTAssertNil(viewModel.hostName)
        XCTAssertNil(viewModel.locationDescription)
        
        await viewModel.appear()
        XCTAssertEqual(viewModel.hostName, "A fine place")
        XCTAssertEqual(viewModel.locationDescription, "Event Location")
    }
    
    func testInit_locationName_art() async throws {
        let data = MockEvent(
            playaLocationDescription: "Event Location",
            locationName: "A fine place",
            art: MockArt(
                playaLocationDescription: "Art Location",
                name: "Art"
            )
        )
        let viewModel = try XCTUnwrap(EventViewModel(data: data, metadata: MockMetadata(), embargo: Self.noEmbargo))
        XCTAssertNil(viewModel.hostName)
        XCTAssertNil(viewModel.locationDescription)
        
        await viewModel.appear()
        XCTAssertEqual(viewModel.hostName, "Art")
        XCTAssertEqual(viewModel.locationDescription, "Art Location")
    }
    
    func testInit_locationName_art_camp() async throws {
        let data = MockEvent(
            playaLocationDescription: "Event Location",
            locationName: "A fine place",
            camp: MockCamp(
                playaLocationDescription: "Camp Location",
                name: "Camp"
            ),
            art: MockArt(
                playaLocationDescription: "Art Location",
                name: "Art"
            )
        )
        let viewModel = try XCTUnwrap(EventViewModel(data: data, metadata: MockMetadata(), embargo: Self.noEmbargo))
        XCTAssertNil(viewModel.hostName)
        XCTAssertNil(viewModel.locationDescription)
        
        await viewModel.appear()
        XCTAssertEqual(viewModel.hostName, "Camp")
        XCTAssertEqual(viewModel.locationDescription, "Camp Location")
    }
    
    func testInit_notEvent() {
        let data = MockData()
        let viewModel = EventViewModel(data: data, metadata: MockMetadata(), embargo: Self.noEmbargo)
        XCTAssertNil(viewModel)
    }

    // MARK: timeDescription
    func testTimeDescription_isAllDay() {
        let event = MockEvent(
            isAllDay: true,
            start: Date(timeIntervalSince1970: 0),
            duration: 63*60,
            durationUntilStart: 2*60,
            isHappeningNow: true,
            isStartingSoon: true,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "Wed (All Day)")
    }
    
    func testTimeDescription_startSoon() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            duration: 63*60,
            durationUntilStart: 2*60,
            isHappeningNow: true,
            isStartingSoon: true,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "Starts 2m (1h 3m)")
    }
    
    func testTimeDescription_startSoon_now() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            duration: 63*60,
            durationUntilStart: 0,
            isHappeningNow: true,
            isStartingSoon: true,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "now!")
    }
    
    func testTimeDescription_now() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            durationUntilStart: 2*60,
            durationUntilEnd: 3*60,
            isHappeningNow: true,
            isStartingSoon: false,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "2m (3m left)")
    }
    
    func testTimeDescription_endedNow() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            durationUntilStart: 2*60,
            durationUntilEnd: 0,
            isHappeningNow: true,
            isStartingSoon: false,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "0 min")
    }
    
    func testTimeDescription_notSoon_started_ended() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            isHappeningNow: false,
            isStartingSoon: false,
            hasStarted: true,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "Wed 4:00PM (0m)")
    }
    
    func testTimeDescription_notSoon_notStarted_ended() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            isHappeningNow: false,
            isStartingSoon: false,
            hasStarted: false,
            hasEnded: true
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "Wed 4:00PM (0m)")
    }
    
    func testTimeDescription_notSoon_notStarted_notEnded() {
        let event = MockEvent(
            isAllDay: false,
            start: Date(timeIntervalSince1970: 0),
            isHappeningNow: false, 
            isStartingSoon: false,
            hasStarted: false,
            hasEnded: false
        )
        let result = EventViewModel.timeDescription(event: event)
        XCTAssertEqual(result, "Wed 4:00PM (0m)")
    }
    
    // MARK: defaultEventText
    func testDefaultDescription_startOnly() {
        let event = MockEvent(
            start: Date(timeIntervalSince1970: 5*60*60 + 2*60 + 25)
        )
        let result = EventViewModel.defaultEventText(event: event)
        XCTAssertEqual(result, "Wed 9:02PM (0m)")
    }
    
    func testDefaultDescription_start_duration_seconds() {
        let event = MockEvent(
            start: Date(timeIntervalSince1970: 5*60*60 + 2*60 + 25),
            duration: 45
        )
        let result = EventViewModel.defaultEventText(event: event)
        XCTAssertEqual(result, "Wed 9:02PM (0m)")
    }
    
    func testDefaultDescription_start_duration_minutes() {
        let event = MockEvent(
            start: Date(timeIntervalSince1970: 5*60*60 + 2*60 + 25),
            duration: 2*60 + 25
        )
        let result = EventViewModel.defaultEventText(event: event)
        XCTAssertEqual(result, "Wed 9:02PM (2m)")
    }
    
    func testDefaultDescription_start_duration_hours() {
        let event = MockEvent(
            start: Date(timeIntervalSince1970: 5*60*60 + 2*60 + 25),
            duration: 5*60*60 + 2*60 + 25
        )
        let result = EventViewModel.defaultEventText(event: event)
        XCTAssertEqual(result, "Wed 9:02PM (5h 2m)")
    }
}
