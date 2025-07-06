import XCTest
@testable import PlayaAPI
import PlayaAPITestHelpers

final class APIParserTests: XCTestCase {
    
    var parser: APIParserProtocol!
    
    override func setUp() {
        super.setUp()
        parser = APIParserFactory.create()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Art Parsing Tests
    
    func testParseArt_ValidJSON_ReturnsCorrectData() throws {
        let artObjects = try parser.parseArt(from: MockAPIData.artJSON)
        
        XCTAssertEqual(artObjects.count, 1)
        
        let art = artObjects[0]
        XCTAssertEqual(art.uid.value, "a2IVI000000yWeZ2AU")
        XCTAssertEqual(art.name, "Temple of the Deep")
        XCTAssertEqual(art.year, 2025)
        XCTAssertEqual(art.url?.absoluteString, "https://www.2025temple.com/")
        XCTAssertEqual(art.contactEmail, "miguel@2025temple.com")
        XCTAssertEqual(art.hometown, "Valencia, Spain")
        XCTAssertEqual(art.artist, "Miguel Arraiz")
        XCTAssertEqual(art.category, "Open Playa")
        XCTAssertEqual(art.program, "Honorarium")
        XCTAssertEqual(art.donationLink?.absoluteString, "https://crowdfundr.com/2025temple")
        XCTAssertFalse(art.guidedTours)
        XCTAssertTrue(art.selfGuidedTourMap)
        XCTAssertEqual(art.images.count, 1)
        XCTAssertEqual(art.images[0].thumbnailUrl.absoluteString, "https://burningman.widen.net/content/jiicnlpjwu/jpeg/a2IVI000000yWeZ2AU-1.jpeg")
    }
    
    func testParseArt_InvalidJSON_ThrowsError() {
        let invalidJSON = "invalid json".data(using: .utf8)!
        
        XCTAssertThrowsError(try parser.parseArt(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testParseArt_EmptyArray_ReturnsEmptyArray() throws {
        let emptyJSON = "[]".data(using: .utf8)!
        let artObjects = try parser.parseArt(from: emptyJSON)
        
        XCTAssertTrue(artObjects.isEmpty)
    }
    
    // MARK: - Camp Parsing Tests
    
    func testParseCamps_ValidJSON_ReturnsCorrectData() throws {
        let campObjects = try parser.parseCamps(from: MockAPIData.campJSON)
        
        XCTAssertEqual(campObjects.count, 1)
        
        let camp = campObjects[0]
        XCTAssertEqual(camp.uid.value, "a1XVI000008yf262AA")
        XCTAssertEqual(camp.name, "Bag o' Dicks")
        XCTAssertEqual(camp.year, 2025)
        XCTAssertNil(camp.url)
        XCTAssertEqual(camp.contactEmail, "bagodicks.bm1@gmail.com")
        XCTAssertEqual(camp.hometown, "chicago")
        XCTAssertEqual(camp.landmark, "3 neon dicks in the sky with sparkly come shots")
        XCTAssertEqual(camp.images.count, 1)
        XCTAssertEqual(camp.images[0].thumbnailUrl.absoluteString, "https://burningman.widen.net/content/3ggbw9ehze/jpeg/a1XVI000008yf262AA-1.jpeg")
    }
    
    func testParseCamps_InvalidJSON_ThrowsError() {
        let invalidJSON = "invalid json".data(using: .utf8)!
        
        XCTAssertThrowsError(try parser.parseCamps(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Event Parsing Tests
    
    func testParseEvents_ValidJSON_ReturnsCorrectData() throws {
        let eventObjects = try parser.parseEvents(from: MockAPIData.eventJSON)
        
        XCTAssertEqual(eventObjects.count, 1)
        
        let event = eventObjects[0]
        XCTAssertEqual(event.uid.value, "6Fzgz5paNv8ZbedcCQRw")
        XCTAssertEqual(event.title, "Meowiokie")
        XCTAssertEqual(event.eventId, 51387)
        XCTAssertEqual(event.description, "Its karaoke but with meows. Come by and try")
        XCTAssertEqual(event.eventType.label, "Music/Party")
        XCTAssertEqual(event.eventType.abbreviation, "prty")
        XCTAssertEqual(event.year, 2025)
        XCTAssertEqual(event.slug, "6Fzgz5paNv8ZbedcCQRw-meowiokie")
        XCTAssertEqual(event.hostedByCamp?.value, "a1XVI000009qe5p2AA")
        XCTAssertNil(event.locatedAtArt)
        XCTAssertFalse(event.allDay)
        XCTAssertEqual(event.occurrenceSet.count, 1)
    }
    
    func testParseEvents_InvalidJSON_ThrowsError() {
        let invalidJSON = "invalid json".data(using: .utf8)!
        
        XCTAssertThrowsError(try parser.parseEvents(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - UpdateInfo Parsing Tests
    
    func testParseUpdateInfo_ValidJSON_ReturnsCorrectData() throws {
        let updateInfo = try parser.parseUpdateInfo(from: MockAPIData.updateInfoJSON)
        
        XCTAssertNotNil(updateInfo.art)
        XCTAssertNotNil(updateInfo.camps)
        XCTAssertNotNil(updateInfo.events)
        
        XCTAssertEqual(updateInfo.art?.file, "art.json")
        XCTAssertEqual(updateInfo.camps?.file, "camp.json")
        XCTAssertEqual(updateInfo.events?.file, "event.json")
        
        // Verify dates are parsed correctly
        let formatter = ISO8601DateFormatter()
        let expectedArtDate = formatter.date(from: "2025-07-28T11:51:02-07:00")
        let expectedCampsDate = formatter.date(from: "2025-07-28T11:58:02-07:00")
        let expectedEventsDate = formatter.date(from: "2025-07-28T11:58:02-07:00")
        
        XCTAssertEqual(updateInfo.art?.updated, expectedArtDate)
        XCTAssertEqual(updateInfo.camps?.updated, expectedCampsDate)
        XCTAssertEqual(updateInfo.events?.updated, expectedEventsDate)
    }
    
    func testParseUpdateInfo_InvalidJSON_ThrowsError() {
        let invalidJSON = "invalid json".data(using: .utf8)!
        
        XCTAssertThrowsError(try parser.parseUpdateInfo(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Parser Factory Tests
    
    func testAPIParserFactory_CreatesValidParser() {
        let parser = APIParserFactory.create()
        XCTAssertNotNil(parser)
    }
    
    func testAPIParserFactory_WithCustomDecoder() {
        let customDecoder = JSONDecoder()
        customDecoder.keyDecodingStrategy = .useDefaultKeys
        
        let parser = APIParserFactory.create(decoder: customDecoder)
        XCTAssertNotNil(parser)
    }
}