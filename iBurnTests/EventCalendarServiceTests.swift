//
//  EventCalendarServiceTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
@preconcurrency @testable import iBurn
import PlayaDB
import YapDatabase
import Mantle

// MARK: - Spies

/// Stand-in for EventKit. Records every draft it is asked to create and every
/// identifier it is asked to remove, and models the three permission outcomes plus
/// iOS 17 write-only access (where events can be created but never read back).
private final class SpyEventStore: EventStoreProviding {

    private let lock = NSLock()
    private var _authorization: CalendarAuthorization
    private var _created: [(identifier: String, draft: CalendarEventDraft)] = []
    private var _removeAttempts: [String] = []
    private var _removed: [String] = []
    private var _live: Set<String> = []
    private var _ensureAccessCount = 0
    private var _nextIdentifier = 0

    init(authorization: CalendarAuthorization = .fullAccess) {
        _authorization = authorization
    }

    // MARK: Inspection

    var createdDrafts: [CalendarEventDraft] {
        lock.lock(); defer { lock.unlock() }
        return _created.map(\.draft)
    }

    var createdIdentifiers: [String] {
        lock.lock(); defer { lock.unlock() }
        return _created.map(\.identifier)
    }

    var removedIdentifiers: [String] {
        lock.lock(); defer { lock.unlock() }
        return _removed
    }

    var removeAttempts: [String] {
        lock.lock(); defer { lock.unlock() }
        return _removeAttempts
    }

    var ensureAccessCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _ensureAccessCount
    }

    /// Simulates the user deleting an event from the Calendar app.
    func deleteExternally(identifier: String) {
        lock.lock(); defer { lock.unlock() }
        _live.remove(identifier)
    }

    /// Registers an event that already exists in the calendar (e.g. one created by
    /// the legacy stack before this service shipped).
    func registerExisting(identifier: String) {
        lock.lock(); defer { lock.unlock() }
        _live.insert(identifier)
    }

    // MARK: EventStoreProviding

    var authorization: CalendarAuthorization {
        lock.lock(); defer { lock.unlock() }
        return _authorization
    }

    func ensureAccess() async -> Bool {
        recordEnsureAccess()
    }

    /// Kept synchronous so the lock is never held across an async boundary
    /// (`NSLock.lock()` is unavailable from async contexts in Swift 6).
    private func recordEnsureAccess() -> Bool {
        lock.lock(); defer { lock.unlock() }
        _ensureAccessCount += 1
        return _authorization.allowsWriting
    }

    func lookupEvent(identifier: String) -> CalendarEventLookup {
        lock.lock(); defer { lock.unlock() }
        guard _authorization.allowsReading else { return .unavailable }
        return _live.contains(identifier) ? .found : .notFound
    }

    func createEvent(_ draft: CalendarEventDraft) throws -> String {
        lock.lock(); defer { lock.unlock() }
        _nextIdentifier += 1
        let identifier = "ek-\(_nextIdentifier)"
        _created.append((identifier, draft))
        _live.insert(identifier)
        return identifier
    }

    @discardableResult
    func removeEvent(identifier: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        _removeAttempts.append(identifier)
        guard _authorization.allowsReading, _live.contains(identifier) else { return false }
        _live.remove(identifier)
        _removed.append(identifier)
        return true
    }
}

// MARK: - Tests

final class EventCalendarServiceTests: XCTestCase {

    private static let eventUID = "78ZvNxSeeZQbaeHuughD"
    private static let hostlessEventUID = "hostlessEvent000001"
    /// The two occurrence start instants from the fixture, rendered as PlayaDB
    /// calendar occurrence keys (ISO-8601 UTC).
    private static let occurrenceKeys = ["2026-08-31T19:00:00Z", "2026-09-01T19:00:00Z"]

    private var databaseHelper: BRCTestDatabaseHelper!
    private var connection: YapDatabaseConnection!
    private var playaDB: PlayaDB!
    private var store: SpyEventStore!

