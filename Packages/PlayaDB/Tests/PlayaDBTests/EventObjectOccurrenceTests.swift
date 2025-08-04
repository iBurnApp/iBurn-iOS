import XCTest
import Foundation
import CoreLocation
@testable import PlayaDB

class EventObjectOccurrenceTests: XCTestCase {
    
    func testEventObjectOccurrenceCreation() {
        // Given: An EventObject and EventOccurrence
        let event = EventObject(
            uid: "test-event-123",
            name: "Test Event",
            year: 2025,
            eventId: 456,
            description: "A test event",
            eventTypeLabel: "Workshop",
            eventTypeCode: "workshop",
            printDescription: "Test workshop event",
            slug: "test-event",
            hostedByCamp: "camp-123",
            locatedAtArt: nil,
            otherLocation: "",
            checkLocation: false,
            url: URL(string: "https://example.com"),
            allDay: false,
            contact: "test@example.com",
            gpsLatitude: 40.7862,
            gpsLongitude: -119.2065
        )
        
        let now = Date()
        let occurrence = EventOccurrence(
            id: 1,
            eventId: "test-event-123",
            startTime: now,
            endTime: now.addingTimeInterval(3600) // 1 hour later
        )
        
        // When: Creating an EventObjectOccurrence
        let eventObjectOccurrence = EventObjectOccurrence(event: event, occurrence: occurrence)
        
        // Then: Properties should be correctly delegated
        XCTAssertEqual(eventObjectOccurrence.uid, "test-event-123_1")
        XCTAssertEqual(eventObjectOccurrence.name, "Test Event")
        XCTAssertEqual(eventObjectOccurrence.year, 2025)
        XCTAssertEqual(eventObjectOccurrence.description, "A test event")
        XCTAssertEqual(eventObjectOccurrence.eventTypeLabel, "Workshop")
        XCTAssertEqual(eventObjectOccurrence.eventTypeCode, "workshop")
        XCTAssertEqual(eventObjectOccurrence.startDate, now)
        XCTAssertEqual(eventObjectOccurrence.endDate, now.addingTimeInterval(3600))
        XCTAssertEqual(eventObjectOccurrence.objectType, .event)
        XCTAssertTrue(eventObjectOccurrence.hasLocation)
        XCTAssertTrue(eventObjectOccurrence.isHostedByCamp)
        XCTAssertFalse(eventObjectOccurrence.isLocatedAtArt)
    }
    
    func testEventObjectOccurrenceTimingMethods() {
        // Given: An event that starts in 30 minutes and runs for 2 hours
        let now = Date()
        let startTime = now.addingTimeInterval(30 * 60) // 30 minutes from now
        let endTime = startTime.addingTimeInterval(2 * 3600) // 2 hours duration
        
        let event = EventObject(
            uid: "timing-test",
            name: "Timing Test Event",
            year: 2025,
            eventTypeLabel: "Test",
            eventTypeCode: "test"
        )
        
        let occurrence = EventOccurrence(
            id: 2,
            eventId: "timing-test",
            startTime: startTime,
            endTime: endTime
        )
        
        let eventObjectOccurrence = EventObjectOccurrence(event: event, occurrence: occurrence)
        
        // Then: Timing methods should work correctly
        XCTAssertTrue(eventObjectOccurrence.isFuture(now))
        XCTAssertFalse(eventObjectOccurrence.isCurrentlyHappening(now))
        XCTAssertFalse(eventObjectOccurrence.hasEnded(now))
        XCTAssertTrue(eventObjectOccurrence.isStartingSoon(now))
        XCTAssertEqual(eventObjectOccurrence.duration, 2 * 3600) // 2 hours
        XCTAssertEqual(eventObjectOccurrence.durationString, "2h")
        XCTAssertFalse(eventObjectOccurrence.isShortEvent)
        XCTAssertFalse(eventObjectOccurrence.isLongEvent)
    }
    
