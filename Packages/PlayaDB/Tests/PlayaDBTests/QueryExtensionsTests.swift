import XCTest
import Foundation
import CoreLocation
import MapKit
import GRDB
@testable import PlayaDB
@testable import PlayaAPI
import PlayaAPITestHelpers

/// Tests for protocol-based composable query extensions
final class QueryExtensionsTests: XCTestCase {
    var playaDB: PlayaDB!
    var dbQueue: DatabaseQueue {
        (playaDB as! PlayaDBImpl).dbQueue
    }
    var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Use in-memory database for testing
        tempDBPath = ":memory:"

        // Create PlayaDB instance
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        // Import test data
        let artData = MockAPIData.artJSON
        let campData = MockAPIData.campJSON
        let eventData = MockAPIData.eventJSON
        try await playaDB.importFromData(artData: artData, campData: campData, eventData: eventData)
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Column Protocol Conformance Tests

    func testArtObjectColumnsProtocolConformance() throws {
        // Given: ArtObject.Columns enum
        // When: Accessing protocol-required columns
        // Then: All protocol columns should be accessible at compile time

        // DataObjectColumns
        let _ = ArtObject.Columns.uid
        let _ = ArtObject.Columns.name
        let _ = ArtObject.Columns.year
        let _ = ArtObject.Columns.description

        // GeoLocatableColumns
        let _ = ArtObject.Columns.gpsLatitude
        let _ = ArtObject.Columns.gpsLongitude

        // WebUrlColumns
        let _ = ArtObject.Columns.url

        // ContactEmailColumns
        let _ = ArtObject.Columns.contactEmail

        // HometownColumns
        let _ = ArtObject.Columns.hometown

        // LocationStringColumns
        let _ = ArtObject.Columns.locationString

        // This test passing means compile-time verification succeeded
        XCTAssertTrue(true, "ArtObject.Columns conforms to all required protocols")
    }

    func testCampObjectColumnsProtocolConformance() throws {
        // Given: CampObject.Columns enum
        // When: Accessing protocol-required columns
        // Then: All protocol columns should be accessible at compile time

        // DataObjectColumns
        let _ = CampObject.Columns.uid
        let _ = CampObject.Columns.name
        let _ = CampObject.Columns.year
        let _ = CampObject.Columns.description

        // GeoLocatableColumns
        let _ = CampObject.Columns.gpsLatitude
        let _ = CampObject.Columns.gpsLongitude

        // WebUrlColumns
        let _ = CampObject.Columns.url

        // ContactEmailColumns
        let _ = CampObject.Columns.contactEmail

        // HometownColumns
        let _ = CampObject.Columns.hometown

        // LocationStringColumns
        let _ = CampObject.Columns.locationString

        XCTAssertTrue(true, "CampObject.Columns conforms to all required protocols")
    }

    func testEventObjectColumnsProtocolConformance() throws {
        // Given: EventObject.Columns enum
        // When: Accessing protocol-required columns
        // Then: Protocol columns should be accessible

        // DataObjectColumns
        let _ = EventObject.Columns.uid
        let _ = EventObject.Columns.name
        let _ = EventObject.Columns.year
        let _ = EventObject.Columns.description

        // GeoLocatableColumns
        let _ = EventObject.Columns.gpsLatitude
        let _ = EventObject.Columns.gpsLongitude

        // WebUrlColumns
        let _ = EventObject.Columns.url

        XCTAssertTrue(true, "EventObject.Columns conforms to required protocols")
    }

    func testEventOccurrenceColumnsProtocolConformance() throws {
        // Given: EventOccurrence.Columns enum
        // When: Accessing protocol-required columns
        // Then: Protocol columns should be accessible

        // EventOccurrenceColumns
        let _ = EventOccurrence.Columns.startTime
        let _ = EventOccurrence.Columns.endTime

        XCTAssertTrue(true, "EventOccurrence.Columns conforms to EventOccurrenceColumns")
    }

    // MARK: - DataObject Query Extension Tests

    func testOrderedByName() async throws {
        // Given: Art objects in database
        let artObjects = try await playaDB.fetchArt()
        XCTAssertGreaterThan(artObjects.count, 0, "Should have art objects")

        // When: Querying with orderedByName()
        let sortedArt = try await dbQueue.read { db in
            try ArtObject.all()
                .orderedByName()
                .fetchAll(db)
        }

        // Then: Results should be sorted alphabetically
        let names = sortedArt.map { $0.name }
        let expectedSorted = names.sorted()
        XCTAssertEqual(names, expectedSorted, "Art objects should be sorted by name")
    }

