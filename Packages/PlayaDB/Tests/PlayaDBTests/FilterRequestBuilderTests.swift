import XCTest
import CoreLocation
import MapKit
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Tests that validate the filter request builders and filtered fetch APIs.
final class FilterRequestBuilderTests: XCTestCase {
    private var playaDB: PlayaDB!
    private var tempDBPath: String!

    private var dbQueue: DatabaseQueue {
        (playaDB as! PlayaDBImpl).dbQueue
    }

    // MARK: - XCTest Lifecycle

    override func setUp() async throws {
        try await super.setUp()

        tempDBPath = ":memory:"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        // Seed baseline mock data
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        tempDBPath = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func insertArt(
        uid: String,
        name: String,
        year: Int,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> ArtObject {
        let art = ArtObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )

        try await dbQueue.write { db in
            var mutableArt = art
            try mutableArt.insert(db)
        }

        return art
    }

    @discardableResult
    private func insertCamp(
        uid: String,
        name: String,
        year: Int,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> CampObject {
        let camp = CampObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )

        try await dbQueue.write { db in
            var mutableCamp = camp
            try mutableCamp.insert(db)
        }

        return camp
    }

    private func insertEvent(
        uid: String,
        name: String,
        year: Int,
        start: Date,
        end: Date,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws {
        let event = EventObject(
            uid: uid,
            name: name,
            year: year,
            description: description,
            eventTypeLabel: "Workshop",
            eventTypeCode: "work",
            gpsLatitude: latitude,
            gpsLongitude: longitude
        )

        try await dbQueue.write { db in
            var mutableEvent = event
            try mutableEvent.insert(db)

            var insertedOccurrence = EventOccurrence(
                eventId: uid,
                startTime: start,
                endTime: end
            )
            try insertedOccurrence.insert(db)
        }
    }

    // MARK: - Art Filters

    func testArtRequestAppliesYearRegionAndSearchFilters() async throws {
        // Additional fixtures to challenge filters
        try await insertArt(
            uid: "art-outside-region",
            name: "Far Away Sculpture",
            year: 2025,
            description: "Sculpture far from playa center",
            latitude: 40.1,
            longitude: -119.9
        )

        try await insertArt(
            uid: "art-different-year",
            name: "Vintage Piece",
            year: 2024,
            description: "Historic artwork inside the city",
            latitude: 40.79,
            longitude: -119.21
        )

        try await insertArt(
            uid: "art-no-location",
            name: "Mystery Installation",
            year: 2025,
            description: "No coordinates available"
        )

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )

        // Filter targets the imported mock art (curiosity keyword & GPS inside region)
        let filter = ArtFilter(
            year: 2025,
            region: region,
            searchText: "curiosity"
        )

        let request = (playaDB as! PlayaDBImpl).artRequest(filter: filter)
        let results = try await dbQueue.read { db in
            try request.fetchAll(db)
        }

        XCTAssertEqual(results.count, 1, "Only the mock art record should match all filters")
        XCTAssertEqual(results.first?.uid, "a2IVI000000yWeZ2AU")
    }

    func testFetchArtFilterOrdersByNameAscending() async throws {
        try await insertArt(
            uid: "art-alpha",
            name: "Alpha Installation",
            year: 2025,
            description: "Alphabetical test",
            latitude: 40.785,
            longitude: -119.205
        )

        try await insertArt(
            uid: "art-beta",
            name: "Beta Installation",
            year: 2025,
            description: "Alphabetical test two",
            latitude: 40.786,
            longitude: -119.204
        )

        let filter = ArtFilter(year: 2025)
        let art = try await playaDB.fetchArt(filter: filter)
        let names = art.map(\.name)

        XCTAssertEqual(names, names.sorted(), "Art results should be ordered alphabetically by name")
    }

    // MARK: - Camp Filters

    func testCampRequestAppliesRegionAndSearchFilters() async throws {
        try await insertCamp(
            uid: "camp-library",
            name: "Desert Library",
            year: 2025,
            description: "Mobile library with workshops",
            latitude: 40.789,
            longitude: -119.205
        )

        try await insertCamp(
            uid: "camp-outside",
            name: "Remote Camp",
            year: 2025,
            description: "Too far away",
            latitude: 40.2,
            longitude: -119.8
        )

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )

        let filter = CampFilter(
            year: 2025,
            region: region,
            searchText: "library"
        )

        let request = (playaDB as! PlayaDBImpl).campRequest(filter: filter)
        let results = try await dbQueue.read { db in
            try request.fetchAll(db)
        }

        XCTAssertEqual(results.count, 1, "Only the Desert Library should match the compound filter")
        XCTAssertEqual(results.first?.uid, "camp-library")
    }

