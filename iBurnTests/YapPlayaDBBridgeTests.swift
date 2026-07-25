//
//  YapPlayaDBBridgeTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Regression coverage for the Yap ⇄ PlayaDB bridge fixes from the 2026-07-25 audit:
//   * legacy cell hearts writing PlayaDB with a per-occurrence Yap uid (silent no-op)
//   * detail-screen notes writing PlayaDB uids into per-occurrence Yap keys (silent no-op)
//   * the visit-status mirror not regrouping the legacy Visit List
//   * the embargo-cleared notification that live-refreshes PlayaDB-backed UI
//

import XCTest
@preconcurrency @testable import iBurn
import PlayaDB
import YapDatabase
import Mantle

final class YapPlayaDBBridgeTests: XCTestCase {

    private var databaseHelper: BRCTestDatabaseHelper!
    private var connection: YapDatabaseConnection!

    override func setUp() {
        super.setUp()
        databaseHelper = BRCTestDatabaseHelper()
        databaseHelper.setUp()
        connection = databaseHelper.connection
    }

    override func tearDown() {
        connection = nil
        databaseHelper.tearDown()
        databaseHelper = nil
        super.tearDown()
    }

    // MARK: - Builders

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

    /// Builds a BRCEventObject with an already-occurrence-suffixed uid, matching what
    /// `BRCRecurringEventObject.eventObjects()` produces at import time.
    private func makeEvent(uid: String) throws -> BRCEventObject {
        let json: [String: Any] = ["uid": uid, "title": "Test Event", "year": 2026]
        let model = try MTLJSONAdapter.model(of: BRCEventObject.self, fromJSONDictionary: json)
        return try XCTUnwrap(model as? BRCEventObject)
    }

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

    private func saveArt(uid: String, notes: String? = nil) throws {
        let metadata = try XCTUnwrap(BRCArtMetadata())
        metadata.userNotes = notes
        save(try makeArt(uid: uid), metadata: metadata)
    }

    private func saveCamp(uid: String, notes: String? = nil, visitStatus: Int = 0) throws {
        let metadata = try XCTUnwrap(BRCCampMetadata())
        metadata.userNotes = notes
        metadata.visitStatus = visitStatus
        save(try makeCamp(uid: uid), metadata: metadata)
    }

    private func saveEvent(uid: String, notes: String? = nil, visitStatus: Int = 0) throws {
        let metadata = try XCTUnwrap(BRCEventMetadata())
        metadata.userNotes = notes
        metadata.visitStatus = visitStatus
        save(try makeEvent(uid: uid), metadata: metadata)
    }

    private func metadataInYap(uid: String, collection: String) throws -> BRCObjectMetadata {
        var result: BRCObjectMetadata?
        connection.read { transaction in
            guard let object = transaction.object(forKey: uid, inCollection: collection) as? BRCDataObject else {
                return
            }
            result = object.metadata(with: transaction)
        }
        return try XCTUnwrap(result, "No object found for \(uid) in \(collection)")
    }

    private func notesInYap(uid: String, collection: String) throws -> String? {
        try metadataInYap(uid: uid, collection: collection).userNotes
    }

    private func makeService(
        visitStatusDidChangeHook: @escaping FavoriteSyncVisitStatusDidChangeHook = {}
    ) -> FavoriteSyncService {
        FavoriteSyncServiceFactory.makeService(
            connection: connection,
            calendarRefreshHook: { _, _ in },
            visitStatusDidChangeHook: visitStatusDidChangeHook
        )
    }

    // MARK: - Legacy Cell UID Normalization (BRCDataObjectTableViewCell)

    /// The legacy cell heart dual-writes PlayaDB. Yap events are stored per occurrence
    /// ("<apiUID>-<index>"); passing that uid to `fetchEvent(uid:)` returns nil, so the
    /// PlayaDB write silently disappeared.
    func testCellPlayaDBUIDStripsOccurrenceSuffixForEventsOnly() throws {
        let event = try makeEvent(uid: "78ZvNxSeeZQbaeHuughD-3")
        XCTAssertEqual(BRCDataObjectTableViewCell.playaDBUID(for: event), "78ZvNxSeeZQbaeHuughD")

        let unsuffixedEvent = try makeEvent(uid: "78ZvNxSeeZQbaeHuughD")
        XCTAssertEqual(BRCDataObjectTableViewCell.playaDBUID(for: unsuffixedEvent), "78ZvNxSeeZQbaeHuughD")

        // Art/camp uids are identical in both databases and must not be rewritten, even
        // when they happen to end in "-<digits>".
        let art = try makeArt(uid: "art-123")
        XCTAssertEqual(BRCDataObjectTableViewCell.playaDBUID(for: art), "art-123")

        let camp = try makeCamp(uid: "camp-456")
        XCTAssertEqual(BRCDataObjectTableViewCell.playaDBUID(for: camp), "camp-456")
    }