    func testForYear() async throws {
        // Given: Objects with specific year
        let artObjects = try await playaDB.fetchArt()
        guard let firstYear = artObjects.first?.year else {
            XCTFail("Should have at least one art object")
            return
        }

        // When: Filtering by year
        let yearFiltered = try await dbQueue.read { db in
            try ArtObject.all()
                .forYear(firstYear)
                .fetchAll(db)
        }

        // Then: All results should match the year
        XCTAssertGreaterThan(yearFiltered.count, 0, "Should have objects for year \(firstYear)")
        XCTAssertTrue(yearFiltered.allSatisfy { $0.year == firstYear }, "All objects should be from year \(firstYear)")
    }

    func testWithDescription() async throws {
        // Given: Art objects with and without descriptions
        // When: Filtering to only those with descriptions
        let withDesc = try await dbQueue.read { db in
            try ArtObject.all()
                .withDescription()
                .fetchAll(db)
        }

        // Then: All results should have non-nil descriptions
        XCTAssertTrue(withDesc.allSatisfy { $0.description != nil }, "All objects should have descriptions")
    }

    func testDescriptionContains() async throws {
        // Given: Art objects with various descriptions
        let allArt = try await playaDB.fetchArt()
        guard let firstWithDesc = allArt.first(where: { $0.description != nil }),
              let desc = firstWithDesc.description,
              desc.count > 3 else {
            // Skip if no suitable test data
            return
        }

        // Extract a substring to search for
        let searchTerm = String(desc.prefix(5))

        // When: Searching descriptions
        let results = try await dbQueue.read { db in
            try ArtObject.all()
                .descriptionContains(searchTerm)
                .fetchAll(db)
        }

        // Then: Results should contain the search term
        XCTAssertGreaterThan(results.count, 0, "Should find objects with description containing '\(searchTerm)'")
        XCTAssertTrue(results.allSatisfy {
            $0.description?.contains(searchTerm) ?? false
        }, "All results should contain search term in description")
    }

    // MARK: - Geographic Query Extension Tests

    func testWithLocation() async throws {
        // Given: Art objects with GPS coordinates
        // When: Filtering to only those with locations
        let withLocation = try await dbQueue.read { db in
            try ArtObject.all()
                .withLocation()
                .fetchAll(db)
        }

        // Then: All results should have GPS coordinates
        XCTAssertTrue(withLocation.allSatisfy {
            $0.gpsLatitude != nil && $0.gpsLongitude != nil
        }, "All objects should have GPS coordinates")
    }

    func testInRegion() async throws {
        // Given: A region around Black Rock City
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        // When: Filtering art objects in region
        let inRegion = try await dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .fetchAll(db)
        }

        // Then: All results should be within the region bounds
        let minLat = brcCenter.latitude - 0.05
        let maxLat = brcCenter.latitude + 0.05
        let minLon = brcCenter.longitude - 0.05
        let maxLon = brcCenter.longitude + 0.05