    override func setUp() {
        super.setUp()
        databaseHelper = BRCTestDatabaseHelper()
        databaseHelper.setUp()
        connection = databaseHelper.connection
        store = SpyEventStore()
    }

    override func tearDown() {
        store = nil
        playaDB = nil
        connection = nil
        databaseHelper.tearDown()
        databaseHelper = nil
        super.tearDown()
    }

    // MARK: Fixtures

    private func makePlayaDB() async throws -> PlayaDB {
        let db = try createInMemoryPlayaDB()
        try await db.importFromData(
            artData: Self.artJSON,
            campData: Self.campJSON,
            eventData: Self.eventJSON
        )
        playaDB = db
        return db
    }

    private func makeService(
        playaDB: PlayaDB,
        legacyIdentifierStore: LegacyCalendarIdentifierStore? = nil,
        embargoAllowsLocation: @escaping (EventObjectOccurrence) -> Bool = { _ in true }
    ) -> EventCalendarService {
        EventCalendarServiceFactory.makeService(
            playaDB: playaDB,
            eventStore: store,
            legacyIdentifierStore: legacyIdentifierStore,
            embargoAllowsLocation: embargoAllowsLocation
        )
    }

    /// Seeds the legacy per-occurrence Yap objects with EKEvent identifiers, the way an
    /// install that favorited the event before this service shipped would look.
    private func seedLegacyYapIdentifiers(_ identifiers: [String]) throws {
        for (index, identifier) in identifiers.enumerated() {
            let json: [String: Any] = [
                "uid": "\(Self.eventUID)-\(index)",
                "title": "Fairycore Tarot Meetup",
                "year": 2026
            ]
            let model = try MTLJSONAdapter.model(of: BRCEventObject.self, fromJSONDictionary: json)
            let event = try XCTUnwrap(model as? BRCEventObject)
            let metadata = try XCTUnwrap(BRCEventMetadata())
            metadata.isFavorite = true
            metadata.calendarEventIdentifier = identifier
            connection.readWrite { transaction in
                transaction.setObject(event,
                                      forKey: event.yapKey,
                                      inCollection: event.yapCollection,
                                      withMetadata: metadata)
            }
            store.registerExisting(identifier: identifier)
        }
    }

    private func legacyIdentifiersInYap() throws -> [String?] {
        var identifiers: [String?] = []
        connection.read { transaction in
            let collection = BRCEventObject.yapCollection
            let keys = FavoriteSyncServiceImpl.occurrenceKeys(
                from: transaction.allKeys(inCollection: collection),
                apiUID: Self.eventUID
            ).sorted()
            for key in keys {
                guard let event = transaction.object(forKey: key, inCollection: collection) as? BRCEventObject else {
                    continue
                }
                identifiers.append((event.metadata(with: transaction) as? BRCEventMetadata)?.calendarEventIdentifier)
            }
        }
        return identifiers
    }

    // MARK: - Favoriting