    /// End-to-end proof against a real PlayaDB: the raw Yap uid misses, the normalized one
    /// resolves and can be favorited (which is what the cell's heart does).
    @MainActor
    func testCellPlayaDBUIDResolvesEventInPlayaDB() async throws {
        let playaDB = try createInMemoryPlayaDB()
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )

        let yapEvent = try makeEvent(uid: "78ZvNxSeeZQbaeHuughD-0")
        let missing = try await playaDB.fetchEvent(uid: yapEvent.uniqueID)
        XCTAssertNil(missing)

        let normalized = BRCDataObjectTableViewCell.playaDBUID(for: yapEvent)
        let fetched = try await playaDB.fetchEvent(uid: normalized)
        let event = try XCTUnwrap(fetched)
        try await playaDB.setFavorite(true, for: event)
        let isFavorite = try await playaDB.isFavorite(event)
        XCTAssertTrue(isFavorite)
    }

    // MARK: - Notes Mirroring (FavoriteSyncService.mirrorNotes)

    func testArtAndCampNotesMirrorToYap() async throws {
        try saveArt(uid: "art-123")
        try saveCamp(uid: "camp-456")
        let service = makeService()

        await service.mirrorNotes(type: .art, uid: "art-123", notes: "bring goggles")
        await service.mirrorNotes(type: .camp, uid: "camp-456", notes: "free coffee at 9")

        XCTAssertEqual(try notesInYap(uid: "art-123", collection: BRCArtObject.yapCollection), "bring goggles")
        XCTAssertEqual(try notesInYap(uid: "camp-456", collection: BRCCampObject.yapCollection), "free coffee at 9")
    }

    /// The bug: `syncNotesToYapDB` wrote the bare PlayaDB uid into
    /// `BRCEventObject.yapCollection`, which never matches a per-occurrence key.
    func testEventNotesFanOutToAllOccurrences() async throws {
        try saveEvent(uid: "event-abc-0")
        try saveEvent(uid: "event-abc-1")
        try saveEvent(uid: "event-abc-10")
        // Non-matching neighbors that must NOT be touched
        try saveEvent(uid: "event-abcd-0")   // different API uid
        try saveEvent(uid: "event-abc-x")    // non-numeric suffix
        let service = makeService()

        await service.mirrorNotes(type: .event, uid: "event-abc", notes: "meet at the gate")

        let collection = BRCEventObject.yapCollection
        XCTAssertEqual(try notesInYap(uid: "event-abc-0", collection: collection), "meet at the gate")
        XCTAssertEqual(try notesInYap(uid: "event-abc-1", collection: collection), "meet at the gate")
        XCTAssertEqual(try notesInYap(uid: "event-abc-10", collection: collection), "meet at the gate")
        XCTAssertNil(try notesInYap(uid: "event-abcd-0", collection: collection))
        XCTAssertNil(try notesInYap(uid: "event-abc-x", collection: collection))
    }

    func testEventNotesClearedWithEmptyString() async throws {
        try saveEvent(uid: "event-abc-0", notes: "old note")
        try saveEvent(uid: "event-abc-1", notes: "old note")
        let service = makeService()

        await service.mirrorNotes(type: .event, uid: "event-abc", notes: "")

        let collection = BRCEventObject.yapCollection
        XCTAssertEqual(try notesInYap(uid: "event-abc-0", collection: collection), "")
        XCTAssertEqual(try notesInYap(uid: "event-abc-1", collection: collection), "")
    }

    func testNotesMirrorSkipsEqualValueWrites() async throws {
        try saveCamp(uid: "camp-456", notes: "same")
        try saveEvent(uid: "event-abc-0", notes: "same")
        let service = makeService()

        // Yap only bumps the connection snapshot when a commit has disk changes, so an
        // unchanged snapshot proves the equal-value path skipped the write entirely.
        let snapshotBefore = connection.snapshot
        await service.mirrorNotes(type: .camp, uid: "camp-456", notes: "same")
        await service.mirrorNotes(type: .event, uid: "event-abc", notes: "same")
        XCTAssertEqual(connection.snapshot, snapshotBefore, "Equal-value notes mirror must not write to Yap")

        // Positive control: a differing value must produce a real commit.
        await service.mirrorNotes(type: .camp, uid: "camp-456", notes: "changed")
        XCTAssertGreaterThan(connection.snapshot, snapshotBefore)
        XCTAssertEqual(try notesInYap(uid: "camp-456", collection: BRCCampObject.yapCollection), "changed")
    }

    func testNotesMirrorForUnknownUIDAndMutantVehicleIsSafeNoOp() async throws {
        try saveCamp(uid: "mv-999")
        let service = makeService()

        await service.mirrorNotes(type: .art, uid: "does-not-exist", notes: "x")
        await service.mirrorNotes(type: .event, uid: "does-not-exist", notes: "x")
        // Mutant vehicles have no Yap class; a same-uid camp must stay untouched.
        await service.mirrorNotes(type: .mutantVehicle, uid: "mv-999", notes: "x")

        XCTAssertNil(try notesInYap(uid: "mv-999", collection: BRCCampObject.yapCollection))
    }

    // MARK: - Visit Status Regroup Hook

    /// The legacy Visit List renders from a grouped view whose grouping block only re-runs on
    /// a versionTag bump (`refreshVisitStatusGroupedView`); without it rows stay in their old
    /// group after a PlayaDB-side change.
    func testVisitStatusMirrorTriggersRegroupAfterCommit() async throws {
        try saveCamp(uid: "camp-456")
        try saveEvent(uid: "event-abc-0")

        let recorder = HookRecorder()
        let service = makeService(visitStatusDidChangeHook: { recorder.record() })

        await service.mirrorVisitStatus(type: .camp, uid: "camp-456", visitStatus: BRCVisitStatus.wantToVisit.rawValue)
        XCTAssertEqual(recorder.count, 1)

        await service.mirrorVisitStatus(type: .event, uid: "event-abc", visitStatus: BRCVisitStatus.visited.rawValue)
        XCTAssertEqual(recorder.count, 2)
    }

    func testVisitStatusRegroupSkippedWhenNothingChanged() async throws {
        try saveCamp(uid: "camp-456", visitStatus: BRCVisitStatus.visited.rawValue)
        try saveEvent(uid: "event-abc-0", visitStatus: BRCVisitStatus.visited.rawValue)

        let recorder = HookRecorder()
        let service = makeService(visitStatusDidChangeHook: { recorder.record() })

        // Equal values: no Yap write, so no grouped-view churn either.
        await service.mirrorVisitStatus(type: .camp, uid: "camp-456", visitStatus: BRCVisitStatus.visited.rawValue)
        await service.mirrorVisitStatus(type: .event, uid: "event-abc", visitStatus: BRCVisitStatus.visited.rawValue)
        // Unknown uid: nothing to write.
        await service.mirrorVisitStatus(type: .art, uid: "does-not-exist", visitStatus: BRCVisitStatus.visited.rawValue)
        // Mutant vehicles have no Yap representation at all.
        await service.mirrorVisitStatus(type: .mutantVehicle, uid: "camp-456", visitStatus: BRCVisitStatus.wantToVisit.rawValue)

        XCTAssertEqual(recorder.count, 0)
    }

    // MARK: - Embargo Notification

    func testEmbargoNotifierPostsDidClearNotification() {
        let expectation = expectation(forNotification: .BRCEmbargoDidClear, object: nil, handler: nil)
        BRCEmbargoNotifier.postDidClear()
        wait(for: [expectation], timeout: 2)
    }

    func testEmbargoNotificationNameMatchesObjCConstant() {
        XCTAssertEqual(Notification.Name.BRCEmbargoDidClear.rawValue,
                       BRCEmbargoNotifier.didClearNotificationName)
    }

    // MARK: - Helpers

    /// Thread-safe counter for the injected visit-status hook.
    private final class HookRecorder {
        private let lock = NSLock()
        private var _count = 0

        var count: Int {
            lock.lock(); defer { lock.unlock() }
            return _count
        }

        func record() {
            lock.lock(); defer { lock.unlock() }
            _count += 1
        }
    }

    // MARK: - Inline PlayaDB Fixtures (minimal PlayaAPI-format JSON)

    private static let artJSON = """
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test art","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":null,"location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.data(using: .utf8) ?? Data()

    private static let campJSON = """
    [{"uid":"a1XVI000008zSaf2AE","name":"Test Camp","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test camp","landmark":null,"location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":null},"location_string":"Esplanade & 6:30","images":[]}]
    """.data(using: .utf8) ?? Data()

    private static let eventJSON = """
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"Test event","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000008zSaf2AE","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T12:00:00-07:00","end_time":"2026-08-31T13:30:00-07:00"}]}]
    """.data(using: .utf8) ?? Data()
}
