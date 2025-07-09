import XCTest
import Foundation
import CoreLocation
@testable import PlayaDB
@testable import PlayaAPI

final class PlayaDBImportTests: XCTestCase {
    var playaDB: PlayaDB!
    var tempDBPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use in-memory database for testing
        tempDBPath = ":memory:"
        
        // Create PlayaDB instance with in-memory database
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
    }
    
    override func tearDown() async throws {
        playaDB = nil
        
        // No cleanup needed for in-memory database
        
        try await super.tearDown()
    }
    
    // MARK: - Art Object Import Tests
    
    func testArtObjectImport() async throws {
        // Given: Load art objects from PlayaAPI
        let artService = ArtService()
        let expectedArtObjects = try artService.loadArt()
        
        // When: Import data into PlayaDB
        try await playaDB.importFromPlayaAPI()
        
        // Then: Verify we can fetch the same number of art objects
        let fetchedArtObjects = try await playaDB.fetchArt()
        
        XCTAssertEqual(fetchedArtObjects.count, expectedArtObjects.count, 
                      "Should fetch same number of art objects as imported")
        
        // Verify specific art object properties
        guard let firstExpected = expectedArtObjects.first,
              let firstFetched = fetchedArtObjects.first(where: { $0.uid == firstExpected.uid.rawValue }) else {
            XCTFail("Could not find matching art objects")
            return
        }
        
        XCTAssertEqual(firstFetched.name, firstExpected.name)
        XCTAssertEqual(firstFetched.year, firstExpected.year)
        XCTAssertEqual(firstFetched.artist, firstExpected.artist)
        XCTAssertEqual(firstFetched.description, firstExpected.description)
        XCTAssertEqual(firstFetched.url, firstExpected.url)
        XCTAssertEqual(firstFetched.contactEmail, firstExpected.contactEmail)
        XCTAssertEqual(firstFetched.hometown, firstExpected.hometown)
        XCTAssertEqual(firstFetched.category, firstExpected.category)
        XCTAssertEqual(firstFetched.program, firstExpected.program)
        XCTAssertEqual(firstFetched.donationLink, firstExpected.donationLink)
        XCTAssertEqual(firstFetched.locationString, firstExpected.locationString)
        XCTAssertEqual(firstFetched.guidedTours, firstExpected.guidedTours)
        XCTAssertEqual(firstFetched.selfGuidedTourMap, firstExpected.selfGuidedTourMap)
        
        // Verify location data
        if let expectedLocation = firstExpected.location {
            XCTAssertEqual(firstFetched.locationHour, expectedLocation.hour)
            XCTAssertEqual(firstFetched.locationMinute, expectedLocation.minute)
            XCTAssertEqual(firstFetched.locationDistance, expectedLocation.distance)
            XCTAssertEqual(firstFetched.locationCategory, expectedLocation.category)
            XCTAssertEqual(firstFetched.gpsLatitude, expectedLocation.gpsLatitude)
            XCTAssertEqual(firstFetched.gpsLongitude, expectedLocation.gpsLongitude)
        }
    }
    
    func testArtObjectWithGPSLocation() async throws {
        // Given: Import art objects
        try await playaDB.importFromPlayaAPI()
        
        // When: Fetch art objects with GPS coordinates
        let artObjects = try await playaDB.fetchArt()
        let artWithGPS = artObjects.filter { $0.hasGPSLocation }
        
        // Then: Verify GPS coordinates are properly stored
        XCTAssertGreaterThan(artWithGPS.count, 0, "Should have at least some art objects with GPS coordinates")
        
        for artObject in artWithGPS.prefix(5) { // Test first 5 objects with GPS
            XCTAssertNotNil(artObject.gpsLatitude, "GPS latitude should not be nil")
            XCTAssertNotNil(artObject.gpsLongitude, "GPS longitude should not be nil")
            XCTAssertNotNil(artObject.location, "CLLocation should not be nil")
            XCTAssertTrue(artObject.hasLocation, "hasLocation should be true")
        }
    }
    
    // MARK: - Camp Object Import Tests
    
    func testCampObjectImport() async throws {
        // Given: Load camp objects from PlayaAPI
        let campService = CampService()
        let expectedCampObjects = try campService.loadCamps()
        
        // When: Import data into PlayaDB
        try await playaDB.importFromPlayaAPI()
        
        // Then: Verify we can fetch the same number of camp objects
        let fetchedCampObjects = try await playaDB.fetchCamps()
        
        XCTAssertEqual(fetchedCampObjects.count, expectedCampObjects.count, 
                      "Should fetch same number of camp objects as imported")
        
        // Verify specific camp object properties
        guard let firstExpected = expectedCampObjects.first,
              let firstFetched = fetchedCampObjects.first(where: { $0.uid == firstExpected.uid.rawValue }) else {
            XCTFail("Could not find matching camp objects")
            return
        }
        
        XCTAssertEqual(firstFetched.name, firstExpected.name)
        XCTAssertEqual(firstFetched.year, firstExpected.year)
        XCTAssertEqual(firstFetched.description, firstExpected.description)
        XCTAssertEqual(firstFetched.url, firstExpected.url)
        XCTAssertEqual(firstFetched.contactEmail, firstExpected.contactEmail)
        XCTAssertEqual(firstFetched.hometown, firstExpected.hometown)
        XCTAssertEqual(firstFetched.landmark, firstExpected.landmark)
        XCTAssertEqual(firstFetched.locationString, firstExpected.locationString)
        
        // Verify location data
        if let expectedLocation = firstExpected.location {
            XCTAssertEqual(firstFetched.locationLocationString, expectedLocation.string)
            XCTAssertEqual(firstFetched.frontage, expectedLocation.frontage)
            XCTAssertEqual(firstFetched.intersection, expectedLocation.intersection)
            XCTAssertEqual(firstFetched.intersectionType, expectedLocation.intersectionType)
            XCTAssertEqual(firstFetched.dimensions, expectedLocation.dimensions)
            XCTAssertEqual(firstFetched.exactLocation, expectedLocation.exactLocation)
            XCTAssertEqual(firstFetched.gpsLatitude, expectedLocation.gpsLatitude)
            XCTAssertEqual(firstFetched.gpsLongitude, expectedLocation.gpsLongitude)
        }
    }
    
    func testCampObjectWithGPSLocation() async throws {
        // Given: Import camp objects
        try await playaDB.importFromPlayaAPI()
        
        // When: Fetch camp objects with GPS coordinates
        let campObjects = try await playaDB.fetchCamps()
        let campsWithGPS = campObjects.filter { $0.hasGPSLocation }
        
        // Then: Verify GPS coordinates are properly stored
        XCTAssertGreaterThan(campsWithGPS.count, 0, "Should have at least some camp objects with GPS coordinates")
        
        for campObject in campsWithGPS.prefix(5) { // Test first 5 objects with GPS
            XCTAssertNotNil(campObject.gpsLatitude, "GPS latitude should not be nil")
            XCTAssertNotNil(campObject.gpsLongitude, "GPS longitude should not be nil")
            XCTAssertNotNil(campObject.location, "CLLocation should not be nil")
            XCTAssertTrue(campObject.hasLocation, "hasLocation should be true")
        }
    }
    
    // MARK: - Event Object Import Tests
    
    func testEventObjectImport() async throws {
        // Given: Load event objects from PlayaAPI
        let eventService = EventService()
        let expectedEventObjects = try eventService.loadEvents()
        
        // When: Import data into PlayaDB
        try await playaDB.importFromPlayaAPI()
        
        // Then: Verify we can fetch the same number of event objects
        let fetchedEventObjects = try await playaDB.fetchEvents()
        
        XCTAssertEqual(fetchedEventObjects.count, expectedEventObjects.count, 
                      "Should fetch same number of event objects as imported")
        
        // Verify specific event object properties
        guard let firstExpected = expectedEventObjects.first,
              let firstFetched = fetchedEventObjects.first(where: { $0.uid == firstExpected.uid.rawValue }) else {
            XCTFail("Could not find matching event objects")
            return
        }
        
        XCTAssertEqual(firstFetched.name, firstExpected.title)
        XCTAssertEqual(firstFetched.year, firstExpected.year)
        XCTAssertEqual(firstFetched.eventId, firstExpected.eventId)
        XCTAssertEqual(firstFetched.description, firstExpected.description)
        XCTAssertEqual(firstFetched.eventTypeLabel, firstExpected.eventType.label)
        XCTAssertEqual(firstFetched.eventTypeCode, firstExpected.eventType.type.rawValue)
        XCTAssertEqual(firstFetched.printDescription, firstExpected.printDescription)
        XCTAssertEqual(firstFetched.slug, firstExpected.slug)
        XCTAssertEqual(firstFetched.hostedByCamp, firstExpected.hostedByCamp?.rawValue)
        XCTAssertEqual(firstFetched.locatedAtArt, firstExpected.locatedAtArt?.rawValue)
        XCTAssertEqual(firstFetched.otherLocation, firstExpected.otherLocation)
        XCTAssertEqual(firstFetched.checkLocation, firstExpected.checkLocation)
        XCTAssertEqual(firstFetched.url, firstExpected.url)
        XCTAssertEqual(firstFetched.allDay, firstExpected.allDay)
        XCTAssertEqual(firstFetched.contact, firstExpected.contact)
    }
    
    func testEventObjectLocationResolution() async throws {
        // Given: Import all data (art, camps, events)
        try await playaDB.importFromPlayaAPI()
        
        // When: Fetch events with GPS coordinates
        let eventObjects = try await playaDB.fetchEvents()
        let eventsWithGPS = eventObjects.filter { $0.hasGPSLocation }
        
        // Then: Verify GPS coordinates were copied from host locations
        XCTAssertGreaterThan(eventsWithGPS.count, 0, "Should have at least some events with GPS coordinates")
        
        for eventObject in eventsWithGPS.prefix(5) { // Test first 5 objects with GPS
            XCTAssertNotNil(eventObject.gpsLatitude, "GPS latitude should not be nil")
            XCTAssertNotNil(eventObject.gpsLongitude, "GPS longitude should not be nil")
            XCTAssertNotNil(eventObject.location, "CLLocation should not be nil")
            XCTAssertTrue(eventObject.hasLocation, "hasLocation should be true")
            
            // Verify that the event has either a host camp or art location
            let hasHostLocation = eventObject.hostedByCamp != nil || eventObject.locatedAtArt != nil
            XCTAssertTrue(hasHostLocation, "Event with GPS coordinates should have a host camp or art location")
        }
    }
    
    // MARK: - Event Occurrences Import Tests
    
    func testEventOccurrencesImport() async throws {
        // Given: Load event objects from PlayaAPI
        let eventService = EventService()
        let expectedEventObjects = try eventService.loadEvents()
        let totalExpectedOccurrences = expectedEventObjects.reduce(0) { $0 + $1.occurrenceSet.count }
        
        // When: Import data into PlayaDB
        try await playaDB.importFromPlayaAPI()
        
        // Then: Verify event occurrences were imported
        // Note: We need to access the database directly to count occurrences
        let playaDBImpl = playaDB as! PlayaDBImpl
        let occurrenceCount = try await playaDBImpl.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrences") ?? 0
        }
        
        XCTAssertEqual(occurrenceCount, totalExpectedOccurrences, 
                      "Should import all event occurrences")
        
        // Verify that occurrences are properly linked to events
        let eventObjects = try await playaDB.fetchEvents()
        let eventWithOccurrences = eventObjects.first { !expectedEventObjects.first { $0.uid.rawValue == $1.uid }?.occurrenceSet.isEmpty ?? true }
        
        if let event = eventWithOccurrences {
            let eventOccurrences = try await playaDBImpl.dbQueue.read { db in
                try EventOccurrence.fetchAll(db, sql: "SELECT * FROM event_occurrences WHERE event_id = ?", arguments: [event.uid])
            }
            
            let expectedOccurrences = expectedEventObjects.first { $0.uid.rawValue == event.uid }?.occurrenceSet ?? []
            XCTAssertEqual(eventOccurrences.count, expectedOccurrences.count, 
                          "Should have correct number of occurrences for event")
        }
    }
    
    // MARK: - Update Info Tests
    
    func testUpdateInfoImport() async throws {
        // Given: Import data
        try await playaDB.importFromPlayaAPI()
        
        // When: Fetch update info
        let updateInfo = try await playaDB.getUpdateInfo()
        
        // Then: Verify update info for all data types
        XCTAssertEqual(updateInfo.count, 3, "Should have update info for all 3 data types")
        
        let dataTypes = Set(updateInfo.map { $0.dataType })
        XCTAssertTrue(dataTypes.contains("art"), "Should have update info for art")
        XCTAssertTrue(dataTypes.contains("camp"), "Should have update info for camp")
        XCTAssertTrue(dataTypes.contains("event"), "Should have update info for event")
        
        // Verify counts match actual imported data
        let artCount = try await playaDB.fetchArt().count
        let campCount = try await playaDB.fetchCamps().count
        let eventCount = try await playaDB.fetchEvents().count
        
        let artUpdateInfo = updateInfo.first { $0.dataType == "art" }
        let campUpdateInfo = updateInfo.first { $0.dataType == "camp" }
        let eventUpdateInfo = updateInfo.first { $0.dataType == "event" }
        
        XCTAssertEqual(artUpdateInfo?.totalCount, artCount, "Art update info count should match fetched count")
        XCTAssertEqual(campUpdateInfo?.totalCount, campCount, "Camp update info count should match fetched count")
        XCTAssertEqual(eventUpdateInfo?.totalCount, eventCount, "Event update info count should match fetched count")
    }
    
    // MARK: - Full Import Integration Test
    
    func testFullImportIntegration() async throws {
        // Given: Load all data types from PlayaAPI
        let artService = ArtService()
        let campService = CampService()
        let eventService = EventService()
        
        let expectedArtObjects = try artService.loadArt()
        let expectedCampObjects = try campService.loadCamps()
        let expectedEventObjects = try eventService.loadEvents()
        
        // When: Perform full import
        try await playaDB.importFromPlayaAPI()
        
        // Then: Verify all data was imported correctly
        let fetchedArtObjects = try await playaDB.fetchArt()
        let fetchedCampObjects = try await playaDB.fetchCamps()
        let fetchedEventObjects = try await playaDB.fetchEvents()
        
        XCTAssertEqual(fetchedArtObjects.count, expectedArtObjects.count, "Art objects count mismatch")
        XCTAssertEqual(fetchedCampObjects.count, expectedCampObjects.count, "Camp objects count mismatch")
        XCTAssertEqual(fetchedEventObjects.count, expectedEventObjects.count, "Event objects count mismatch")
        
        // Verify data integrity across all types
        XCTAssertGreaterThan(fetchedArtObjects.count, 0, "Should have imported art objects")
        XCTAssertGreaterThan(fetchedCampObjects.count, 0, "Should have imported camp objects")
        XCTAssertGreaterThan(fetchedEventObjects.count, 0, "Should have imported event objects")
        
        // Verify that some objects have GPS coordinates
        let artWithGPS = fetchedArtObjects.filter { $0.hasGPSLocation }
        let campsWithGPS = fetchedCampObjects.filter { $0.hasGPSLocation }
        let eventsWithGPS = fetchedEventObjects.filter { $0.hasGPSLocation }
        
        XCTAssertGreaterThan(artWithGPS.count, 0, "Should have art objects with GPS")
        XCTAssertGreaterThan(campsWithGPS.count, 0, "Should have camp objects with GPS")
        XCTAssertGreaterThan(eventsWithGPS.count, 0, "Should have event objects with GPS")
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistencyAfterImport() async throws {
        // Given: Import data
        try await playaDB.importFromPlayaAPI()
        
        // When: Verify data consistency
        let artObjects = try await playaDB.fetchArt()
        let campObjects = try await playaDB.fetchCamps()
        let eventObjects = try await playaDB.fetchEvents()
        
        // Then: Check that UIDs are unique within each type
        let artUIDs = Set(artObjects.map { $0.uid })
        let campUIDs = Set(campObjects.map { $0.uid })
        let eventUIDs = Set(eventObjects.map { $0.uid })
        
        XCTAssertEqual(artUIDs.count, artObjects.count, "Art UIDs should be unique")
        XCTAssertEqual(campUIDs.count, campObjects.count, "Camp UIDs should be unique")
        XCTAssertEqual(eventUIDs.count, eventObjects.count, "Event UIDs should be unique")
        
        // Verify that all objects have required fields
        for artObject in artObjects {
            XCTAssertFalse(artObject.uid.isEmpty, "Art object should have UID")
            XCTAssertFalse(artObject.name.isEmpty, "Art object should have name")
            XCTAssertGreaterThan(artObject.year, 0, "Art object should have valid year")
        }
        
        for campObject in campObjects {
            XCTAssertFalse(campObject.uid.isEmpty, "Camp object should have UID")
            XCTAssertFalse(campObject.name.isEmpty, "Camp object should have name")
            XCTAssertGreaterThan(campObject.year, 0, "Camp object should have valid year")
        }
        
        for eventObject in eventObjects {
            XCTAssertFalse(eventObject.uid.isEmpty, "Event object should have UID")
            XCTAssertFalse(eventObject.name.isEmpty, "Event object should have name")
            XCTAssertGreaterThan(eventObject.year, 0, "Event object should have valid year")
        }
    }
}

// MARK: - Helper Extensions

extension PlayaDBImportTests {
    /// Helper to access the internal database queue for testing
    var dbQueue: DatabaseQueue {
        (playaDB as! PlayaDBImpl).dbQueue
    }
}