    func testFetchCampsFilterOrdersByNameAscending() async throws {
        try await insertCamp(
            uid: "camp-alpha",
            name: "Alpha Camp",
            year: 2025,
            latitude: 40.785,
            longitude: -119.205
        )

        try await insertCamp(
            uid: "camp-beta",
            name: "Beta Camp",
            year: 2025,
            latitude: 40.786,
            longitude: -119.204
        )

        let filter = CampFilter(year: 2025)
        let camps = try await playaDB.fetchCamps(filter: filter)
        let names = camps.map(\.name)

        XCTAssertEqual(names, names.sorted(), "Camp results should be ordered alphabetically by name")
    }

    // MARK: - Event Filters

    func testEventOccurrenceRequestTimeFilters() async throws {
        let now = Date()

        try await insertEvent(
            uid: "event-past",
            name: "Past Gathering",
            year: 2025,
            start: now.addingTimeInterval(-7200),
            end: now.addingTimeInterval(-3600),
            description: "Already finished"
        )

        try await insertEvent(
            uid: "event-current",
            name: "Current Workshop",
            year: 2025,
            start: now.addingTimeInterval(-1800),
            end: now.addingTimeInterval(1800),
            description: "Happening now"
        )

        try await insertEvent(
            uid: "event-future",
            name: "Future Class",
            year: 2025,
            start: now.addingTimeInterval(7200),
            end: now.addingTimeInterval(10800),
            description: "Upcoming"
        )

        let impl = playaDB as! PlayaDBImpl

        let happeningFilter = EventFilter(happeningNow: true)
        let happening = try await dbQueue.read { db in
            try impl.eventOccurrenceRequest(filter: happeningFilter).fetchAll(db)
        }
        XCTAssertEqual(happening.map(\.eventId), ["event-current"])

        let upcomingFilter = EventFilter(startingWithinHours: 3)
        let upcoming = try await dbQueue.read { db in
            try impl.eventOccurrenceRequest(filter: upcomingFilter).fetchAll(db)
        }
        XCTAssertEqual(upcoming.map(\.eventId), ["event-future"])

        let notExpiredFilter = EventFilter(includeExpired: false)
        let notExpired = try await dbQueue.read { db in
            try impl.eventOccurrenceRequest(filter: notExpiredFilter).fetchAll(db)
        }
        XCTAssertEqual(
            Set(notExpired.map(\.eventId)),
            Set(["event-current", "event-future"]),
            "Expired events should be excluded when includeExpired is false"
        )
    }

    func testFetchEventsAppliesYearRegionAndSearchFilters() async throws {
        let now = Date()
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )

        try await insertEvent(
            uid: "event-match",
            name: "Sunrise Yoga",
            year: 2025,
            start: now.addingTimeInterval(3600),
            end: now.addingTimeInterval(7200),
            description: "Daily yoga practice",
            latitude: 40.787,
            longitude: -119.205
        )

        try await insertEvent(
            uid: "event-different-year",
            name: "Old Year Gala",
            year: 2024,
            start: now.addingTimeInterval(3600),
            end: now.addingTimeInterval(7200),
            description: "Different year",
            latitude: 40.787,
            longitude: -119.205
        )

        try await insertEvent(
            uid: "event-outside-region",
            name: "Distant Music",
            year: 2025,
            start: now.addingTimeInterval(3600),
            end: now.addingTimeInterval(7200),
            description: "Too far away",
            latitude: 40.2,
            longitude: -119.8
        )

        try await insertEvent(
            uid: "event-no-location",
            name: "Secret Location Party",
            year: 2025,
            start: now.addingTimeInterval(3600),
            end: now.addingTimeInterval(7200),
            description: "Location TBD"
        )

        try await insertEvent(
            uid: "event-search-miss",
            name: "Morning Meditation",
            year: 2025,
            start: now.addingTimeInterval(3600),
            end: now.addingTimeInterval(7200),
            description: "Relaxing meditation inside region",
            latitude: 40.788,
            longitude: -119.204
        )

        let filter = EventFilter(
            year: 2025,
            region: region,
            searchText: "yoga",
            includeExpired: true
        )

        let events = try await playaDB.fetchEvents(filter: filter)
        XCTAssertEqual(events.count, 1, "Only Sunrise Yoga should match all event-level filters")
        XCTAssertEqual(events.first?.event.uid, "event-match")
    }
}
