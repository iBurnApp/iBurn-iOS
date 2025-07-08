import XCTest
@testable import PlayaAPI
import PlayaAPITestHelpers
import iBurn2025APIData

final class BundleDataIntegrationTests: XCTestCase {
    
    var parser: APIParserProtocol!
    
    override func setUp() {
        super.setUp()
        parser = APIParserFactory.create()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }
    
    // MARK: - Bundle Data Loading Tests
    
    func testLoadArtDataFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.art.loadData()
        XCTAssertFalse(data.isEmpty, "Art data should not be empty")
        
        // Verify it can be parsed
        let artObjects = try parser.parseArt(from: data)
        XCTAssertFalse(artObjects.isEmpty, "Should have art objects in 2025 data")
        
        // Verify structure of first art object
        let firstArt = artObjects[0]
        XCTAssertFalse(firstArt.uid.value.isEmpty, "Art UID should not be empty")
        XCTAssertFalse(firstArt.name.isEmpty, "Art name should not be empty")
        XCTAssertEqual(firstArt.year, 2025, "Art year should be 2025")
    }
    
    func testLoadCampDataFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.camp.loadData()
        XCTAssertFalse(data.isEmpty, "Camp data should not be empty")
        
        // Verify it can be parsed
        let campObjects = try parser.parseCamps(from: data)
        XCTAssertFalse(campObjects.isEmpty, "Should have camp objects in 2025 data")
        
        // Verify structure of first camp object
        let firstCamp = campObjects[0]
        XCTAssertFalse(firstCamp.uid.value.isEmpty, "Camp UID should not be empty")
        XCTAssertFalse(firstCamp.name.isEmpty, "Camp name should not be empty")
        XCTAssertEqual(firstCamp.year, 2025, "Camp year should be 2025")
    }
    
    func testLoadEventDataFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.event.loadData()
        XCTAssertFalse(data.isEmpty, "Event data should not be empty")
        
        // Verify it can be parsed
        let eventObjects = try parser.parseEvents(from: data)
        XCTAssertFalse(eventObjects.isEmpty, "Should have event objects in 2025 data")
        
        // Verify structure of first event object
        let firstEvent = eventObjects[0]
        XCTAssertFalse(firstEvent.uid.value.isEmpty, "Event UID should not be empty")
        XCTAssertFalse(firstEvent.title.isEmpty, "Event title should not be empty")
        XCTAssertEqual(firstEvent.year, 2025, "Event year should be 2025")
    }
    
    func testLoadUpdateInfoFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.update.loadData()
        XCTAssertFalse(data.isEmpty, "Update info data should not be empty")
        
        // Verify it can be parsed
        let updateInfo = try parser.parseUpdateInfo(from: data)
        XCTAssertNotNil(updateInfo.art, "Should have art update info")
        XCTAssertNotNil(updateInfo.camps, "Should have camps update info")
        XCTAssertNotNil(updateInfo.events, "Should have events update info")
        
        XCTAssertEqual(updateInfo.art?.file, "art.json", "Art file should be art.json")
        XCTAssertEqual(updateInfo.camps?.file, "camp.json", "Camps file should be camp.json")
        XCTAssertEqual(updateInfo.events?.file, "event.json", "Events file should be event.json")
    }
    
    // MARK: - Additional Data Files Tests
    
    func testLoadCreditsFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.credits.loadData()
        XCTAssertFalse(data.isEmpty, "Credits data should not be empty")
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertNotNil(json, "Credits should be valid JSON")
    }
    
    func testLoadDatesInfoFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.datesInfo.loadData()
        XCTAssertFalse(data.isEmpty, "Dates info data should not be empty")
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertNotNil(json, "Dates info should be valid JSON")
    }
    
    func testLoadPointsFromBundle() throws {
        let data = try iBurn2025APIData.DataFile.points.loadData()
        XCTAssertFalse(data.isEmpty, "Points data should not be empty")
        
        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssertNotNil(json, "Points should be valid JSON")
    }
    
    // MARK: - Data Consistency Tests
    
    func testAllDataFilesAvailable() throws {
        for dataFile in iBurn2025APIData.DataFile.allCases {
            XCTAssertNotNil(dataFile.url, "Should have URL for \(dataFile.rawValue)")
            XCTAssertNoThrow(try dataFile.loadData(), "Should be able to load \(dataFile.rawValue)")
        }
    }
    
    func testDataVolumeRealistic() throws {
        // Art data should be substantial (at least 100KB)
        let artData = try iBurn2025APIData.DataFile.art.loadData()
        XCTAssertGreaterThan(artData.count, 100_000, "Art data should be substantial")
        
        // Camp data should be substantial (at least 500KB) 
        let campData = try iBurn2025APIData.DataFile.camp.loadData()
        XCTAssertGreaterThan(campData.count, 500_000, "Camp data should be substantial")
        
        // Event data should be very substantial (at least 1MB)
        let eventData = try iBurn2025APIData.DataFile.event.loadData()
        XCTAssertGreaterThan(eventData.count, 1_000_000, "Event data should be very substantial")
    }
    
    // MARK: - BundleDataLoader Tests
    
    func testBundleDataLoaderWithAPIDataBundle() throws {
        // Test that BundleDataLoader can work with the iBurn2025APIData bundle
        let data = try BundleDataLoader.loadArt(from: iBurn2025APIData.bundle)
        XCTAssertFalse(data.isEmpty, "Should load art data from bundle")
        
        // Verify it matches the direct bundle access
        let directData = try iBurn2025APIData.DataFile.art.loadData()
        XCTAssertEqual(data, directData, "BundleDataLoader should return same data as direct access")
    }
    
    func testBundleDataLoaderAllMethods() throws {
        // Test all BundleDataLoader methods with the iBurn2025APIData bundle
        XCTAssertNoThrow(try BundleDataLoader.loadArt(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadCamps(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadEvents(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadUpdateInfo(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadCredits(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadDatesInfo(from: iBurn2025APIData.bundle))
        XCTAssertNoThrow(try BundleDataLoader.loadPoints(from: iBurn2025APIData.bundle))
    }
}