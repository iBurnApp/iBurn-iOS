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
    
    private func loadAllRealData() throws -> (art: Data, camp: Data, event: Data, mv: Data) {
        (
            art: try iBurn2025APIData.DataFile.art.loadData(),
            camp: try iBurn2025APIData.DataFile.camp.loadData(),
            event: try iBurn2025APIData.DataFile.event.loadData(),
            mv: try iBurn2025APIData.DataFile.mv.loadData()
        )
    }

    private func importAllRealData() async throws {
        let data = try loadAllRealData()
        try await playaDB.importFromData(artData: data.art, campData: data.camp, eventData: data.event, mvData: data.mv)
    }

    func testImportRealDataFromiBurnBundle() async throws {
        // Given: Load real data from iBurn2025APIData bundle
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        let mvData = try iBurn2025APIData.DataFile.mv.loadData()

        // When: Import data into PlayaDB
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData, mvData: mvData)

        // Then: Verify we have the real data
        let artObjects = try await playaDB.fetchArt()
        let campObjects = try await playaDB.fetchCamps()
        let eventObjects = try await playaDB.fetchEvents()
        let mvObjects = try await playaDB.fetchMutantVehicles()

        // These should have substantial amounts of real data
        XCTAssertGreaterThan(artObjects.count, 50, "Should have many art objects from real data")
        XCTAssertGreaterThan(campObjects.count, 100, "Should have many camp objects from real data")
        XCTAssertGreaterThan(eventObjects.count, 100, "Should have many event objects from real data")
        XCTAssertGreaterThan(mvObjects.count, 100, "Should have many MV objects from real data")

        print("Imported \(artObjects.count) art, \(campObjects.count) camps, \(eventObjects.count) events, \(mvObjects.count) mutant vehicles")
    }
    
    func testMutantVehicleRealDataImport() async throws {
        try await importAllRealData()

        let mvObjects = try await playaDB.fetchMutantVehicles()
        XCTAssertGreaterThan(mvObjects.count, 100, "Should have many MV objects")

        // Verify MVs have no location
        for mv in mvObjects.prefix(10) {
            XCTAssertFalse(mv.hasLocation, "MVs should have no location")
            XCTAssertNil(mv.location, "MVs should have nil location")
            XCTAssertEqual(mv.objectType, .mutantVehicle)
            XCTAssertFalse(mv.name.isEmpty)
        }

        // Verify image URLs are loaded
        let imageURLs = try await playaDB.fetchMutantVehicleImageURLs()
        XCTAssertGreaterThan(imageURLs.count, 50, "Many MVs should have images")

        // Verify search works with real MV data
        let searchResults = try await playaDB.searchObjects("dragon")
        let mvResults = searchResults.filter { $0.objectType == .mutantVehicle }
        // "dragon" is a common MV theme
        XCTAssertGreaterThan(mvResults.count, 0, "Should find MVs when searching 'dragon'")

        print("MV real data: \(mvObjects.count) vehicles, \(imageURLs.count) with images")
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

    // MARK: - AI Search Scenario Tests
    //
    // These tests validate that the PlayaDB queries underlying the AI search tools
    // produce meaningful results for various search patterns. The on-device Foundation
    // Model would call these same queries via Tool wrappers.

    func testSearchByKeyword_MultipleTypes() async throws {
        try await importAllRealData()

        // A keyword search should return results across multiple object types
        let results = try await playaDB.searchObjects("fire")
        let types = Set(results.map { $0.objectType })

        XCTAssertGreaterThan(results.count, 0, "Should find results for 'fire'")
        print("'fire' search: \(results.count) results across types: \(types)")

        // Verify result objects have names (tool would format these for the model)
        for result in results.prefix(5) {
            XCTAssertFalse(result.name.isEmpty, "Each result should have a name")
            XCTAssertFalse(result.uid.isEmpty, "Each result should have a uid")
        }
    }

    func testSearchByKeyword_SingleWordQueries() async throws {
        try await importAllRealData()

        // Test various single-word queries that an AI model might decompose from natural language
        let queries = ["music", "dance", "yoga", "art", "temple", "burn"]
        for query in queries {
            let results = try await playaDB.searchObjects(query)
            print("'\(query)' search: \(results.count) results")
            // Most common festival terms should find something
            XCTAssertGreaterThan(results.count, 0, "Should find results for '\(query)'")
        }
    }

    func testFetchArtWithFilter_KeywordSearch() async throws {
        try await importAllRealData()

        // Simulate what FetchArtTool would do
        var filter = ArtFilter.all
        filter.searchText = "temple"
        let results = try await playaDB.fetchArt(filter: filter)

        XCTAssertGreaterThan(results.count, 0, "Should find art matching 'temple'")
        for art in results {
            XCTAssertFalse(art.name.isEmpty)
            XCTAssertFalse(art.uid.isEmpty)
        }
        print("Art filter 'temple': \(results.count) results")
    }

    func testFetchCampsWithFilter_KeywordSearch() async throws {
        try await importAllRealData()

        // Simulate what FetchCampsTool would do
        var filter = CampFilter.all
        filter.searchText = "music"
        let results = try await playaDB.fetchCamps(filter: filter)

        XCTAssertGreaterThan(results.count, 0, "Should find camps matching 'music'")
        for camp in results {
            XCTAssertFalse(camp.name.isEmpty)
            XCTAssertFalse(camp.uid.isEmpty)
        }
        print("Camp filter 'music': \(results.count) results")
    }

    func testFetchMVsWithFilter_KeywordSearch() async throws {
        try await importAllRealData()

        // Simulate what FetchMutantVehiclesTool would do
        var filter = MutantVehicleFilter.all
        filter.searchText = "dragon"
        let results = try await playaDB.fetchMutantVehicles(filter: filter)

        XCTAssertGreaterThan(results.count, 0, "Should find MVs matching 'dragon'")
        for mv in results {
            XCTAssertFalse(mv.name.isEmpty)
            XCTAssertFalse(mv.uid.isEmpty)
        }
        print("MV filter 'dragon': \(results.count) results")
    }

    func testToolOutputFormatting_ResultsAreConcise() async throws {
        try await importAllRealData()

        // Verify that search results can be formatted concisely for the on-device model's
        // 4096 token context window. Each result should be expressible in ~100 chars.
        let results = try await playaDB.searchObjects("camp")
        let formatted = results.prefix(15).map { obj in
            "\(obj.objectType.rawValue): \(obj.name) (uid: \(obj.uid))"
        }.joined(separator: "\n")

        // 15 results formatted should fit comfortably in the context window
        XCTAssertLessThan(formatted.count, 3000, "Formatted results should be concise enough for context window")
        print("Formatted output (\(formatted.count) chars):\n\(formatted)")
    }

    func testSearchObjectsFetchByUID_Roundtrip() async throws {
        try await importAllRealData()

        // Simulate the AI search flow: search -> get UIDs -> fetch individual objects
        let searchResults = try await playaDB.searchObjects("fire")
        XCTAssertGreaterThan(searchResults.count, 0)

        // For each result, verify we can fetch it back by UID (as mergeAIResults does)
        for result in searchResults.prefix(5) {
            switch result.objectType {
            case .art:
                let fetched = try await playaDB.fetchArt(uid: result.uid)
                XCTAssertNotNil(fetched, "Should fetch art by uid: \(result.uid)")
                XCTAssertEqual(fetched?.name, result.name)
            case .camp:
                let fetched = try await playaDB.fetchCamp(uid: result.uid)
                XCTAssertNotNil(fetched, "Should fetch camp by uid: \(result.uid)")
                XCTAssertEqual(fetched?.name, result.name)
            case .event:
                let fetched = try await playaDB.fetchEvent(uid: result.uid)
                XCTAssertNotNil(fetched, "Should fetch event by uid: \(result.uid)")
                XCTAssertEqual(fetched?.name, result.name)
            case .mutantVehicle:
                let fetched = try await playaDB.fetchMutantVehicle(uid: result.uid)
                XCTAssertNotNil(fetched, "Should fetch MV by uid: \(result.uid)")
                XCTAssertEqual(fetched?.name, result.name)
            }
        }
    }

    func testMultipleToolCallScenario_DecomposedQuery() async throws {
        try await importAllRealData()

        // Simulate what the AI model would do for "interactive fire art":
        // 1. Call searchByKeyword("fire") for broad results
        let fireResults = try await playaDB.searchObjects("fire")

        // 2. Call fetchArt(keyword: "interactive") for targeted art search
        var artFilter = ArtFilter.all
        artFilter.searchText = "interactive"
        let interactiveArt = try await playaDB.fetchArt(filter: artFilter)

        // 3. Both calls should return results
        XCTAssertGreaterThan(fireResults.count, 0, "Should find results for 'fire'")
        XCTAssertGreaterThan(interactiveArt.count, 0, "Should find interactive art")

        // 4. The model would intersect/rank these -- verify UIDs are usable
        let fireUIDs = Set(fireResults.map { $0.uid })
        let interactiveUIDs = Set(interactiveArt.map { $0.uid })
        let overlap = fireUIDs.intersection(interactiveUIDs)
        print("'fire' results: \(fireResults.count), 'interactive' art: \(interactiveArt.count), overlap: \(overlap.count)")
    }

    // MARK: - Re-import Tests

    func testImportFromDataTwice_Succeeds() async throws {
        // First import
        try await importAllRealData()
        let firstInfo = try await playaDB.getUpdateInfo()
        XCTAssertFalse(firstInfo.isEmpty, "Should have update info after first import")
        let firstArtCount = firstInfo.first(where: { $0.dataType == "art" })!.totalCount

        // Brief pause so timestamps differ
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Second import — this is the scenario that was failing
        try await importAllRealData()
        let secondInfo = try await playaDB.getUpdateInfo()
        XCTAssertFalse(secondInfo.isEmpty, "Should have update info after second import")

        let secondArt = secondInfo.first(where: { $0.dataType == "art" })!
        XCTAssertEqual(secondArt.totalCount, firstArtCount, "Art count should match")
        XCTAssertEqual(secondArt.fetchStatus, "complete", "Status should be complete")
        XCTAssertNotNil(secondArt.ingestionDate, "Ingestion date should be set")
        XCTAssertNotNil(secondArt.fetchDate, "Fetch date should be set")

        // Verify the timestamps are from the second import, not the first
        XCTAssertGreaterThan(secondArt.createdAt, firstInfo.first(where: { $0.dataType == "art" })!.createdAt,
                            "Second import should have later timestamp")

        print("Re-import test passed: \(secondInfo.count) update info rows with status '\(secondArt.fetchStatus)'")
    }

    // MARK: - Event Occurrence Time Correction Tests

    func testEventOccurrenceDurationsAreReasonable() async throws {
        try await importAllRealData()

        let dbImpl = playaDB as! PlayaDBImpl
        let occurrences = try await dbImpl.dbQueue.read { db in
            try EventOccurrence.fetchAll(db)
        }

        XCTAssertGreaterThan(occurrences.count, 100, "Should have many occurrences")

        var negativeDurations = 0
        var excessiveDurations = 0
        for occ in occurrences {
            let duration = occ.endTime.timeIntervalSince(occ.startTime)
            if duration < 0 {
                negativeDurations += 1
            }
            if duration > 24 * 60 * 60 {
                excessiveDurations += 1
            }
        }

        XCTAssertEqual(negativeDurations, 0, "No occurrences should have negative duration after correction")
        XCTAssertEqual(excessiveDurations, 0, "No occurrences should have >24h duration after correction")

        print("Validated \(occurrences.count) occurrences: 0 negative, 0 excessive durations")
    }

    // MARK: - Query Extension Performance Tests

    func testQueryExtensions_OrderedByNamePerformance() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Query with orderedByName() extension
        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .orderedByName()
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Should be fast and return sorted results
        XCTAssertGreaterThan(results.count, 0, "Should have results")
        XCTAssertLessThan(queryTime, 0.1, "Query should complete in under 100ms")

        print("orderedByName() query: \(results.count) results in \(queryTime)s")
    }

    func testQueryExtensions_InRegionPerformance() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Query with inRegion() extension
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Should be fast with R-Tree optimization
        XCTAssertGreaterThan(results.count, 0, "Should find objects in region")
        XCTAssertLessThan(queryTime, 0.1, "Spatial query should complete in under 100ms")

        print("inRegion() query: \(results.count) results in \(queryTime)s")
    }

    func testQueryExtensions_ComposedQueryPerformance() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Execute complex composed query
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .withLocation()
                .withUrl()
                .orderedByName()
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Composed query should still be fast (single SQL query)
        XCTAssertLessThan(queryTime, 0.15, "Composed query should complete in under 150ms")

        print("Composed query (inRegion + withLocation + withUrl + orderedByName): \(results.count) results in \(queryTime)s")
    }

    // TODO: Re-enable once favorites associations are implemented
    /*
    func testQueryExtensions_FavoritesPerformance() async throws {
        // Given: Import real data and mark favorites
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // Mark some favorites
        let artObjects = try await playaDB.fetchArt()
        for art in artObjects.prefix(20) {
            try await playaDB.toggleFavorite(art)
        }

        // When: Query favorites with extensions
        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .onlyFavorites()
                .orderedByName()
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Join query should be fast
        XCTAssertGreaterThan(results.count, 0, "Should have favorited objects")
        XCTAssertLessThan(queryTime, 0.1, "Favorites query with join should complete in under 100ms")

        print("onlyFavorites() + orderedByName() query: \(results.count) results in \(queryTime)s")
    }
    */

    func testQueryExtensions_EventTimingPerformance() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Query events with timing filters
        let now = Date()
        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try EventOccurrence.all()
                .notExpired(at: now)
                .orderedByStartTime()
                .limit(100)
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Time-based query should be fast
        XCTAssertLessThan(queryTime, 0.1, "Event timing query should complete in under 100ms")

        print("notExpired() + orderedByStartTime() query: \(results.count) results in \(queryTime)s")
    }

    func testQueryExtensions_ContactInfoPerformance() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Query with contact info filters
        let dbImpl = playaDB as! PlayaDBImpl
        let startTime = Date()

        let results = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .withUrl()
                .withContactEmail()
                .withHometown()
                .orderedByHometown()
                .fetchAll(db)
        }

        let queryTime = Date().timeIntervalSince(startTime)

        // Then: Multiple filter query should be fast
        XCTAssertLessThan(queryTime, 0.15, "Contact info query should complete in under 150ms")

        print("withUrl() + withContactEmail() + withHometown() + orderedByHometown() query: \(results.count) results in \(queryTime)s")
    }

    func testQueryExtensions_CrossModelConsistency() async throws {
        // Given: Import real data
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        let eventData = try iBurn2025APIData.DataFile.event.loadData()

        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)

        // When: Apply same query to different models
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        let dbImpl = playaDB as! PlayaDBImpl

        let artResults = try await dbImpl.dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .withLocation()
                .orderedByName()
                .fetchAll(db)
        }

        let campResults = try await dbImpl.dbQueue.read { db in
            try CampObject.all()
                .inRegion(region)
                .withLocation()
                .orderedByName()
                .fetchAll(db)
        }

        // Then: Both queries should work and be consistent
        XCTAssertGreaterThan(artResults.count, 0, "Should have art results")
        XCTAssertGreaterThan(campResults.count, 0, "Should have camp results")

        print("Cross-model query: \(artResults.count) art, \(campResults.count) camps in same region")
    }
}