    func testEventObjectOccurrenceCurrentlyHappening() {
        // Given: An event that started 30 minutes ago and ends in 10 minutes (ending soon)
        let now = Date()
        let startTime = now.addingTimeInterval(-30 * 60) // 30 minutes ago
        let endTime = now.addingTimeInterval(10 * 60) // 10 minutes from now
        
        let event = EventObject(
            uid: "current-test",
            name: "Current Test Event",
            year: 2025,
            eventTypeLabel: "Test",
            eventTypeCode: "test"
        )
        
        let occurrence = EventOccurrence(
            id: 3,
            eventId: "current-test",
            startTime: startTime,
            endTime: endTime
        )
        
        let eventObjectOccurrence = EventObjectOccurrence(event: event, occurrence: occurrence)
        
        // Then: Should be currently happening
        XCTAssertFalse(eventObjectOccurrence.isFuture(now))
        XCTAssertTrue(eventObjectOccurrence.isCurrentlyHappening(now))
        XCTAssertFalse(eventObjectOccurrence.hasEnded(now))
        XCTAssertFalse(eventObjectOccurrence.isStartingSoon(now))
        XCTAssertTrue(eventObjectOccurrence.isEndingSoon(now))
    }
    
    func testEventObjectOccurrenceLocationHandling() {
        // Given: An event with GPS coordinates
        let event = EventObject(
            uid: "location-test",
            name: "Location Test Event",
            year: 2025,
            eventTypeLabel: "Test",
            eventTypeCode: "test",
            gpsLatitude: 40.7862, // Black Rock City coordinates
            gpsLongitude: -119.2065
        )
        
        let occurrence = EventOccurrence(
            id: 4,
            eventId: "location-test",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
        
        let eventObjectOccurrence = EventObjectOccurrence(event: event, occurrence: occurrence)
        
        // Then: Location properties should work
        XCTAssertTrue(eventObjectOccurrence.hasLocation)
        XCTAssertTrue(eventObjectOccurrence.hasGPSLocation)
        XCTAssertNotNil(eventObjectOccurrence.location)
        XCTAssertEqual(eventObjectOccurrence.gpsLatitude, 40.7862)
        XCTAssertEqual(eventObjectOccurrence.gpsLongitude, -119.2065)
        
        if let location = eventObjectOccurrence.location {
            XCTAssertEqual(location.coordinate.latitude, 40.7862, accuracy: 0.0001)
            XCTAssertEqual(location.coordinate.longitude, -119.2065, accuracy: 0.0001)
        }
    }
    
    func testEventObjectOccurrenceCompatibilityMethods() {
        // Given: An event occurrence
        let now = Date()
        let event = EventObject(
            uid: "compat-test",
            name: "Compatibility Test",
            year: 2025,
            eventTypeLabel: "Test",
            eventTypeCode: "test"
        )
        
        let occurrence = EventOccurrence(
            id: 5,
            eventId: "compat-test",
            startTime: now,
            endTime: now.addingTimeInterval(2 * 3600) // 2 hours
        )
        
        let eventObjectOccurrence = EventObjectOccurrence(event: event, occurrence: occurrence)
        
        // Then: Compatibility methods should work
        XCTAssertEqual(eventObjectOccurrence.timeIntervalForDuration(), 2 * 3600)
        XCTAssertTrue(eventObjectOccurrence.isHappeningRightNow(now))
        XCTAssertFalse(eventObjectOccurrence.startAndEndString.isEmpty)
        XCTAssertFalse(eventObjectOccurrence.startWeekdayString.isEmpty)
        
        // Test shouldShowOnMap logic
        let futureEvent = EventObjectOccurrence(
            event: event,
            occurrence: EventOccurrence(
                id: 6,
                eventId: "compat-test",
                startTime: now.addingTimeInterval(10 * 60), // 10 minutes from now
                endTime: now.addingTimeInterval(70 * 60) // 70 minutes from now
            )
        )
        XCTAssertTrue(futureEvent.shouldShowOnMap(now)) // Starting soon
    }
}