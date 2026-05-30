//
//  RightNowCandidateTests.swift
//  iBurnTests
//
//  Tests the pure (no-LLM) candidate gathering for the Right Now flow.
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import CoreLocation
import MapKit
@preconcurrency @testable import iBurn
@testable import PlayaDB

#if canImport(FoundationModels)

@available(iOS 26, *)
@MainActor
final class RightNowCandidateTests: XCTestCase {

    private var playaDB: PlayaDB!

    private let artUID = "a2IVI000000yWeZ2AU"
    private let eventUID = "78ZvNxSeeZQbaeHuughD"
    private let artCoord = CLLocationCoordinate2D(latitude: 40.79179890754886, longitude: -119.1976993927176)

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

    private func region(around c: CLLocationCoordinate2D, delta: Double = 0.02) -> MKCoordinateRegion {
        MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta))
    }

    private func brcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = hour; components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .burningManTimeZone
        return calendar.date(from: components) ?? Date.distantPast
    }

    func testTimelessArtAppearsInNowWhenInRegion() async throws {
        let now = brcDate(2025, 8, 28, 11, 30)
        let result = try await gatherRightNowCandidates(
            playaDB: playaDB,
            region: region(around: artCoord),
            origin: artCoord,
            now: now,
            windowStart: now,
            windowEnd: now.addingTimeInterval(2 * 3600),
            vibe: "",
            lean: .balanced,
            favoriteUIDs: [],
            includeHappeningNow: true
        )
        XCTAssertTrue(result.now.contains { $0.uid == artUID },
                      "Art within the region should be a 'now' candidate")
    }

    func testArtOutsideRegionIsExcluded() async throws {
        let now = brcDate(2025, 8, 28, 11, 30)
        let far = region(around: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        let result = try await gatherRightNowCandidates(
            playaDB: playaDB,
            region: far,
            origin: far.center,
            now: now,
            windowStart: now,
            windowEnd: now.addingTimeInterval(2 * 3600),
            vibe: "",
            lean: .balanced,
            favoriteUIDs: [],
            includeHappeningNow: true
        )
        XCTAssertFalse(result.now.contains { $0.uid == artUID },
                       "Art outside the region should be excluded")
    }

    func testUpcomingEventAppearsInNext() async throws {
        let now = brcDate(2025, 8, 28, 11, 30)
        // region nil → city-wide (event host has no GPS, so a region filter would drop it).
        let result = try await gatherRightNowCandidates(
            playaDB: playaDB,
            region: nil,
            origin: artCoord,
            now: now,
            windowStart: now,
            windowEnd: brcDate(2025, 8, 28, 14, 0),
            vibe: "",
            lean: .balanced,
            favoriteUIDs: [],
            includeHappeningNow: false
        )
        XCTAssertTrue(result.next.contains { $0.uid == eventUID },
                      "Event starting within the window should be a 'next' candidate")
    }

    func testSurpriseLeanExcludesFavorites() async throws {
        let art = try await playaDB.fetchArt()
        let first = try XCTUnwrap(art.first)
        try await playaDB.toggleFavorite(first)

        let now = brcDate(2025, 8, 28, 11, 30)
        let result = try await gatherRightNowCandidates(
            playaDB: playaDB,
            region: region(around: artCoord),
            origin: artCoord,
            now: now,
            windowStart: now,
            windowEnd: now.addingTimeInterval(2 * 3600),
            vibe: "",
            lean: .surprise,
            favoriteUIDs: [first.uid],
            includeHappeningNow: true
        )
        XCTAssertFalse(result.now.contains { $0.uid == first.uid },
                       "Surprise lean should exclude favorited items")
    }

    // MARK: - Fixtures

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2025,"url":null,"contact_email":null,"hometown":"San Francisco, CA","description":"An interactive art installation exploring curiosity and wonder.","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":null,"location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":true}]
    """.data(using: .utf8)!

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Camp ASL Support Services HUB","year":2025,"url":null,"contact_email":null,"hometown":"All over","description":"American sign language Support services.","landmark":"ASL sign","location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":"Mid-block facing 10:00"},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8)!

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"First time picking up cards? All levels welcome","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2025,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000009t6XR2AY","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2025-08-28T12:00:00-07:00","end_time":"2025-08-28T13:30:00-07:00"}]}]
    """.data(using: .utf8)!

    private static let mvJSON = """
    [{"uid":"a6BVI000000Xf1r3BC","name":"Dragon Wagon","year":2025,"description":"A fire-breathing dragon on wheels","artist":"Fire Arts Collective","hometown":"Portland, OR","url":null,"contact_email":null,"donation_link":null,"images":[],"tags":["Fire","Dragon"]}]
    """.data(using: .utf8)!
}

#endif
