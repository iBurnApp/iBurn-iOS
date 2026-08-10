import XCTest
import Foundation
import GRDB
@testable import PlayaDB
import PlayaAPITestHelpers

/// Favoriting one showing of a recurring event favorites *that showing only*.
///
/// Covers the identity scheme (``EventFavoriteKey``), the legacy parent-uid fallback that
/// keeps pre-existing favorites lit, the open-time fold that promotes those into explicit
/// rows, and every read surface that has to agree with all of it.
final class PerOccurrenceFavoriteTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    private var dbQueue: any DatabaseWriter { playaDB.dbQueue }

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "PerOccurrenceFavoriteTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: Self.recurringEventJSON
        )
    }

    /// `MockAPIData.eventJSON` has a single one-off event, which can't express any of this.
    /// This adds a three-morning workshop — the shape the whole feature exists for — next
    /// to a one-off, so "only the tapped showing" is actually observable.
    static let recurringEventJSON = """
    [
        {
            "uid": "recurring-yoga-uid",
            "title": "Sunrise Yoga",
            "event_id": 90001,
            "description": "Every morning, rain or dust.",
            "event_type": { "label": "Class/Workshop", "abbr": "work" },
            "year": 2025,
            "print_description": "",
            "slug": "recurring-yoga-uid-sunrise-yoga",
            "hosted_by_camp": "a1XVI000009t6XR2AY",
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [
                { "start_time": "2025-08-26T07:00:00-07:00", "end_time": "2025-08-26T08:00:00-07:00" },
                { "start_time": "2025-08-27T07:00:00-07:00", "end_time": "2025-08-27T08:00:00-07:00" },
                { "start_time": "2025-08-28T07:00:00-07:00", "end_time": "2025-08-28T08:00:00-07:00" }
            ]
        },
        {
            "uid": "78ZvNxSeeZQbaeHuughD",
            "title": "Fairycore Tarot Meetup",
            "event_id": 51138,
            "description": "First time picking up cards? A professional reader? All levels welcome",
            "event_type": { "label": "Class/Workshop", "abbr": "work" },
            "year": 2025,
            "print_description": "",
            "slug": "78ZvNxSeeZQbaeHuughD-fairycore-tarot-meetup",
            "hosted_by_camp": "a1XVI000009t6XR2AY",
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [
                { "start_time": "2025-08-28T12:00:00-07:00", "end_time": "2025-08-28T13:30:00-07:00" }
            ]
        }
    ]
    """.data(using: .utf8) ?? Data()

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// An event with more than one occurrence, plus all of its occurrences in start order.
    private func recurringEvent() async throws -> (uid: String, occurrences: [EventObjectOccurrence]) {
        var filter = EventFilter()
        filter.includeExpired = true
        let all = try await playaDB.fetchEvents(filter: filter)
        let grouped = Dictionary(grouping: all, by: { $0.event.uid })
        let recurring = grouped.first { $0.value.count > 1 }
        let entry = try XCTUnwrap(recurring, "Mock data must contain at least one recurring event")
        return (entry.key, entry.value.sorted { $0.startDate < $1.startDate })
    }

    private func storedFavoriteIDs() async throws -> Set<String> {
        try await dbQueue.read { db in
            try String.fetchSet(db, sql: """
                SELECT object_id FROM object_metadata
                WHERE object_type = 'event' AND is_favorite = 1
                """)
        }
    }


    /// `XCTAssert*` takes autoclosures, which can't await — bind first.
    private func assertFavorite(
        _ object: any DataObject,
        _ expected: Bool,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let actual = try await playaDB.isFavorite(object)
        XCTAssertEqual(actual, expected, message, file: file, line: line)
    }

    private func writeLegacyParentFavorite(eventUID: String, stamp: Date = Date()) async throws {
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO object_metadata
                    (object_type, object_id, is_favorite, favorite_updated_at, created_at, updated_at)
                VALUES ('event', ?, 1, ?, ?, ?)
                """, arguments: [eventUID, stamp, stamp, stamp])
        }
    }

    private func reopenDatabase() throws {
        playaDB = nil
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
    }

    // MARK: - Identity

    func testFavoriteIdentityIsEventUIDPlusStartInstant() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let first = try XCTUnwrap(occurrences.first)

        XCTAssertEqual(
            first.favoriteIdentity,
            "\(uid)#\(EventCalendarEntry.occurrenceKey(for: first.startDate))"
        )
        let split = try XCTUnwrap(EventFavoriteKey.split(first.favoriteIdentity))
        XCTAssertEqual(split.eventUID, uid)
        XCTAssertEqual(split.occurrenceKey, first.occurrenceKey)
    }

    func testDistinctOccurrencesGetDistinctIdentities() async throws {
        let (_, occurrences) = try await recurringEvent()
        let identities = Set(occurrences.map(\.favoriteIdentity))
        XCTAssertEqual(identities.count, occurrences.count)
    }

    func testBareEventUIDIsNotComposite() {
        XCTAssertFalse(EventFavoriteKey.isComposite("abc123"))
        XCTAssertTrue(EventFavoriteKey.isComposite("abc123#2025-08-28T19:00:00Z"))
        XCTAssertEqual(EventFavoriteKey.eventUID(from: "abc123"), "abc123")
        XCTAssertEqual(EventFavoriteKey.eventUID(from: "abc123#2025-08-28T19:00:00Z"), "abc123")
    }

    // MARK: - Scope of a single toggle

    func testFavoritingOneOccurrenceLeavesSiblingsAlone() async throws {
        let (_, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        let sibling = try XCTUnwrap(occurrences.dropFirst().first)

        try await playaDB.toggleFavorite(target)

        try await assertFavorite(target, true)
        try await assertFavorite(sibling, false)
        let stored = try await storedFavoriteIDs()
        XCTAssertEqual(stored, [target.favoriteIdentity])
    }

    func testListRowMetadataMarksOnlyTheFavoritedOccurrence() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        try await playaDB.setFavorite(true, for: target)

        var filter = EventFilter()
        filter.includeExpired = true
        let rows = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ListRow<EventObjectOccurrence>], Error>) in
            var token: PlayaDBObservationToken?
            var resumed = false
            token = playaDB.observeEvents(filter: filter, onChange: { rows in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: rows)
                token?.cancel()
            }, onError: { error in
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: error)
            })
        }

        let mine = rows.filter { $0.object.event.uid == uid }
        XCTAssertGreaterThan(mine.count, 1)
        let favorited = mine.filter { $0.metadata?.isFavorite == true }
        XCTAssertEqual(favorited.count, 1)
        XCTAssertEqual(favorited.first?.object.favoriteIdentity, target.favoriteIdentity)
    }

    func testFavoriteIdentifiersAnswersPerOccurrence() async throws {
        let (_, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        let sibling = try XCTUnwrap(occurrences.dropFirst().first)
        try await playaDB.setFavorite(true, for: target)

        let identifiers = try await playaDB.favoriteIdentifiers(among: [target, sibling])

        XCTAssertEqual(identifiers, [target.favoriteIdentity])
        XCTAssertFalse(identifiers.contains(sibling.favoriteIdentity))
    }

    func testOnlyFavoritesFilterReturnsJustTheFavoritedOccurrence() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        try await playaDB.setFavorite(true, for: target)

        var filter = EventFilter()
        filter.includeExpired = true
        filter.onlyFavorites = true

        let fetched = try await playaDB.fetchEvents(filter: filter)
        XCTAssertEqual(fetched.map(\.favoriteIdentity), [target.favoriteIdentity])

        // The JOIN path (day/hour buckets) must agree with the non-joined path.
        let joined = try await dbQueue.read { [playaDB] db in
            try XCTUnwrap(playaDB).eventObjectOccurrencesJoined(filter: filter, db: db)
        }
        XCTAssertEqual(joined.map(\.favoriteIdentity), [target.favoriteIdentity])
        XCTAssertEqual(joined.first?.event.uid, uid)
    }

    func testFetchFavoriteEventsReturnsOnlyFavoritedOccurrences() async throws {
        let (_, occurrences) = try await recurringEvent()
        let first = try XCTUnwrap(occurrences.first)
        let third = occurrences.count > 2 ? occurrences[2] : nil
        try await playaDB.setFavorite(true, for: first)
        if let third { try await playaDB.setFavorite(true, for: third) }

        let favorites = try await playaDB.fetchFavoriteEvents()

        let expected = [first.favoriteIdentity] + (third.map { [$0.favoriteIdentity] } ?? [])
        XCTAssertEqual(Set(favorites.map(\.favoriteIdentity)), Set(expected))
        XCTAssertEqual(favorites.map(\.startDate), favorites.map(\.startDate).sorted())
    }

    func testUnfavoritingOneOccurrenceLeavesTheOtherFavorited() async throws {
        let (_, occurrences) = try await recurringEvent()
        let first = try XCTUnwrap(occurrences.first)
        let second = try XCTUnwrap(occurrences.dropFirst().first)
        try await playaDB.setFavorite(true, for: first)
        try await playaDB.setFavorite(true, for: second)

        try await playaDB.toggleFavorite(first)

        try await assertFavorite(first, false)
        try await assertFavorite(second, true)
    }

    // MARK: - Series operations

    func testSeriesSetterFavoritesEveryOccurrence() async throws {
        let (uid, occurrences) = try await recurringEvent()

        let changed = try await playaDB.setFavorite(true, forEventSeries: uid)

        XCTAssertEqual(changed, occurrences.count + 1, "Every occurrence plus the parent row")
        for occurrence in occurrences {
            try await assertFavorite(occurrence, true)
        }
        let favorites = try await playaDB.favoriteOccurrences(forEventUID: uid)
        XCTAssertEqual(favorites.count, occurrences.count)
    }

    func testBareEventToggleAffectsTheWholeSeries() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let fetchedEvent = try await playaDB.fetchEvent(uid: uid)
        let event = try XCTUnwrap(fetchedEvent)

        try await playaDB.toggleFavorite(event)
        for occurrence in occurrences {
            try await assertFavorite(occurrence, true,
                          "A bare EventObject names no showing, so its heart means the series")
        }
        try await assertFavorite(event, true)

        try await playaDB.toggleFavorite(event)
        for occurrence in occurrences {
            try await assertFavorite(occurrence, false)
        }
        try await assertFavorite(event, false)
    }

    func testBareEventIsFavoriteWhenAnyOccurrenceIs() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let fetchedEvent = try await playaDB.fetchEvent(uid: uid)
        let event = try XCTUnwrap(fetchedEvent)
        try await playaDB.setFavorite(true, for: try XCTUnwrap(occurrences.first))

        try await assertFavorite(event, true)
    }

    // MARK: - Legacy parent-uid compatibility

    func testLegacyParentRowLightsEveryOccurrence() async throws {
        let (uid, occurrences) = try await recurringEvent()
        try await writeLegacyParentFavorite(eventUID: uid)

        // No reopen: the fallback has to work before the fold ever runs.
        for occurrence in occurrences {
            try await assertFavorite(occurrence, true)
        }
        let identifiers = try await playaDB.favoriteIdentifiers(among: occurrences)
        XCTAssertEqual(identifiers, Set(occurrences.map(\.favoriteIdentity)))

        let favorites = try await playaDB.fetchFavoriteEvents()
        XCTAssertEqual(Set(favorites.map(\.favoriteIdentity)),
                       Set(occurrences.map(\.favoriteIdentity)))
    }

    func testUnfavoritingOneOccurrenceOfALegacySeriesOverridesTheParentRow() async throws {
        let (uid, occurrences) = try await recurringEvent()
        try await writeLegacyParentFavorite(eventUID: uid)
        let target = try XCTUnwrap(occurrences.first)

        try await playaDB.toggleFavorite(target)

        try await assertFavorite(target, false,
                       "An explicit occurrence row must out-vote the legacy parent row")
        for sibling in occurrences.dropFirst() {
            try await assertFavorite(sibling, true)
        }
    }

    // MARK: - Open-time fold

    func testFoldSplitsLegacyParentRowIntoPerOccurrenceRows() async throws {
        let (uid, occurrences) = try await recurringEvent()
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        try await writeLegacyParentFavorite(eventUID: uid, stamp: stamp)

        try reopenDatabase()

        let stored = try await storedFavoriteIDs()
        for occurrence in occurrences {
            XCTAssertTrue(stored.contains(occurrence.favoriteIdentity))
        }
        XCTAssertTrue(stored.contains(uid),
                      "The parent row stays favorited as the fallback for occurrences added later")

        let stamps = try await dbQueue.read { db in
            try Date.fetchAll(db, sql: """
                SELECT favorite_updated_at FROM object_metadata
                WHERE object_type = 'event' AND object_id <> ?
                """, arguments: [uid])
        }
        XCTAssertEqual(Set(stamps), [stamp], "Folded rows inherit the parent's favorite stamp")
    }

    func testFoldIsIdempotentAndPreservesExplicitOccurrenceRows() async throws {
        let (uid, occurrences) = try await recurringEvent()
        try await writeLegacyParentFavorite(eventUID: uid)
        let unfavorited = try XCTUnwrap(occurrences.first)
        // User already said "not this one".
        try await playaDB.setFavorite(false, for: unfavorited)

        try reopenDatabase()
        let afterFirst = try await storedFavoriteIDs()
        try reopenDatabase()
        let afterSecond = try await storedFavoriteIDs()

        XCTAssertEqual(afterFirst, afterSecond, "Fold must be idempotent")
        XCTAssertFalse(afterFirst.contains(unfavorited.favoriteIdentity),
                       "An explicit occurrence decision survives the fold")
        for sibling in occurrences.dropFirst() {
            XCTAssertTrue(afterFirst.contains(sibling.favoriteIdentity))
        }

        let rowCount = try await dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM object_metadata WHERE object_type = 'event'") ?? 0
        }
        XCTAssertEqual(rowCount, occurrences.count + 1, "One row per occurrence plus the parent")
    }

    func testFoldLeavesParentIntactWhenOccurrencesAreMissing() async throws {
        let orphanUID = "orphan-event-uid"
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO object_metadata
                    (object_type, object_id, is_favorite, created_at, updated_at)
                VALUES ('event', ?, 1, ?, ?)
                """, arguments: [orphanUID, Date(), Date()])
        }

        try reopenDatabase()

        let stored = try await storedFavoriteIDs()
        XCTAssertTrue(stored.contains(orphanUID),
                      "Nothing to fold into yet — the parent row must survive for a later open")
        XCTAssertFalse(stored.contains { EventFavoriteKey.isComposite($0) && $0.hasPrefix(orphanUID) })
    }

    // MARK: - Sync

    func testSyncRoundTripsCompositeKeys() async throws {
        let (_, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        try await playaDB.setFavorite(true, for: target)

        let snapshot = try await playaDB.favoriteSyncSnapshot()
        let item = try XCTUnwrap(snapshot.first { $0.objectId == target.favoriteIdentity })
        XCTAssertTrue(item.isFavorite)
        XCTAssertEqual(item.objectType, "event")

        // A peer receives the composite id verbatim and lands on the same occurrence.
        let peerPath = NSTemporaryDirectory() + "PerOccurrenceFavoriteTests-peer-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: peerPath) }
        let peer = try PlayaDBImpl(dbPath: peerPath)
        try await peer.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: Self.recurringEventJSON
        )
        let applied = try await peer.applyFavoriteSync(snapshot)
        XCTAssertTrue(applied.contains { $0.objectId == target.favoriteIdentity })

        let peerFavorites = try await peer.fetchFavoriteEvents()
        XCTAssertEqual(peerFavorites.map(\.favoriteIdentity), [target.favoriteIdentity])
    }

    func testLaterUnfavoriteWinsOverEarlierFavoriteForTheSameOccurrence() async throws {
        let (_, occurrences) = try await recurringEvent()
        let target = try XCTUnwrap(occurrences.first)
        try await playaDB.setFavorite(true, for: target)

        let unfavorite = FavoriteSyncItem(
            objectType: "event",
            objectId: target.favoriteIdentity,
            isFavorite: false,
            favoriteUpdatedAt: Date().addingTimeInterval(60),
            visitStatus: 0,
            visitStatusUpdatedAt: nil
        )
        let applied = try await playaDB.applyFavoriteSync([unfavorite])

        XCTAssertEqual(applied.count, 1)
        try await assertFavorite(target, false)
    }
}