        for art in inRegion {
            if let lat = art.gpsLatitude, let lon = art.gpsLongitude {
                XCTAssertGreaterThanOrEqual(lat, minLat, "Latitude should be >= min")
                XCTAssertLessThanOrEqual(lat, maxLat, "Latitude should be <= max")
                XCTAssertGreaterThanOrEqual(lon, minLon, "Longitude should be >= min")
                XCTAssertLessThanOrEqual(lon, maxLon, "Longitude should be <= max")
            }
        }
    }

    func testOrderedByDistance() async throws {
        // Given: A reference coordinate
        let reference = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)

        // When: Ordering by distance
        let orderedByDistance = try await dbQueue.read { db in
            try ArtObject.all()
                .withLocation()
                .orderedByDistance(from: reference)
                .limit(10)
                .fetchAll(db)
        }

        // Then: Results should exist and be ordered (approximation)
        XCTAssertGreaterThan(orderedByDistance.count, 0, "Should have art objects ordered by distance")

        // Verify ordering is roughly correct (using Pythagorean distance approximation)
        var previousDistance: Double = 0
        for art in orderedByDistance {
            guard let lat = art.gpsLatitude, let lon = art.gpsLongitude else { continue }
            let latDiff = lat - reference.latitude
            let lonDiff = lon - reference.longitude
            let distance = latDiff * latDiff + lonDiff * lonDiff

            XCTAssertGreaterThanOrEqual(distance, previousDistance,
                "Distance should not decrease (may be approximately equal)")
            previousDistance = distance
        }
    }

    // MARK: - Event Occurrence Query Extension Tests

    func testNotExpired() async throws {
        // Given: Event occurrences, some expired
        let now = Date()

        // When: Filtering to non-expired events
        let notExpired = try await dbQueue.read { db in
            try EventOccurrence.all()
                .notExpired(at: now)
                .fetchAll(db)
        }

        // Then: All results should have end time after now
        XCTAssertTrue(notExpired.allSatisfy { $0.endTime > now },
            "All events should end after current time")
    }

    func testHappeningNow() async throws {
        // Given: Event occurrences
        let now = Date()

        // When: Filtering to currently happening events
        let happening = try await dbQueue.read { db in
            try EventOccurrence.all()
                .happeningNow(at: now)
                .fetchAll(db)
        }

        // Then: All results should be currently happening
        XCTAssertTrue(happening.allSatisfy {
            $0.startTime <= now && $0.endTime > now
        }, "All events should be happening now")
    }

    func testStartingWithin() async throws {
        // Given: Event occurrences
        let now = Date()
        let hours = 24

        // When: Finding events starting within 24 hours
        let upcoming = try await dbQueue.read { db in
            try EventOccurrence.all()
                .startingWithin(hours: hours, from: now)
                .fetchAll(db)
        }

        // Then: All results should start within the time window
        let endDate = Calendar.current.date(byAdding: .hour, value: hours, to: now) ?? now
        XCTAssertTrue(upcoming.allSatisfy {
            $0.startTime >= now && $0.startTime <= endDate
        }, "All events should start within \(hours) hours")
    }

    func testOrderedByStartTime() async throws {
        // Given: Event occurrences
        // When: Ordering by start time
        let ordered = try await dbQueue.read { db in
            try EventOccurrence.all()
                .orderedByStartTime()
                .fetchAll(db)
        }

        // Then: Results should be chronologically ordered
        var previousStartTime: Date = Date.distantPast
        for occurrence in ordered {
            XCTAssertGreaterThanOrEqual(occurrence.startTime, previousStartTime,
                "Start times should be in ascending order")
            previousStartTime = occurrence.startTime
        }
    }

    // MARK: - Contact Info Query Extension Tests

    func testWithUrl() async throws {
        // Given: Art objects with URLs
        // When: Filtering to only those with URLs
        let withUrl = try await dbQueue.read { db in
            try ArtObject.all()
                .withUrl()
                .fetchAll(db)
        }

        // Then: All results should have non-nil URLs
        XCTAssertTrue(withUrl.allSatisfy { $0.url != nil }, "All objects should have URLs")
    }

    func testWithUrlMatching() async throws {
        // Given: Art objects with URLs
        let pattern = "http"

        // When: Filtering by URL pattern
        let matching = try await dbQueue.read { db in
            try ArtObject.all()
                .withUrl(matching: pattern)
                .fetchAll(db)
        }

        // Then: All results should have URLs containing the pattern
        XCTAssertTrue(matching.allSatisfy {
            $0.url?.absoluteString.contains(pattern) ?? false
        }, "All URLs should contain pattern '\(pattern)'")
    }

    func testWithContactEmail() async throws {
        // Given: Art objects with contact emails
        // When: Filtering to only those with emails
        let withEmail = try await dbQueue.read { db in
            try ArtObject.all()
                .withContactEmail()
                .fetchAll(db)
        }

        // Then: All results should have non-nil emails
        XCTAssertTrue(withEmail.allSatisfy { $0.contactEmail != nil },
            "All objects should have contact emails")
    }

    func testWithEmailDomain() async throws {
        // Given: Art objects with contact emails
        let allWithEmail = try await dbQueue.read { db in
            try ArtObject.all()
                .withContactEmail()
                .fetchAll(db)
        }

        guard let firstEmail = allWithEmail.first?.contactEmail,
              let domain = firstEmail.split(separator: "@").last else {
            // Skip if no suitable test data
            return
        }

        // When: Filtering by email domain
        let withDomain = try await dbQueue.read { db in
            try ArtObject.all()
                .withEmailDomain(String(domain))
                .fetchAll(db)
        }

        // Then: All results should have emails with that domain
        XCTAssertGreaterThan(withDomain.count, 0, "Should find objects with domain")
        XCTAssertTrue(withDomain.allSatisfy {
            $0.contactEmail?.hasSuffix("@\(domain)") ?? false
        }, "All emails should have domain '\(domain)'")
    }

    func testWithHometown() async throws {
        // Given: Art objects with hometowns
        // When: Filtering to only those with hometowns
        let withHometown = try await dbQueue.read { db in
            try ArtObject.all()
                .withHometown()
                .fetchAll(db)
        }

        // Then: All results should have non-nil hometowns
        XCTAssertTrue(withHometown.allSatisfy { $0.hometown != nil },
            "All objects should have hometowns")
    }

    func testFromHometown() async throws {
        // Given: Art objects with hometowns
        let allWithHometown = try await dbQueue.read { db in
            try ArtObject.all()
                .withHometown()
                .fetchAll(db)
        }

        guard let firstHometown = allWithHometown.first?.hometown,
              firstHometown.count > 3 else {
            // Skip if no suitable test data
            return
        }

        let searchTerm = String(firstHometown.prefix(5))

        // When: Filtering by hometown
        let fromHometown = try await dbQueue.read { db in
            try ArtObject.all()
                .fromHometown(searchTerm)
                .fetchAll(db)
        }

        // Then: All results should have matching hometowns
        XCTAssertGreaterThan(fromHometown.count, 0, "Should find objects from hometown")
        XCTAssertTrue(fromHometown.allSatisfy {
            $0.hometown?.contains(searchTerm) ?? false
        }, "All hometowns should contain '\(searchTerm)'")
    }

    func testOrderedByHometown() async throws {
        // Given: Art objects with hometowns
        // When: Ordering by hometown
        let ordered = try await dbQueue.read { db in
            try ArtObject.all()
                .withHometown()
                .orderedByHometown()
                .fetchAll(db)
        }

        // Then: Results should be alphabetically sorted by hometown
        let hometowns = ordered.compactMap { $0.hometown }
        let expectedSorted = hometowns.sorted()
        XCTAssertEqual(hometowns, expectedSorted, "Hometowns should be sorted alphabetically")
    }

    func testWithLocationString() async throws {
        // Given: Art objects with location strings
        // When: Filtering to only those with location strings
        let withLocation = try await dbQueue.read { db in
            try ArtObject.all()
                .withLocationString()
                .fetchAll(db)
        }

        // Then: All results should have non-nil location strings
        XCTAssertTrue(withLocation.allSatisfy { $0.locationString != nil },
            "All objects should have location strings")
    }

    func testAtLocationMatching() async throws {
        // Given: Art objects with location strings
        let allWithLocation = try await dbQueue.read { db in
            try ArtObject.all()
                .withLocationString()
                .fetchAll(db)
        }

        guard let firstLocation = allWithLocation.first?.locationString,
              firstLocation.count > 3 else {
            // Skip if no suitable test data
            return
        }

        let pattern = String(firstLocation.prefix(5))

        // When: Filtering by location pattern
        let matching = try await dbQueue.read { db in
            try ArtObject.all()
                .atLocation(matching: pattern)
                .fetchAll(db)
        }

        // Then: All results should have matching location strings
        XCTAssertGreaterThan(matching.count, 0, "Should find objects at location")
        XCTAssertTrue(matching.allSatisfy {
            $0.locationString?.contains(pattern) ?? false
        }, "All location strings should contain '\(pattern)'")
    }

    // MARK: - Favorites Query Extension Tests
    // TODO: Enable once GRDB associations are set up for favorites

    /*
    func testOnlyFavorites() async throws {
        // Given: Some favorited art objects
        let allArt = try await playaDB.fetchArt()
        guard let firstArt = allArt.first else {
            XCTFail("Should have at least one art object")
            return
        }

        // Mark as favorite
        try await playaDB.toggleFavorite(firstArt)

        // When: Querying for favorites only
        let favorites = try await dbQueue.read { db in
            try ArtObject.all()
                .onlyFavorites()
                .fetchAll(db)
        }

        // Then: Should include the favorited object
        XCTAssertTrue(favorites.contains(where: { $0.uid == firstArt.uid }),
            "Favorites should include the favorited art object")

        // Verify all returned objects are actually favorited
        for art in favorites {
            let isFavorite = try await playaDB.isFavorite(art)
            XCTAssertTrue(isFavorite, "All returned objects should be favorited")
        }
    }
    */

    // MARK: - Composability Tests (Critical!)

    func testComposedQueries_GeographicAndContact() async throws {
        // Given: A region and contact info filters
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        // When: Chaining multiple filters together
        let results = try await dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .withLocation()
                .withUrl()
                .orderedByName()
                .fetchAll(db)
        }

        // Then: All filters should be applied
        let minLat = brcCenter.latitude - 0.05
        let maxLat = brcCenter.latitude + 0.05
        let minLon = brcCenter.longitude - 0.05
        let maxLon = brcCenter.longitude + 0.05

        for art in results {
            // Has location
            XCTAssertNotNil(art.gpsLatitude, "Should have latitude")
            XCTAssertNotNil(art.gpsLongitude, "Should have longitude")

            // In region
            if let lat = art.gpsLatitude, let lon = art.gpsLongitude {
                XCTAssertGreaterThanOrEqual(lat, minLat)
                XCTAssertLessThanOrEqual(lat, maxLat)
                XCTAssertGreaterThanOrEqual(lon, minLon)
                XCTAssertLessThanOrEqual(lon, maxLon)
            }

            // Has URL
            XCTAssertNotNil(art.url, "Should have URL")
        }

        // Verify ordering
        let names = results.map { $0.name }
        let expectedSorted = names.sorted()
        XCTAssertEqual(names, expectedSorted, "Should be sorted by name")
    }

    func testComposedQueries_ComplexChain() async throws {
        // Given: Multiple filters for a complex query
        // When: Chaining many filters together
        let results = try await dbQueue.read { db in
            try ArtObject.all()
                .withDescription()
                .withUrl()
                .withHometown()
                .orderedByName()
                .limit(10)
                .fetchAll(db)
        }

        // Then: All filters should be applied
        XCTAssertLessThanOrEqual(results.count, 10, "Should respect limit")

        for art in results {
            XCTAssertNotNil(art.description, "Should have description")
            XCTAssertNotNil(art.url, "Should have URL")
            XCTAssertNotNil(art.hometown, "Should have hometown")
        }

        // Verify ordering
        if results.count > 1 {
            let names = results.map { $0.name }
            let expectedSorted = names.sorted()
            XCTAssertEqual(names, expectedSorted, "Should be sorted by name")
        }
    }

    func testComposedQueries_EventTiming() async throws {
        // Given: Event occurrences with time-based filters
        let now = Date()

        // When: Chaining time and ordering filters
        let results = try await dbQueue.read { db in
            try EventOccurrence.all()
                .notExpired(at: now)
                .orderedByStartTime()
                .limit(5)
                .fetchAll(db)
        }

        // Then: All filters should be applied
        XCTAssertLessThanOrEqual(results.count, 5, "Should respect limit")

        // Not expired
        XCTAssertTrue(results.allSatisfy { $0.endTime > now },
            "All events should not be expired")

        // Ordered by start time
        var previousStartTime: Date = Date.distantPast
        for occurrence in results {
            XCTAssertGreaterThanOrEqual(occurrence.startTime, previousStartTime,
                "Should be ordered by start time")
            previousStartTime = occurrence.startTime
        }
    }

    // TODO: Enable once favorites associations are implemented
    /*
    func testComposedQueries_FavoritesWithFilters() async throws {
        // Given: Some favorited objects
        let allArt = try await playaDB.fetchArt()
        let objectsToFavorite = allArt.prefix(3)

        for art in objectsToFavorite {
            try await playaDB.toggleFavorite(art)
        }

        // When: Combining favorites with other filters
        let results = try await dbQueue.read { db in
            try ArtObject.all()
                .onlyFavorites()
                .orderedByName()
                .fetchAll(db)
        }

        // Then: Should get favorited objects in alphabetical order
        XCTAssertGreaterThan(results.count, 0, "Should have favorited objects")

        for art in results {
            let isFavorite = try await playaDB.isFavorite(art)
            XCTAssertTrue(isFavorite, "Should be favorited")
        }

        // Verify ordering
        let names = results.map { $0.name }
        let expectedSorted = names.sorted()
        XCTAssertEqual(names, expectedSorted, "Should be sorted by name")
    }
    */

    func testComposedQueries_CrossModelConsistency() async throws {
        // Given: Same filters applied to different models
        let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
        let region = MKCoordinateRegion(
            center: brcCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        // When: Applying same query to Art and Camps
        let artResults = try await dbQueue.read { db in
            try ArtObject.all()
                .inRegion(region)
                .withLocation()
                .orderedByName()
                .fetchAll(db)
        }

        let campResults = try await dbQueue.read { db in
            try CampObject.all()
                .inRegion(region)
                .withLocation()
                .orderedByName()
                .fetchAll(db)
        }

        // Then: Both queries should work identically
        // Verify art results
        for art in artResults {
            XCTAssertNotNil(art.gpsLatitude)
            XCTAssertNotNil(art.gpsLongitude)
        }

        // Verify camp results
        for camp in campResults {
            XCTAssertNotNil(camp.gpsLatitude)
            XCTAssertNotNil(camp.gpsLongitude)
        }

        // Verify both are sorted
        if artResults.count > 1 {
            let artNames = artResults.map { $0.name }
            XCTAssertEqual(artNames, artNames.sorted())
        }

        if campResults.count > 1 {
            let campNames = campResults.map { $0.name }
            XCTAssertEqual(campNames, campNames.sorted())
        }
    }
}