    func testFavoriteCreatesOneEventAndEntryPerOccurrence() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.createdIdentifiers.count, 2)
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.map(\.occurrenceKey), Self.occurrenceKeys)
        XCTAssertEqual(entries.map(\.ekEventIdentifier).sorted(), store.createdIdentifiers.sorted())
        XCTAssertTrue(entries.allSatisfy { $0.eventId == Self.eventUID })
    }

    func testCreatedDraftMatchesLegacyContent() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        let draft = try XCTUnwrap(store.createdDrafts.first)
        XCTAssertEqual(draft.title, "Fairycore Tarot Meetup")
        XCTAssertEqual(draft.notes, "Test event")
        XCTAssertEqual(draft.location, "Esplanade & 6:30 - Test Camp")
        XCTAssertEqual(draft.timeZone, TimeZone.burningManTimeZone)
        XCTAssertFalse(draft.isAllDay)
        // Legacy alarms: 1.5 hours and 10 minutes before the start.
        XCTAssertEqual(draft.alarmOffsets, [-90 * 60, -10 * 60])
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 90 * 60)
    }

    func testEmbargoHidesPlayaAddressButKeepsHostName() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db, embargoAllowsLocation: { _ in false })

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        let draft = try XCTUnwrap(store.createdDrafts.first)
        XCTAssertEqual(draft.location, "Test Camp")
    }

    func testHostlessEventFallsBackToOtherLocation() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.hostlessEventUID, isFavorite: true)

        let draft = try XCTUnwrap(store.createdDrafts.first)
        XCTAssertEqual(draft.location, "Center Camp Plaza")
    }

    func testRepeatedFavoriteDoesNotDuplicate() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.createdIdentifiers.count, 2, "Re-favoriting must not create extra EKEvents")
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.count, 2)
    }

    /// The legacy favorite hook fires once per Yap occurrence key, so the same event
    /// arrives several times in a row. Concurrent identical passes must coalesce.
    func testConcurrentIdenticalReconcilesCoalesce() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { await service.reconcile(eventUID: Self.eventUID, isFavorite: true) }
            }
        }

        XCTAssertEqual(store.createdIdentifiers.count, 2)
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.count, 2)
    }

    func testManuallyDeletedEventIsRecreated() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        let firstIdentifier = try XCTUnwrap(store.createdIdentifiers.first)
        store.deleteExternally(identifier: firstIdentifier)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.createdIdentifiers.count, 3, "Only the deleted occurrence should be recreated")
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.count, 2, "The recreated entry must replace the stale row, not add one")
        let identifiers = Set(entries.map(\.ekEventIdentifier))
        XCTAssertFalse(identifiers.contains(firstIdentifier))
        XCTAssertTrue(identifiers.contains(try XCTUnwrap(store.createdIdentifiers.last)))
    }

    func testUnknownEventIsNoOp() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: "not-a-real-event", isFavorite: true)

        XCTAssertTrue(store.createdIdentifiers.isEmpty)
        let entries = try await db.fetchCalendarEntries(eventId: "not-a-real-event")
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - Unfavoriting

    func testUnfavoriteRemovesEventsAndEntries() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        let created = store.createdIdentifiers

        await service.reconcile(eventUID: Self.eventUID, isFavorite: false)

        XCTAssertEqual(store.removedIdentifiers.sorted(), created.sorted())
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertTrue(entries.isEmpty)
    }

    func testUnfavoriteThenFavoriteCreatesFreshEvents() async throws {
        let db = try await makePlayaDB()
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: false)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.createdIdentifiers.count, 4)
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map(\.ekEventIdentifier)), Set(store.createdIdentifiers.suffix(2)))
    }

    // MARK: - Permissions

    func testDeniedPermissionWritesNothing() async throws {
        let db = try await makePlayaDB()
        store = SpyEventStore(authorization: .denied)
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.ensureAccessCount, 1)
        XCTAssertTrue(store.createdIdentifiers.isEmpty)
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertTrue(entries.isEmpty)
    }

    func testUndeterminedPermissionWritesNothing() async throws {
        let db = try await makePlayaDB()
        store = SpyEventStore(authorization: .notDetermined)
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: false)

        XCTAssertTrue(store.createdIdentifiers.isEmpty)
        XCTAssertTrue(store.removeAttempts.isEmpty)
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertTrue(entries.isEmpty)
    }

    /// Write-only access (iOS 17+) cannot read events back, so bookkeeping must be
    /// trusted rather than treated as "the user deleted it".
    func testWriteOnlyAccessTrustsStoredEntries() async throws {
        let db = try await makePlayaDB()
        store = SpyEventStore(authorization: .writeOnly)
        let service = makeService(playaDB: db)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.createdIdentifiers.count, 2, "Unverifiable events must not be recreated")
    }

    func testEKEventStoreProviderGatesOnAuthorization() async {
        var promptCount = 0
        let provider = EKEventStoreProvider(prompt: { promptCount += 1 })
        let granted = await provider.ensureAccess()

        switch provider.authorization {
        case .notDetermined:
            XCTAssertFalse(granted)
            XCTAssertEqual(promptCount, 1, "An undetermined status must prompt exactly once")
        case .denied:
            XCTAssertFalse(granted)
            XCTAssertEqual(promptCount, 0)
        case .writeOnly, .fullAccess:
            XCTAssertTrue(granted)
            XCTAssertEqual(promptCount, 0)
        }
    }

    // MARK: - Legacy Yap Takeover

    func testUnfavoriteRemovesLegacyYapBookkeptEvents() async throws {
        let db = try await makePlayaDB()
        try seedLegacyYapIdentifiers(["legacy-0", "legacy-1"])
        let legacyStore = YapLegacyCalendarIdentifierStore(connection: connection)
        let service = makeService(playaDB: db, legacyIdentifierStore: legacyStore)

        // PlayaDB has no entries: everything in the calendar came from the legacy stack.
        await service.reconcile(eventUID: Self.eventUID, isFavorite: false)

        XCTAssertEqual(store.removedIdentifiers.sorted(), ["legacy-0", "legacy-1"])
        XCTAssertEqual(try legacyIdentifiersInYap(), [nil, nil], "Yap identifiers must be cleared")
    }

    func testFavoriteTakesOverLegacyEventsInsteadOfDuplicating() async throws {
        let db = try await makePlayaDB()
        try seedLegacyYapIdentifiers(["legacy-0", "legacy-1"])
        let legacyStore = YapLegacyCalendarIdentifierStore(connection: connection)
        let service = makeService(playaDB: db, legacyIdentifierStore: legacyStore)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.removedIdentifiers.sorted(), ["legacy-0", "legacy-1"])
        XCTAssertEqual(store.createdIdentifiers.count, 2, "One fresh EKEvent per occurrence")
        XCTAssertEqual(try legacyIdentifiersInYap(), [nil, nil])
        let entries = try await db.fetchCalendarEntries(eventId: Self.eventUID)
        XCTAssertEqual(entries.count, 2)
    }

    func testTakeoverDoesNotRunOnceEntriesAreOwnedByPlayaDB() async throws {
        let db = try await makePlayaDB()
        try seedLegacyYapIdentifiers(["legacy-0", "legacy-1"])
        let legacyStore = YapLegacyCalendarIdentifierStore(connection: connection)
        let service = makeService(playaDB: db, legacyIdentifierStore: legacyStore)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)
        let removalsAfterTakeover = store.removeAttempts.count
        await service.reconcile(eventUID: Self.eventUID, isFavorite: true)

        XCTAssertEqual(store.removeAttempts.count, removalsAfterTakeover,
                       "The Yap takeover is one-way; it must not repeat once PlayaDB owns the entries")
    }

    func testTakeoverIsSkippedWithoutLegacyStore() async throws {
        let db = try await makePlayaDB()
        try seedLegacyYapIdentifiers(["legacy-0", "legacy-1"])
        let service = makeService(playaDB: db, legacyIdentifierStore: nil)

        await service.reconcile(eventUID: Self.eventUID, isFavorite: false)

        XCTAssertTrue(store.removeAttempts.isEmpty)
        XCTAssertEqual(try legacyIdentifiersInYap(), ["legacy-0", "legacy-1"])
    }

    // MARK: - Hook Routing (feature flag)

    func testHookRoutesToPlayaDBServiceWhenFlagIsOn() {
        var reconciled: [(String, Bool)] = []
        var legacyCalls: [String] = []
        let hook = EventCalendarHookRouter.makeCalendarRefreshHook(
            isPlayaDBSyncEnabled: { true },
            playaDBReconcile: { uid, isFavorite in reconciled.append((uid, isFavorite)) },
            legacyRefresh: { uid, _ in legacyCalls.append(uid) }
        )

        hook("\(Self.eventUID)-0", true)
        hook("\(Self.eventUID)-12", false)

        XCTAssertTrue(legacyCalls.isEmpty)
        XCTAssertEqual(reconciled.map(\.0), [Self.eventUID, Self.eventUID],
                       "Per-occurrence Yap uids must be normalized to the API uid")
        XCTAssertEqual(reconciled.map(\.1), [true, false])
    }

    func testHookRoutesToLegacyWhenFlagIsOff() {
        var reconciled: [String] = []
        var legacyCalls: [(String, Bool)] = []
        let hook = EventCalendarHookRouter.makeCalendarRefreshHook(
            isPlayaDBSyncEnabled: { false },
            playaDBReconcile: { uid, _ in reconciled.append(uid) },
            legacyRefresh: { uid, isFavorite in legacyCalls.append((uid, isFavorite)) }
        )

        hook("\(Self.eventUID)-0", true)

        XCTAssertTrue(reconciled.isEmpty)
        XCTAssertEqual(legacyCalls.map(\.0), ["\(Self.eventUID)-0"],
                       "The legacy hook keeps the raw per-occurrence uid")
        XCTAssertEqual(legacyCalls.map(\.1), [true])
    }

    func testFeatureFlagDefaultsToPlayaDBSync() {
        XCTAssertEqual(Preferences.FeatureFlags.usePlayaDBCalendarSync.key, "featureFlag.calendar.usePlayaDB")
        XCTAssertTrue(Preferences.FeatureFlags.usePlayaDBCalendarSync.defaultValue)
    }

    // MARK: - Inline PlayaDB Fixtures (minimal PlayaAPI-format JSON)

    private static let artJSON = Data("""
    [{"uid":"a2IVI000000yWeZ2AU","name":"Burning Questions","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test art","artist":"Jane Smith","category":"Open Playa","program":"Honorarium","donation_link":null,"location":{"hour":12,"minute":0,"distance":2500,"category":"Open Playa","gps_latitude":40.79179890754886,"gps_longitude":-119.1976993927176},"location_string":"12:00 2500', Open Playa","images":[],"guided_tours":false,"self_guided_tour_map":false}]
    """.utf8)

    private static let campJSON = Data("""
    [{"uid":"a1XVI000008zSaf2AE","name":"Test Camp","year":2026,"url":null,"contact_email":null,"hometown":null,"description":"Test camp","landmark":null,"location":{"frontage":"Esplanade","intersection":"6:30","intersection_type":"&","dimensions":"75 x 110","exact_location":null},"location_string":"Esplanade & 6:30","images":[]}]
    """.utf8)

    /// Two events: one camp-hosted with two occurrences (the calendar fan-out case)
    /// and one with no host but an `other_location` string.
    private static let eventJSON = Data("""
    [{"uid":"78ZvNxSeeZQbaeHuughD","title":"Fairycore Tarot Meetup","event_id":51138,"description":"Test event","event_type":{"label":"Class/Workshop","abbr":"work"},"year":2026,"print_description":"","slug":"78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup","hosted_by_camp":"a1XVI000008zSaf2AE","located_at_art":null,"other_location":"","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-08-31T12:00:00-07:00","end_time":"2026-08-31T13:30:00-07:00"},{"start_time":"2026-09-01T12:00:00-07:00","end_time":"2026-09-01T13:30:00-07:00"}]},
     {"uid":"hostlessEvent000001","title":"Sunrise Set","event_id":51139,"description":"No host","event_type":{"label":"Music/Party","abbr":"prty"},"year":2026,"print_description":"","slug":"hostlessEvent000001-sunrise-set","hosted_by_camp":null,"located_at_art":null,"other_location":"Center Camp Plaza","check_location":false,"url":null,"all_day":false,"contact":null,"occurrence_set":[{"start_time":"2026-09-02T05:00:00-07:00","end_time":"2026-09-02T07:00:00-07:00"}]}]
    """.utf8)
}
