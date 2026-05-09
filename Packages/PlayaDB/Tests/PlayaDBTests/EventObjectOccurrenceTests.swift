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
    
    // MARK: - Host Pre-loading

    private func makeEvent(
        uid: String = "host-test-event",
        hostedByCamp: String? = nil,
        locatedAtArt: String? = nil
    ) -> EventObject {
        EventObject(
            uid: uid,
            name: "Host Test Event",
            year: 2025,
            eventTypeLabel: "Workshop",
            eventTypeCode: "workshop",
            hostedByCamp: hostedByCamp,
            locatedAtArt: locatedAtArt
        )
    }

    private func makeOccurrence(eventUID: String, id: Int64 = 1) -> EventOccurrence {
        let now = Date()
        return EventOccurrence(
            id: id,
            eventId: eventUID,
            startTime: now,
            endTime: now.addingTimeInterval(3600)
        )
    }

    func testEventObjectOccurrence_HostNameAndAddress_FromCampHost() throws {
        // Given: a camp host with a locationString
        let camp = CampObject(
            uid: "camp-uid-1",
            name: "Camp Foo",
            year: 2025,
            locationString: "7:30 & E",
            intersection: "Esplanade & 6:00"
        )
        let event = makeEvent(hostedByCamp: camp.uid)
        let occurrence = makeOccurrence(eventUID: event.uid)

        // When: occurrence is constructed with the camp as host
        let occ = EventObjectOccurrence(event: event, occurrence: occurrence, host: camp)

        // Then: host name + address delegate to the camp
        let hostName = try XCTUnwrap(occ.hostName)
        let hostAddress = try XCTUnwrap(occ.hostAddress)
        XCTAssertEqual(hostName, "Camp Foo")
        XCTAssertEqual(hostAddress, "7:30 & E")
    }

    func testEventObjectOccurrence_HostNameAndAddress_FromArtHost() throws {
        // Given: an art host with no locationString (falls back to timeBasedAddress)
        let art = ArtObject(
            uid: "art-uid-1",
            name: "Big Art",
            year: 2025,
            locationString: nil,
            locationHour: 9,
            locationMinute: 30,
            locationDistance: 1200
        )
        let event = makeEvent(locatedAtArt: art.uid)
        let occurrence = makeOccurrence(eventUID: event.uid)

        let occ = EventObjectOccurrence(event: event, occurrence: occurrence, host: art)

        let hostName = try XCTUnwrap(occ.hostName)
        let hostAddress = try XCTUnwrap(occ.hostAddress)
        XCTAssertEqual(hostName, "Big Art")
        XCTAssertEqual(hostAddress, "9:30 & 1200'")
    }

    func testEventObjectOccurrence_HostNameAndAddress_NilWhenNoHost() {
        // Given: no host argument (default nil)
        let event = makeEvent()
        let occurrence = makeOccurrence(eventUID: event.uid)

        let occ = EventObjectOccurrence(event: event, occurrence: occurrence)

        XCTAssertNil(occ.hostName)
        XCTAssertNil(occ.hostAddress)
        XCTAssertNil(occ.host)
    }

    func testEventOccurrenceJoinedRow_PrefersCampOverArt() throws {
        // Given: a joined row with both hostedCamp and locatedArt set
        let camp = CampObject(uid: "c1", name: "Camp", year: 2025, locationString: "Camp Loc")
        let art = ArtObject(uid: "a1", name: "Art", year: 2025, locationString: "Art Loc")
        let event = makeEvent(uid: "ev1", hostedByCamp: camp.uid, locatedAtArt: art.uid)
        let occurrence = makeOccurrence(eventUID: event.uid)

        let row = EventOccurrenceJoinedRow(
            occurrence: occurrence,
            event: event,
            hostedCamp: camp,
            locatedArt: art
        )

        // When: convert to EventObjectOccurrence
        let occ = row.toEventObjectOccurrence()

        // Then: camp wins (hostedCamp ?? locatedArt)
        let host = try XCTUnwrap(occ.host)
        XCTAssertEqual(host.uid, camp.uid)
        XCTAssertEqual(occ.hostName, "Camp")
        XCTAssertEqual(occ.hostAddress, "Camp Loc")
    }

    func testEventOccurrenceJoinedRow_FallsBackToArt() throws {
        let art = ArtObject(uid: "a2", name: "Art Only", year: 2025, locationString: "Deep Playa")
        let event = makeEvent(uid: "ev2", locatedAtArt: art.uid)
        let occurrence = makeOccurrence(eventUID: event.uid)

        let row = EventOccurrenceJoinedRow(
            occurrence: occurrence,
            event: event,
            hostedCamp: nil,
            locatedArt: art
        )

        let occ = row.toEventObjectOccurrence()
        let host = try XCTUnwrap(occ.host)
        XCTAssertEqual(host.uid, art.uid)
        XCTAssertEqual(occ.hostName, "Art Only")
        XCTAssertEqual(occ.hostAddress, "Deep Playa")
    }

    func testEventOccurrenceJoinedRow_NilWhenNeither() {
        let event = makeEvent(uid: "ev3")
        let occurrence = makeOccurrence(eventUID: event.uid)

        let row = EventOccurrenceJoinedRow(
            occurrence: occurrence,
            event: event,
            hostedCamp: nil,
            locatedArt: nil
        )

        let occ = row.toEventObjectOccurrence()
        XCTAssertNil(occ.host)
        XCTAssertNil(occ.hostName)
        XCTAssertNil(occ.hostAddress)
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