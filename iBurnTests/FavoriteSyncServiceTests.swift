//
//  FavoriteSyncServiceTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/11/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@preconcurrency @testable import iBurn
import PlayaDB
import YapDatabase
import Mantle

/// Thread-safe spy that stands in for the EventKit calendar refresh hook.
/// The real hook (`BRCEventObject.refreshCalendarEntry`) needs calendar
/// entitlements, so tests verify the hook is invoked instead of asserting
/// on actual EKEvents. At call time the spy re-reads the committed Yap state,
/// verifying the metadata write lands before the hook fires (the ordering
/// `refreshCalendarEntry` depends on).
private final class CalendarRefreshSpy {
    struct Call {
        let uniqueID: String
        let isFavoriteAtCallTime: Bool
    }

    private let lock = NSLock()
    private var _calls: [Call] = []
    private let connection: YapDatabaseConnection

    init(connection: YapDatabaseConnection) {
        self.connection = connection
    }

    var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return _calls
    }

    func record(yapUID: String) {
        var committedFavorite = false
        connection.read { transaction in
            if let event = transaction.object(forKey: yapUID, inCollection: BRCEventObject.yapCollection) as? BRCEventObject {
                committedFavorite = event.metadata(with: transaction).isFavorite
            }
        }
        let call = Call(uniqueID: yapUID, isFavoriteAtCallTime: committedFavorite)
        lock.lock(); defer { lock.unlock() }
        _calls.append(call)
    }
}

final class FavoriteSyncServiceTests: XCTestCase {

    private var databaseHelper: BRCTestDatabaseHelper!
    private var connection: YapDatabaseConnection!
    private var calendarSpy: CalendarRefreshSpy!
    private var service: FavoriteSyncService!

    override func setUp() {
        super.setUp()
        databaseHelper = BRCTestDatabaseHelper()
        databaseHelper.setUp()
        let connection: YapDatabaseConnection = databaseHelper.connection
        self.connection = connection
        let spy = CalendarRefreshSpy(connection: connection)
        calendarSpy = spy
        service = FavoriteSyncServiceFactory.makeService(connection: connection) { yapUID, _ in
            spy.record(yapUID: yapUID)
        }
    }

    override func tearDown() {
        service = nil
        calendarSpy = nil
        connection = nil
        databaseHelper.tearDown()
        databaseHelper = nil
        super.tearDown()
    }

    // MARK: - Object Builders

    private func makeArt(uid: String) throws -> BRCArtObject {
        let json: [String: Any] = ["uid": uid, "name": "Test Art", "year": 2026]
        let model = try MTLJSONAdapter.model(of: BRCArtObject.self, fromJSONDictionary: json)
        return try XCTUnwrap(model as? BRCArtObject)
    }

    private func makeCamp(uid: String) throws -> BRCCampObject {
        let json: [String: Any] = ["uid": uid, "name": "Test Camp", "year": 2026]
        let model = try MTLJSONAdapter.model(of: BRCCampObject.self, fromJSONDictionary: json)
        return try XCTUnwrap(model as? BRCCampObject)
    }

    /// Builds a BRCEventObject with an explicit (already occurrence-suffixed) uid,
    /// matching what `BRCRecurringEventObject.eventObjects()` produces at import time.
    private func makeEvent(uid: String) throws -> BRCEventObject {
        let json: [String: Any] = ["uid": uid, "title": "Test Event", "year": 2026]
        let model = try MTLJSONAdapter.model(of: BRCEventObject.self, fromJSONDictionary: json)
        return try XCTUnwrap(model as? BRCEventObject)
    }

    // MARK: - Yap Helpers

    private func save(_ object: BRCDataObject, metadata: BRCObjectMetadata) {
        connection.readWrite { transaction in
            transaction.setObject(
                object,
                forKey: object.yapKey,
                inCollection: object.yapCollection,
                withMetadata: metadata
            )
        }
    }

    private func saveArt(uid: String, isFavorite: Bool = false) throws {
        let metadata = try XCTUnwrap(BRCObjectMetadata())
        metadata.isFavorite = isFavorite
        save(try makeArt(uid: uid), metadata: metadata)
    }

    private func saveCamp(uid: String, isFavorite: Bool = false) throws {
        let metadata = try XCTUnwrap(BRCObjectMetadata())
        metadata.isFavorite = isFavorite
        save(try makeCamp(uid: uid), metadata: metadata)
    }

