import XCTest
import Foundation
import GRDB
@testable import PlayaDB
@testable import PlayaAPI
import PlayaAPITestHelpers

/// Verifies how an event occurrence's metadata is addressed.
///
/// Two different rules live here, on purpose:
/// - **Notes, visits, view history** share the parent event's row — they are statements
///   about the event, not about one showing of it.
/// - **Favorites** are per occurrence, keyed by ``EventFavoriteKey`` (see
///   `PerOccurrenceFavoriteTests` for the full behaviour).
///
/// Neither ever uses `EventObjectOccurrence.uid`, a synthesized "<eventUID>_<occurrenceID>"
/// whose numeric half is reissued by every import. Earlier versions did, producing rows
/// invisible to every favorite query; `migrateOccurrenceKeyedMetadata` still cleans those up.
final class MetadataIdentityTests: XCTestCase {
    var playaDB: PlayaDB!
    var dbQueue: any DatabaseWriter {
        (playaDB as! PlayaDBImpl).dbQueue
    }
    var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "MetadataIdentityTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        try await super.tearDown()
    }

    private func firstOccurrence() async throws -> EventObjectOccurrence {
        let events = try await playaDB.fetchEvents()
        return try XCTUnwrap(events.first)
    }

    // MARK: - Identity normalization

    func testFavoritingOccurrenceWritesOccurrenceKeyedMetadata() async throws {
        let occurrence = try await firstOccurrence()

        try await playaDB.toggleFavorite(occurrence)

        let storedIds = try await dbQueue.read { db in
            try String.fetchAll(db, sql: """
                SELECT object_id FROM object_metadata
                WHERE object_type = 'event' AND is_favorite = 1
                """)
        }
        XCTAssertEqual(storedIds, [occurrence.favoriteIdentity],
                       "Favorite must be stored under the occurrence composite key, not the parent uid and not the synthesized occurrence uid")
        XCTAssertEqual(EventFavoriteKey.split(occurrence.favoriteIdentity)?.eventUID,
                       occurrence.event.uid)

        let viaOccurrence = try await playaDB.isFavorite(occurrence)
        XCTAssertTrue(viaOccurrence)
    }

    func testOccurrenceFavoriteVisibleToBothQueryPaths() async throws {
        let occurrence = try await firstOccurrence()
        try await playaDB.setFavorite(true, for: occurrence)

        // Non-joined path (fetchEvents(filter:))
        var filter = EventFilter()
        filter.onlyFavorites = true
        filter.includeExpired = true
        let fetched = try await playaDB.fetchEvents(filter: filter)
        XCTAssertTrue(fetched.contains { $0.event.uid == occurrence.event.uid },
                      "onlyFavorites fetch should include the favorited occurrence's event")

        // Joined path (used by observeEventsByDayThenHour)
        let impl = playaDB as! PlayaDBImpl
        let joined = try await dbQueue.read { db in
            try impl.eventObjectOccurrencesJoined(filter: filter, db: db)
        }
        XCTAssertTrue(joined.contains { $0.event.uid == occurrence.event.uid },
                      "JOIN path should agree with the non-joined path on favorites")
    }

    func testSetUserNotesOnOccurrenceReadableViaEvent() async throws {
        let occurrence = try await firstOccurrence()

        try await playaDB.setUserNotes("meet here at dusk", for: occurrence)

        let metadata = try await playaDB.metadata(for: occurrence.event)
        XCTAssertEqual(metadata.userNotes, "meet here at dusk")
    }

    // MARK: - Legacy row migration

    func testOccurrenceKeyedMetadataMergedIntoParentOnReopen() async throws {
        let occurrence = try await firstOccurrence()
        let syntheticId = occurrence.uid
        XCTAssertTrue(syntheticId.contains("_"), "Precondition: synthesized uid format")

        // Simulate a legacy favorite + notes stored under the synthesized uid.
        try await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO object_metadata
                    (object_type, object_id, is_favorite, user_notes, created_at, updated_at)
                VALUES ('event', ?, 1, 'legacy note', ?, ?)
                """, arguments: [syntheticId, Date(), Date()])
        }

        // Reopen: setup migration should fold the row into the parent event.
        playaDB = nil
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let (parentRow, syntheticRemains) = try await dbQueue.read { db -> (ObjectMetadata?, Bool) in
            let parent = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == "event")
                .filter(ObjectMetadata.Columns.objectId == occurrence.event.uid)
                .fetchOne(db)
            let synthetic = try ObjectMetadata
                .filter(ObjectMetadata.Columns.objectType == "event")
                .filter(ObjectMetadata.Columns.objectId == syntheticId)
                .fetchOne(db)
            return (parent, synthetic != nil)
        }

        XCTAssertFalse(syntheticRemains, "Synthesized-uid row should be deleted by migration")
        let parent = try XCTUnwrap(parentRow)
        XCTAssertTrue(parent.isFavorite)
        XCTAssertEqual(parent.userNotes, "legacy note")
    }
}
