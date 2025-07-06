import XCTest
@testable import PlayaAPI
import PlayaAPITestHelpers

final class CodableTests: XCTestCase {
    
    var encoder: JSONEncoder!
    var decoder: JSONDecoder!
    
    override func setUp() {
        super.setUp()
        encoder = PlayaAPI.createEncoder()
        decoder = PlayaAPI.createDecoder()
    }
    
    override func tearDown() {
        encoder = nil
        decoder = nil
        super.tearDown()
    }
    
    // MARK: - Round-trip Tests
    
    func testArt_RoundTripCoding() throws {
        let originalArt = MockAPIData.mockArt
        
        let encoded = try encoder.encode([originalArt])
        let decoded = try decoder.decode([Art].self, from: encoded)
        
        XCTAssertEqual(decoded.count, 1)
        let decodedArt = decoded[0]
        
        XCTAssertEqual(decodedArt.uid, originalArt.uid)
        XCTAssertEqual(decodedArt.name, originalArt.name)
        XCTAssertEqual(decodedArt.year, originalArt.year)
        XCTAssertEqual(decodedArt.url, originalArt.url)
        XCTAssertEqual(decodedArt.contactEmail, originalArt.contactEmail)
        XCTAssertEqual(decodedArt.images.count, originalArt.images.count)
    }
    
    func testCamp_RoundTripCoding() throws {
        let originalCamp = MockAPIData.mockCamp
        
        let encoded = try encoder.encode([originalCamp])
        let decoded = try decoder.decode([Camp].self, from: encoded)
        
        XCTAssertEqual(decoded.count, 1)
        let decodedCamp = decoded[0]
        
        XCTAssertEqual(decodedCamp.uid, originalCamp.uid)
        XCTAssertEqual(decodedCamp.name, originalCamp.name)
        XCTAssertEqual(decodedCamp.year, originalCamp.year)
        XCTAssertEqual(decodedCamp.contactEmail, originalCamp.contactEmail)
        XCTAssertEqual(decodedCamp.landmark, originalCamp.landmark)
        XCTAssertEqual(decodedCamp.images.count, originalCamp.images.count)
    }
    
    func testEvent_RoundTripCoding() throws {
        let originalEvent = MockAPIData.mockEvent
        
        let encoded = try encoder.encode([originalEvent])
        let decoded = try decoder.decode([Event].self, from: encoded)
        
        XCTAssertEqual(decoded.count, 1)
        let decodedEvent = decoded[0]
        
        XCTAssertEqual(decodedEvent.uid, originalEvent.uid)
        XCTAssertEqual(decodedEvent.title, originalEvent.title)
        XCTAssertEqual(decodedEvent.eventId, originalEvent.eventId)
        XCTAssertEqual(decodedEvent.eventType.label, originalEvent.eventType.label)
        XCTAssertEqual(decodedEvent.hostedByCamp, originalEvent.hostedByCamp)
        XCTAssertEqual(decodedEvent.occurrenceSet.count, originalEvent.occurrenceSet.count)
    }
    
    func testUpdateInfo_RoundTripCoding() throws {
        let originalUpdateInfo = MockAPIData.mockUpdateInfo
        
        let encoded = try encoder.encode(originalUpdateInfo)
        let decoded = try decoder.decode(UpdateInfo.self, from: encoded)
        
        XCTAssertEqual(decoded.art?.file, originalUpdateInfo.art?.file)
        XCTAssertEqual(decoded.camps?.file, originalUpdateInfo.camps?.file)
        XCTAssertEqual(decoded.events?.file, originalUpdateInfo.events?.file)
        XCTAssertEqual(decoded.art?.updated, originalUpdateInfo.art?.updated)
        XCTAssertEqual(decoded.camps?.updated, originalUpdateInfo.camps?.updated)
        XCTAssertEqual(decoded.events?.updated, originalUpdateInfo.events?.updated)
    }
    
    // MARK: - Identifier Coding Tests
    
    func testIdentifiers_CodingAsStrings() throws {
        let artID: ArtID = "test-art-123"
        let campID: CampID = "test-camp-456"
        let eventID: EventID = "test-event-789"
        
        // Test ArtID
        let encodedArt = try encoder.encode(artID)
        let decodedArt = try decoder.decode(ArtID.self, from: encodedArt)
        XCTAssertEqual(decodedArt, artID)
        
        // Test CampID
        let encodedCamp = try encoder.encode(campID)
        let decodedCamp = try decoder.decode(CampID.self, from: encodedCamp)
        XCTAssertEqual(decodedCamp, campID)
        
        // Test EventID
        let encodedEvent = try encoder.encode(eventID)
        let decodedEvent = try decoder.decode(EventID.self, from: encodedEvent)
        XCTAssertEqual(decodedEvent, eventID)
    }
    
    // MARK: - Date Coding Tests
    
    func testEventOccurrence_DateCoding() throws {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600)
        let occurrence = EventOccurrence(startTime: startTime, endTime: endTime)
        
        let encoded = try encoder.encode(occurrence)
        let decoded = try decoder.decode(EventOccurrence.self, from: encoded)
        
        // Allow for small differences due to encoding/decoding precision
        XCTAssertEqual(decoded.startTime.timeIntervalSince1970, startTime.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(decoded.endTime.timeIntervalSince1970, endTime.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - URL Coding Tests
    
    func testURL_CodingWithNilValues() throws {
        let artWithoutURL = Art(
            uid: "test-id",
            name: "Test Art",
            year: 2025,
            url: nil,
            donationLink: nil
        )
        
        let encoded = try encoder.encode(artWithoutURL)
        let decoded = try decoder.decode(Art.self, from: encoded)
        
        XCTAssertNil(decoded.url)
        XCTAssertNil(decoded.donationLink)
    }
    
    func testURL_CodingWithValidURLs() throws {
        let testURL = URL(string: "https://example.com")!
        let donationURL = URL(string: "https://donate.example.com")!
        
        let artWithURLs = Art(
            uid: "test-id",
            name: "Test Art",
            year: 2025,
            url: testURL,
            donationLink: donationURL
        )
        
        let encoded = try encoder.encode(artWithURLs)
        let decoded = try decoder.decode(Art.self, from: encoded)
        
        XCTAssertEqual(decoded.url, testURL)
        XCTAssertEqual(decoded.donationLink, donationURL)
    }
    
    // MARK: - Snake Case Conversion Tests
    
    func testSnakeCaseConversion() throws {
        // Test that snake_case JSON fields are properly converted to camelCase Swift properties
        let jsonData = """
        {
            "uid": "test-id",
            "name": "Test Art",
            "year": 2025,
            "contact_email": "test@example.com",
            "donation_link": "https://donate.example.com",
            "location_string": "Center Camp",
            "guided_tours": true,
            "self_guided_tour_map": false,
            "images": []
        }
        """.data(using: .utf8)!
        
        let decoded = try decoder.decode(Art.self, from: jsonData)
        
        XCTAssertEqual(decoded.contactEmail, "test@example.com")
        XCTAssertEqual(decoded.donationLink?.absoluteString, "https://donate.example.com")
        XCTAssertEqual(decoded.locationString, "Center Camp")
        XCTAssertTrue(decoded.guidedTours)
        XCTAssertFalse(decoded.selfGuidedTourMap)
    }
}