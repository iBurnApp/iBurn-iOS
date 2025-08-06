import XCTest
import Foundation
import CoreLocation
import MapKit
import GRDB
@testable import PlayaDB
@testable import PlayaAPI
import iBurn2025APIData

final class PlayaDBRealDataTests: XCTestCase {
    var playaDB: PlayaDB!
    var tempDBPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let dbURL = tempDir.appendingPathComponent("test-\(UUID().uuidString).sqlite")
        tempDBPath = dbURL.path
        
        // Create PlayaDB instance with temporary database
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
    }
    
    override func tearDown() async throws {
        playaDB = nil
        
        // Clean up temporary database
        if FileManager.default.fileExists(atPath: tempDBPath) {
            try FileManager.default.removeItem(atPath: tempDBPath)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Real Data Import Tests
    
    func testImportRealDataFromiBurnBundle() async throws {
        // Given: Load real data from iBurn2025APIData bundle
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        // When: Import data into PlayaDB
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // Then: Verify we have the real data
        let artObjects = try await playaDB.fetchArt()
        let campObjects = try await playaDB.fetchCamps()
        let eventObjects = try await playaDB.fetchEvents()
        
        // These should have substantial amounts of real data
        XCTAssertGreaterThan(artObjects.count, 50, "Should have many art objects from real data")
        XCTAssertGreaterThan(campObjects.count, 100, "Should have many camp objects from real data")
        XCTAssertGreaterThan(eventObjects.count, 100, "Should have many event objects from real data")
        
        print("Imported \(artObjects.count) art objects, \(campObjects.count) camps, \(eventObjects.count) event occurrences")
    }
    
    func testRealDataHasGPSCoordinates() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // When: Check for GPS coordinates
        let artObjects = try await playaDB.fetchArt()
        let campObjects = try await playaDB.fetchCamps()
        let eventObjects = try await playaDB.fetchEvents()
        
        let artWithGPS = artObjects.filter { $0.hasGPSLocation }
        let campsWithGPS = campObjects.filter { $0.hasGPSLocation }
        let eventsWithGPS = eventObjects.filter { $0.hasGPSLocation }
        
        // Then: Real data should have many objects with GPS coordinates
        XCTAssertGreaterThan(artWithGPS.count, 10, "Should have art objects with GPS coordinates")
        XCTAssertGreaterThan(campsWithGPS.count, 50, "Should have camp objects with GPS coordinates")
        XCTAssertGreaterThan(eventsWithGPS.count, 50, "Should have event objects with GPS coordinates from host locations")
        
        print("GPS Coverage: \(artWithGPS.count)/\(artObjects.count) art, \(campsWithGPS.count)/\(campObjects.count) camps, \(eventsWithGPS.count)/\(eventObjects.count) events")
    }
    
    func testSearchPerformanceWithRealData() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // When: Perform search queries
        let startTime = Date()
        let searchResults = try await playaDB.searchObjects("camp")
        let searchTime = Date().timeIntervalSince(startTime)
        
        // Then: Search should be fast and return results
        XCTAssertGreaterThan(searchResults.count, 0, "Should find results for 'camp'")
        XCTAssertLessThan(searchTime, 1.0, "Search should complete in under 1 second")
        
        print("Found \(searchResults.count) results for 'camp' in \(searchTime) seconds")
    }
    
    func testSpatialQueryWithRealData() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // When: Query a region around Black Rock City
        // Approximate center of Black Rock City
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        let startTime = Date()
        let objectsInRegion = try await playaDB.fetchObjects(in: region)
        let queryTime = Date().timeIntervalSince(startTime)
        
        // Then: Should find objects efficiently
        XCTAssertGreaterThan(objectsInRegion.count, 0, "Should find objects in BRC region")
        XCTAssertLessThan(queryTime, 0.5, "Spatial query should be fast with R-Tree index")
        
        print("Found \(objectsInRegion.count) objects in region in \(queryTime) seconds")
    }
    
    func testEventOccurrencesWithRealData() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // When: Fetch events for a specific day (Thursday of event week)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let thursday = formatter.date(from: "2025-08-28")!
        
        let thursdayEvents = try await playaDB.fetchEvents(on: thursday)
        
        // Then: Should have many events on Thursday
        XCTAssertGreaterThan(thursdayEvents.count, 50, "Should have many events on Thursday")
        
        // Check for events spanning midnight
        let crossMidnightEvents = thursdayEvents.filter { event in
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: event.startDate)
            let endDay = calendar.startOfDay(for: event.endDate)
            return startDay != endDay
        }
        
        print("Thursday has \(thursdayEvents.count) events, \(crossMidnightEvents.count) span midnight")
    }
    
    func testFavoritesWithRealData() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
        
        // When: Mark some items as favorites
        let artObjects = try await playaDB.fetchArt()
        let campObjects = try await playaDB.fetchCamps()
        
        // Mark first 5 art pieces as favorites
        for art in artObjects.prefix(5) {
            try await playaDB.toggleFavorite(art)
        }
        
        // Mark first 3 camps as favorites
        for camp in campObjects.prefix(3) {
            try await playaDB.toggleFavorite(camp)
        }
        
        // Then: Should be able to retrieve favorites
        let favorites = try await playaDB.getFavorites()
        XCTAssertEqual(favorites.count, 8, "Should have 8 favorites (5 art + 3 camps)")
        
        // Verify favorite status
        let firstArt = artObjects.first!
        let isFavorite = try await playaDB.isFavorite(firstArt)
        XCTAssertTrue(isFavorite, "First art object should be marked as favorite")
    }
}