    private func saveEvent(uid: String, isFavorite: Bool = false) throws {
        let metadata = try XCTUnwrap(BRCEventMetadata())
        metadata.isFavorite = isFavorite
        save(try makeEvent(uid: uid), metadata: metadata)
    }

    private func isFavoriteInYap(uid: String, collection: String) throws -> Bool {
        var result: Bool?
        connection.read { transaction in
            guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                return
            }
            result = object.metadata(with: transaction).isFavorite
        }
        return try XCTUnwrap(result, "No object found for \(uid) in \(collection)")
    }

    // MARK: - Art / Camp Mirroring

    func testArtFavoriteMirrorsToYap() async throws {
        try saveArt(uid: "art-123")

        await service.mirrorFavorite(type: .art, uid: "art-123", isFavorite: true)
        XCTAssertTrue(try isFavoriteInYap(uid: "art-123", collection: BRCArtObject.yapCollection))

        await service.mirrorFavorite(type: .art, uid: "art-123", isFavorite: false)
        XCTAssertFalse(try isFavoriteInYap(uid: "art-123", collection: BRCArtObject.yapCollection))
    }

    func testCampFavoriteMirrorsToYap() async throws {
        try saveCamp(uid: "camp-456")

        await service.mirrorFavorite(type: .camp, uid: "camp-456", isFavorite: true)
        XCTAssertTrue(try isFavoriteInYap(uid: "camp-456", collection: BRCCampObject.yapCollection))

        await service.mirrorFavorite(type: .camp, uid: "camp-456", isFavorite: false)
        XCTAssertFalse(try isFavoriteInYap(uid: "camp-456", collection: BRCCampObject.yapCollection))
    }

    func testMirrorMissingObjectIsSafeNoOp() async throws {
        // No object stored; mirroring must complete without crashing or inserting.
        await service.mirrorFavorite(type: .art, uid: "does-not-exist", isFavorite: true)
        connection.read { transaction in
            XCTAssertNil(transaction.object(forKey: "does-not-exist", inCollection: BRCArtObject.yapCollection))
        }
    }

    // MARK: - Event Fan-Out

    func testEventFavoriteSetsAllOccurrenceObjects() async throws {
        let apiUID = "event-abc"
        // Matching per-occurrence objects, including a two-digit index
        try saveEvent(uid: "event-abc-0")
        try saveEvent(uid: "event-abc-1")
        try saveEvent(uid: "event-abc-10")
        // Non-matching neighbors that must NOT be touched
        try saveEvent(uid: "event-abcd-0")   // different API uid
        try saveEvent(uid: "event-abc-x")    // non-numeric suffix

        await service.mirrorFavorite(type: .event, uid: apiUID, isFavorite: true)

        let collection = BRCEventObject.yapCollection
        XCTAssertTrue(try isFavoriteInYap(uid: "event-abc-0", collection: collection))
        XCTAssertTrue(try isFavoriteInYap(uid: "event-abc-1", collection: collection))
        XCTAssertTrue(try isFavoriteInYap(uid: "event-abc-10", collection: collection))
        XCTAssertFalse(try isFavoriteInYap(uid: "event-abcd-0", collection: collection))
        XCTAssertFalse(try isFavoriteInYap(uid: "event-abc-x", collection: collection))
    }

    func testEventUnfavoriteClearsAllOccurrenceObjects() async throws {
        let apiUID = "event-abc"
        try saveEvent(uid: "event-abc-0", isFavorite: true)
        try saveEvent(uid: "event-abc-1", isFavorite: true)

        await service.mirrorFavorite(type: .event, uid: apiUID, isFavorite: false)

        let collection = BRCEventObject.yapCollection
        XCTAssertFalse(try isFavoriteInYap(uid: "event-abc-0", collection: collection))
        XCTAssertFalse(try isFavoriteInYap(uid: "event-abc-1", collection: collection))
    }

    // MARK: - Calendar Refresh Hook

    func testCalendarRefreshHookInvokedForEachOccurrence() async throws {
        try saveEvent(uid: "event-abc-0")
        try saveEvent(uid: "event-abc-1")
        try saveEvent(uid: "event-abcd-0") // must not trigger the hook

        await service.mirrorFavorite(type: .event, uid: "event-abc", isFavorite: true)

        let calls = calendarSpy.calls
        XCTAssertEqual(Set(calls.map(\.uniqueID)), ["event-abc-0", "event-abc-1"])
        // The hook must observe the *new* favorite state (metadata replaced first),
        // matching what refreshCalendarEntry needs to create/remove EKEvents.
        XCTAssertTrue(calls.allSatisfy(\.isFavoriteAtCallTime))
    }

    func testCalendarRefreshHookObservesUnfavorite() async throws {
        try saveEvent(uid: "event-abc-0", isFavorite: true)

        await service.mirrorFavorite(type: .event, uid: "event-abc", isFavorite: false)

        let calls = calendarSpy.calls
        XCTAssertEqual(calls.map(\.uniqueID), ["event-abc-0"])
        XCTAssertFalse(try XCTUnwrap(calls.first).isFavoriteAtCallTime)
    }

    func testCalendarRefreshHookNotInvokedForArtOrCamp() async throws {
        try saveArt(uid: "art-123")
        try saveCamp(uid: "camp-456")

        await service.mirrorFavorite(type: .art, uid: "art-123", isFavorite: true)
        await service.mirrorFavorite(type: .camp, uid: "camp-456", isFavorite: true)

        XCTAssertTrue(calendarSpy.calls.isEmpty)
    }

    // MARK: - Mutant Vehicles

    func testMutantVehicleMirrorIsNoOp() async throws {
        // MVs have no legacy Yap class. Store same-uid objects in the other
        // collections to prove the MV path doesn't leak into them.
        try saveArt(uid: "mv-999")
        try saveEvent(uid: "mv-999-0")

        await service.mirrorFavorite(type: .mutantVehicle, uid: "mv-999", isFavorite: true)

        XCTAssertFalse(try isFavoriteInYap(uid: "mv-999", collection: BRCArtObject.yapCollection))
        XCTAssertFalse(try isFavoriteInYap(uid: "mv-999-0", collection: BRCEventObject.yapCollection))
        XCTAssertTrue(calendarSpy.calls.isEmpty)
    }

    // MARK: - Event UID Normalization

    func testAPIEventUIDStripsOccurrenceSuffix() {
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "abc-0"), "abc")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "abc-12"), "abc")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "a-b-2"), "a-b")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "78ZvNxSeeZQbaeHuughD-3"), "78ZvNxSeeZQbaeHuughD")
    }

    func testAPIEventUIDLeavesNonSuffixedUIDsAlone() {
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "abc"), "abc")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "abc-x1"), "abc-x1")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: "abc-"), "abc-")
        XCTAssertEqual(FavoriteSyncServiceImpl.apiEventUID(fromYapUID: ""), "")
    }

    // MARK: - Suffix-Stripped PlayaDB Lookup

    /// Reproduces the DetailDataService.syncFavoriteToPlayaDB scenario: a Yap
    /// per-occurrence uid ("<apiUID>-<index>") must be normalized to the API uid
    /// before the PlayaDB lookup, otherwise fetchEvent silently returns nil.
    func testSuffixStrippedUIDResolvesEventInPlayaDB() async throws {
        let playaDB = try createInMemoryPlayaDB()
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )

        let apiUID = "78ZvNxSeeZQbaeHuughD"
        let yapUID = apiUID + "-0"

        // The raw suffixed uid does not resolve (this was the silent failure)
        let missing = try await playaDB.fetchEvent(uid: yapUID)
        XCTAssertNil(missing)

        // The normalized uid resolves and can be favorited
        let normalized = FavoriteSyncServiceImpl.apiEventUID(fromYapUID: yapUID)
        XCTAssertEqual(normalized, apiUID)
        let fetched = try await playaDB.fetchEvent(uid: normalized)
        let event = try XCTUnwrap(fetched)
        try await playaDB.setFavorite(true, for: event)
        let isFavorite = try await playaDB.isFavorite(event)
        XCTAssertTrue(isFavorite)
    }

    // MARK: - Inline PlayaDB Fixtures (minimal PlayaAPI-format JSON)

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test art","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":null,"location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.data(using: .utf8)!

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Test Camp","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test camp","landmark":null,"location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":null},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8)!

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"Test event","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000008zSaf2AE","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T12:00:00-07:00","end_time":"2026-08-31T13:30:00-07:00"}]}]
    """.data(using: .utf8)!
}
