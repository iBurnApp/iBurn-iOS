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
        XCTAssertEqual(art.name, "Burning Questions")
        XCTAssertEqual(art.year, 2025)
        XCTAssertEqual(art.url?.absoluteString, "https://www.burningquestions.com/")
        XCTAssertEqual(art.contactEmail, "artist@burningquestions.com")
        XCTAssertEqual(art.hometown, "San Francisco, CA")
        XCTAssertEqual(art.artist, "Jane Smith")
        XCTAssertEqual(art.category, "Open Playa")
        XCTAssertEqual(art.program, "Honorarium")
        XCTAssertEqual(art.donationLink?.absoluteString, "https://crowdfundr.com/burningquestions")
        XCTAssertFalse(art.guidedTours)
        XCTAssertTrue(art.selfGuidedTourMap)
        XCTAssertEqual(art.images.count, 1)
        XCTAssertEqual(art.images[0].thumbnailUrl?.absoluteString, "https://example.com/art-image.jpeg")
        XCTAssertEqual(art.images[0].galleryRef, "gallery-123")
        XCTAssertNotNil(art.location)
        XCTAssertEqual(art.location?.hour, 12)
        XCTAssertEqual(art.location?.gpsLatitude, 40.79179890754886)
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
        XCTAssertEqual(camp.uid.value, "a1XVI000008zSaf2AE")
        XCTAssertEqual(camp.name, "Camp ASL Support Services HUB")
        XCTAssertEqual(camp.year, 2025)
        XCTAssertNil(camp.url)
        XCTAssertEqual(camp.contactEmail, "ddhplanb@gmail.com")
        XCTAssertEqual(camp.hometown, "All over, north, and, South America")
        XCTAssertEqual(camp.landmark, "American sign language support services sign")
        XCTAssertEqual(camp.images.count, 0)
        XCTAssertNotNil(camp.location)
        XCTAssertEqual(camp.location?.frontage, "Esplanade")
        XCTAssertEqual(camp.location?.intersection, "6:30")
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
        XCTAssertEqual(event.uid.value, "78ZvNxSeeZQbaeHuughD")
        XCTAssertEqual(event.title, "Fairycore Tarot Meetup")
        XCTAssertEqual(event.eventId, 51138)
        XCTAssertEqual(event.description, "First time picking up cards? A professional reader? All levels welcome")
        XCTAssertEqual(event.eventType.label, "Class/Workshop")
        XCTAssertEqual(event.eventType.type, .classWorkshop)
        XCTAssertEqual(event.year, 2025)
        XCTAssertEqual(event.slug, "78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup")
        XCTAssertEqual(event.hostedByCamp?.value, "a1XVI000009t6XR2AY")
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
    
    // MARK: - MutantVehicle Parsing Tests

    func testParseMutantVehicles_ValidJSON_ReturnsCorrectData() throws {
        let mvObjects = try parser.parseMutantVehicles(from: MockAPIData.mutantVehicleJSON)

        XCTAssertEqual(mvObjects.count, 2)

        let mv = mvObjects[0]
        XCTAssertEqual(mv.uid.value, "a6BVI000000Le0r2AC")
        XCTAssertEqual(mv.name, "Moebius Omnibus")
        XCTAssertEqual(mv.year, 2026)
        XCTAssertNil(mv.url)
        XCTAssertNil(mv.donationLink)
        XCTAssertEqual(mv.contactEmail, "p4l@hotmail.com")
        XCTAssertEqual(mv.hometown, "Oakley, CA")
        XCTAssertEqual(mv.artist, "Phil 'pEEf' Sadow")
        XCTAssertEqual(mv.images.count, 1)
        XCTAssertEqual(mv.images[0].thumbnailUrl?.absoluteString, "https://example.com/mv-image.jpeg")
        XCTAssertEqual(mv.tags, ["Round", "Flying Saucer", "Circular"])

        let mv2 = mvObjects[1]
        XCTAssertEqual(mv2.name, "Dragon Wagon")
        XCTAssertEqual(mv2.url?.absoluteString, "https://dragonwagon.art")
        XCTAssertEqual(mv2.donationLink?.absoluteString, "https://donate.example.com/dragon")
        XCTAssertNil(mv2.contactEmail)
        XCTAssertTrue(mv2.images.isEmpty)
        XCTAssertEqual(mv2.tags, ["Dragon", "Fire"])
    }

    func testParseMutantVehicles_InvalidJSON_ThrowsError() {
        let invalidJSON = "invalid json".data(using: .utf8)!

        XCTAssertThrowsError(try parser.parseMutantVehicles(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testParseMutantVehicles_EmptyArray_ReturnsEmptyArray() throws {
        let emptyJSON = "[]".data(using: .utf8)!
        let mvObjects = try parser.parseMutantVehicles(from: emptyJSON)

        XCTAssertTrue(mvObjects.isEmpty)
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
