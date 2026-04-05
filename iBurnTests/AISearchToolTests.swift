//
//  AISearchToolTests.swift
//  iBurnTests
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@preconcurrency @testable import iBurn
@testable import PlayaDB

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@MainActor
final class AISearchToolTests: XCTestCase {

    private var playaDB: PlayaDB!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON,
            mvData: Self.mvJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - SearchByKeywordTool Tests

    func testSearchByKeywordTool_FindsArt() async throws {
        let tool = SearchByKeywordTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(query: "Burning"))

        XCTAssertTrue(result.contains("Burning Questions"), "Should find art by name")
        XCTAssertTrue(result.contains("a2IVI000000yWeZ2AU"), "Should include uid")
    }

    func testSearchByKeywordTool_FindsCamp() async throws {
        let tool = SearchByKeywordTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(query: "ASL"))

        XCTAssertTrue(result.contains("Camp ASL"), "Should find camp by name")
        XCTAssertTrue(result.contains("a1XVI000008zSaf2AE"), "Should include uid")
    }

    func testSearchByKeywordTool_FindsMV() async throws {
        let tool = SearchByKeywordTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(query: "Dragon"))

        XCTAssertTrue(result.contains("Dragon Wagon"), "Should find MV by name")
        XCTAssertTrue(result.contains("a6BVI000000Xf1r3BC"), "Should include uid")
    }

    func testSearchByKeywordTool_NoResults() async throws {
        let tool = SearchByKeywordTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(query: "zzzznonexistent"))

        XCTAssertEqual(result, "No results found.")
    }

    // MARK: - FetchArtTool Tests

    func testFetchArtTool_AllArt() async throws {
        let tool = FetchArtTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: nil))

        XCTAssertTrue(result.contains("Burning Questions"), "Should return art")
        XCTAssertTrue(result.contains("a2IVI000000yWeZ2AU"), "Should include uid")
    }

    func testFetchArtTool_WithKeyword() async throws {
        let tool = FetchArtTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: "curiosity"))

        // "curiosity" appears in description: "exploring curiosity and wonder"
        XCTAssertTrue(result.contains("Burning Questions"),
                      "Should find art with 'curiosity' in description")
    }

    func testFetchArtTool_NoMatch() async throws {
        let tool = FetchArtTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: "zzzznotfound"))

        XCTAssertEqual(result, "No art found.")
    }

    // MARK: - FetchCampsTool Tests

    func testFetchCampsTool_AllCamps() async throws {
        let tool = FetchCampsTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: nil))

        XCTAssertTrue(result.contains("Camp ASL"), "Should return camps")
    }

    func testFetchCampsTool_WithKeyword() async throws {
        let tool = FetchCampsTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: "sign language"))

        XCTAssertTrue(result.contains("Camp ASL"),
                      "Should find camp with 'sign language' in description")
    }

    // MARK: - FetchMutantVehiclesTool Tests

    func testFetchMutantVehiclesTool_AllMVs() async throws {
        let tool = FetchMutantVehiclesTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: nil))

        XCTAssertTrue(result.contains("Dragon Wagon"), "Should return MVs")
        XCTAssertTrue(result.contains("Moebius Omnibus"), "Should return all MVs")
    }

    func testFetchMutantVehiclesTool_WithKeyword() async throws {
        let tool = FetchMutantVehiclesTool(playaDB: playaDB)
        let result = try await tool.call(arguments: .init(keyword: "dragon"))

        XCTAssertTrue(result.contains("Dragon Wagon"), "Should find MV by keyword")
        XCTAssertFalse(result.contains("Moebius"), "Should not include non-matching MVs")
    }

    // MARK: - FoundationModelSearchService Tests

    func testFoundationModelSearchService_AvailabilityCheck() {
        let service = FoundationModelSearchService(playaDB: playaDB)
        // Just verify the availability check doesn't crash
        // On simulator, isAvailable will be false
        _ = service.isAvailable
    }

    func testFoundationModelSearchService_SearchWhenUnavailable() async throws {
        let service = FoundationModelSearchService(playaDB: playaDB)
        // On simulator without Apple Intelligence, search should return empty
        if !service.isAvailable {
            let results = try await service.search("test query")
            XCTAssertTrue(results.isEmpty, "Should return empty when AI unavailable")
        }
    }

    // MARK: - AISearchServiceFactory Tests

    func testAISearchServiceFactory_CreatesService() {
        // Factory should create a service (may be nil if AI unavailable on simulator)
        let service = AISearchServiceFactory.create(playaDB: playaDB)
        if SystemLanguageModel.default.isAvailable {
            XCTAssertNotNil(service, "Should create service when AI is available")
        } else {
            XCTAssertNil(service, "Should return nil when AI is unavailable")
        }
    }

    // MARK: - End-to-End Tool Flow Tests

    func testToolOutputIsWellFormatted() async throws {
        // Verify all tool outputs follow a consistent format the model can parse
        let keywordTool = SearchByKeywordTool(playaDB: playaDB)
        let artTool = FetchArtTool(playaDB: playaDB)
        let campTool = FetchCampsTool(playaDB: playaDB)
        let mvTool = FetchMutantVehiclesTool(playaDB: playaDB)

        let keywordResult = try await keywordTool.call(arguments: .init(query: "Burning"))
        let artResult = try await artTool.call(arguments: .init(keyword: nil))
        let campResult = try await campTool.call(arguments: .init(keyword: nil))
        let mvResult = try await mvTool.call(arguments: .init(keyword: nil))

        // All results should contain uid references
        for result in [keywordResult, artResult, campResult, mvResult] {
            XCTAssertTrue(result.contains("uid:"), "Tool output should contain uid references: \(result)")
        }

        // Combined output should fit in context window (~4096 tokens ≈ ~16000 chars)
        let totalLength = keywordResult.count + artResult.count + campResult.count + mvResult.count
        XCTAssertLessThan(totalLength, 16000, "Combined tool output should fit in context window")
    }

    // MARK: - Fixture Data

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2025,"url":"https://www.burningquestions.com/","contact_email":"artist@burningquestions.com","hometown":"San Francisco, CA","description":"An interactive art installation exploring curiosity and wonder.","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":"https://crowdfundr.com/burningquestions","location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[{"thumbnail_url":"https://example.com/art-image.jpeg","gallery_ref":"gallery-123"}],"guided_tours":false,"self_guided_tour_map":true}]
    """.data(using: .utf8)!

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Camp ASL Support Services HUB","year":2025,"url":null,"contact_email":"ddhplanb@gmail.com","hometown":"All over, north, and, South America","description":"American sign language Support services. Centralized services for the Deaf.","landmark":"American sign language support services sign","location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":"Mid-block facing 10:00"},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8)!

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"First time picking up cards? A professional reader? All levels welcome","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2025,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000009t6XR2AY","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2025-08-28T12:00:00-07:00","end_time":"2025-08-28T13:30:00-07:00"}]}]
    """.data(using: .utf8)!

    private static let mvJSON = """
    [{"uid":"a6BVI000000Xf1r3BC","name":"Dragon Wagon","year":2025,"description":"A fire-breathing dragon on wheels","artist":"Fire Arts Collective","hometown":"Portland, OR","url":"https://dragonwagon.com","contact_email":"info@dragonwagon.com","donation_link":null,"images":[{"thumbnail_url":"https://example.com/dragon.jpg"}],"tags":["Fire","Dragon"]},{"uid":"a6BVI000000Le0r2AC","name":"Moebius Omnibus","year":2025,"description":"A never-ending bus ride through infinity","artist":"Math Art Lab","hometown":"Austin, TX","url":null,"contact_email":null,"donation_link":null,"images":[],"tags":["Circular","Math"]}]
    """.data(using: .utf8)!
}

#endif
