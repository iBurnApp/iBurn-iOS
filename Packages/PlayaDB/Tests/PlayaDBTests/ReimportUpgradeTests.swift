import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// What happens to a *populated* database — one that already carries the user's
/// favorites, visits, and notes — when a new app build ships newer bundled JSON.
///
/// This is the app-update path: the seed zip is never re-unzipped once
/// `Documents/PlayaDB.sqlite` exists (see `PlayaDBSeedRestore.restoreIfNeeded`), so the
/// only thing that refreshes data is `needsImport` + `importFromData` against the existing
/// store. `importFromData` deletes and reinserts every catalog table wholesale, which
/// means records that vanished from the API are hard-deleted and event occurrence rowids
/// are reissued — while `object_metadata` (favorites / visit status / notes) is never
/// touched. These tests pin that contract:
///
/// * stale rows really do disappear, and rows added by the new snapshot appear;
/// * duplicate uids in the source JSON are deduped (first entry in file order wins);
/// * favorites, per-occurrence event favorites, and notes all survive the re-import;
/// * a favorite whose object vanished leaves a harmless orphan metadata row that simply
///   stops showing up in `getFavorites()`;
/// * `needsImport` flips true → false across the upgrade.
final class ReimportUpgradeTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "ReimportUpgradeTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        try await super.tearDown()
    }

    // MARK: - Fixtures

    /// Timestamps for the two snapshots. B is strictly newer for every data type.
    private static let snapshotAUpdated = "2026-08-16T07:43:45-07:00"
    private static let snapshotBUpdated = "2026-08-19T22:07:14-07:00"

    private static let keptArtUID = "art-kept"
    private static let vanishedArtUID = "art-vanished"
    private static let addedArtUID = "art-added"
    private static let campUID = "camp-kept"
    private static let keptEventUID = "event-kept"
    private static let duplicatedEventUID = "event-duplicated"
    private static let vanishedEventUID = "event-vanished"
    private static let addedEventUID = "event-added"

    /// The occurrence the user favorites — present with the same start instant in both
    /// snapshots, so the composite favorite key resolves before and after.
    private static let favoritedStart = "2026-08-27T09:00:00-07:00"

    private static func artJSON(_ entries: [(uid: String, name: String)]) -> Data {
        let objects = entries.map { entry in
            """
            {
                "uid": "\(entry.uid)",
                "name": "\(entry.name)",
                "year": 2026,
                "url": null,
                "contact_email": null,
                "hometown": "Reno, NV",
                "description": "Test installation.",
                "artist": "Test Artist",
                "category": "Open Playa",
                "program": "Honorarium",
                "donation_link": null,
                "location": {
                    "hour": 3,
                    "minute": 30,
                    "distance": 2000,
                    "category": "Open Playa",
                    "gps_latitude": 40.786,
                    "gps_longitude": -119.203
                },
                "location_string": "3:30 2000', Open Playa",
                "images": [],
                "guided_tours": false,
                "self_guided_tour_map": false
            }
            """
        }
        return Data("[\(objects.joined(separator: ","))]".utf8)
    }

    private static func campJSON(name: String) -> Data {
        Data("""
        [
            {
                "uid": "\(campUID)",
                "name": "\(name)",
                "year": 2026,
                "url": null,
                "contact_email": null,
                "hometown": "Oakland, CA",
                "description": "Test camp.",
                "landmark": null,
                "location": {
                    "frontage": "Esplanade",
                    "intersection": "6:30",
                    "intersection_type": "&",
                    "dimensions": "75 x 110",
                    "exact_location": "Mid-block facing 10:00"
                },
                "location_string": "Esplanade & 6:30",
                "images": []
            }
        ]
        """.utf8)
    }

    private static func eventEntry(uid: String, title: String, starts: [String]) -> String {
        let occurrences = starts.map { start in
            """
            { "start_time": "\(start)", "end_time": "\(start)" }
            """
        }
        return """
        {
            "uid": "\(uid)",
            "title": "\(title)",
            "event_id": \(abs(uid.hashValue % 90000) + 10000),
            "description": "Test event.",
            "event_type": { "label": "Class/Workshop", "abbr": "work" },
            "year": 2026,
            "print_description": "",
            "slug": "\(uid)-slug",
            "hosted_by_camp": "\(campUID)",
            "located_at_art": null,
            "other_location": "",
            "check_location": false,
            "url": null,
            "all_day": false,
            "contact": null,
            "occurrence_set": [\(occurrences.joined(separator: ","))]
        }
        """
    }

    /// Snapshot A — what the shipped build's seed contains. Note the two entries sharing
    /// `duplicatedEventUID`: the real 2026 API data shipped duplicate event uids, and the
    /// importer keeps the first and skips the rest.
    private static var snapshotAEvents: Data {
        let entries = [
            eventEntry(uid: keptEventUID, title: "Sunrise Yoga",
                       starts: [favoritedStart, "2026-08-28T09:00:00-07:00"]),
            eventEntry(uid: duplicatedEventUID, title: "Duplicated Event (first)",
                       starts: ["2026-08-27T12:00:00-07:00"]),
            eventEntry(uid: duplicatedEventUID, title: "Duplicated Event (second)",
                       starts: ["2026-08-27T13:00:00-07:00", "2026-08-27T14:00:00-07:00"]),
            eventEntry(uid: vanishedEventUID, title: "Cancelled Event",
                       starts: ["2026-08-29T12:00:00-07:00"])
        ]
        return Data("[\(entries.joined(separator: ","))]".utf8)
    }

    /// Snapshot B — today's bundled JSON: the cancelled event and one art piece are gone,
    /// new records appear, the duplicate has been cleaned up, and the kept event keeps its
    /// favorited showing at the same instant.
    private static var snapshotBEvents: Data {
        let entries = [
            eventEntry(uid: keptEventUID, title: "Sunrise Yoga (updated)",
                       starts: [favoritedStart, "2026-08-28T09:00:00-07:00"]),
            eventEntry(uid: duplicatedEventUID, title: "Duplicated Event (deduped)",
                       starts: ["2026-08-27T12:00:00-07:00"]),
            eventEntry(uid: addedEventUID, title: "Brand New Event",
                       starts: ["2026-08-30T12:00:00-07:00"])
        ]
        return Data("[\(entries.joined(separator: ","))]".utf8)
    }

    private static func updateJSON(updated: String) -> Data {
        Data("""
        {
            "art": {"file": "art.json", "updated": "\(updated)"},
            "camps": {"file": "camp.json", "updated": "\(updated)"},
            "events": {"file": "event.json", "updated": "\(updated)"}
        }
        """.utf8)
    }

    private func importSnapshotA() async throws {
        try await playaDB.importFromData(
            artData: Self.artJSON([(Self.keptArtUID, "Kept Art"), (Self.vanishedArtUID, "Vanished Art")]),
            campData: Self.campJSON(name: "Test Camp"),
            eventData: Self.snapshotAEvents,
            mvData: nil,
            updateData: Self.updateJSON(updated: Self.snapshotAUpdated)
        )
    }

    private func importSnapshotB() async throws {
        try await playaDB.importFromData(
            artData: Self.artJSON([(Self.keptArtUID, "Kept Art (renamed)"), (Self.addedArtUID, "Added Art")]),
            campData: Self.campJSON(name: "Test Camp (renamed)"),
            eventData: Self.snapshotBEvents,
            mvData: nil,
            updateData: Self.updateJSON(updated: Self.snapshotBUpdated)
        )
    }

    // MARK: - Helpers

    private func eventUIDs() async throws -> [String] {
        try await playaDB.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT uid FROM event_objects ORDER BY uid")
        }
    }

    private func occurrenceCount() async throws -> Int {
        try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM event_occurrences") ?? -1
        }
    }

    private func metadataRowCount(objectID: String) async throws -> Int {
        try await playaDB.dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM object_metadata WHERE object_id = ?",
                             arguments: [objectID]) ?? -1
        }
    }

    /// The occurrence of `keptEventUID` the user favorites, identified by start instant.
    private func favoritedOccurrence() async throws -> EventObjectOccurrence {
        let occurrences = try await playaDB.fetchOccurrences(forEventUID: Self.keptEventUID)
        let target = occurrences.min { $0.startDate < $1.startDate }
        return try XCTUnwrap(target, "Kept event must have occurrences")
    }

    /// Favorites a surviving art piece, a doomed art piece, and one event showing, plus a
    /// note on the camp — the user state an upgrade has to preserve.
    private func seedUserState() async throws -> String {
        let keptArt = try await playaDB.fetchArt(uid: Self.keptArtUID)
        let vanishedArt = try await playaDB.fetchArt(uid: Self.vanishedArtUID)
        let camp = try await playaDB.fetchCamp(uid: Self.campUID)
        let keptArtObject = try XCTUnwrap(keptArt)
        let vanishedArtObject = try XCTUnwrap(vanishedArt)
        let campObject = try XCTUnwrap(camp)

        try await playaDB.setFavorite(true, for: keptArtObject)
        try await playaDB.setFavorite(true, for: vanishedArtObject)
        try await playaDB.setUserNotes("Meet Jo at the gate", for: campObject)

        let occurrence = try await favoritedOccurrence()
        try await playaDB.setFavorite(true, for: occurrence)
        return occurrence.favoriteIdentity
    }

    // MARK: - Import shape

    func testSnapshotAImportDedupsDuplicateEventUIDs() async throws {
        try await importSnapshotA()

        let uids = try await eventUIDs()
        XCTAssertEqual(uids, [Self.duplicatedEventUID, Self.keptEventUID, Self.vanishedEventUID],
                       "Duplicate uid should collapse to a single event row")
        XCTAssertEqual(Set(uids).count, uids.count, "Event uids must be unique in the database")

        // Only the *first* duplicate entry survives, so the second entry's two occurrences
        // never land: 2 (kept) + 1 (first duplicate) + 1 (vanished) = 4.
        let occurrences = try await occurrenceCount()
        XCTAssertEqual(occurrences, 4, "Skipped duplicate must not contribute occurrences")

        let duplicate = try await playaDB.fetchEvent(uid: Self.duplicatedEventUID)
        let duplicateEvent = try XCTUnwrap(duplicate)
        XCTAssertEqual(duplicateEvent.name, "Duplicated Event (first)",
                       "First entry in file order wins")
    }

    func testReimportReplacesStaleRecords() async throws {
        try await importSnapshotA()
        try await importSnapshotB()

        let art = try await playaDB.fetchArt()
        XCTAssertEqual(Set(art.map { $0.uid }), [Self.keptArtUID, Self.addedArtUID],
                       "Vanished art must be hard-deleted and new art inserted")
        let renamed = try await playaDB.fetchArt(uid: Self.keptArtUID)
        let renamedArt = try XCTUnwrap(renamed)
        XCTAssertEqual(renamedArt.name, "Kept Art (renamed)", "Surviving rows take the new values")

        let uids = try await eventUIDs()
        XCTAssertEqual(uids, [Self.addedEventUID, Self.duplicatedEventUID, Self.keptEventUID])
        XCTAssertFalse(uids.contains(Self.vanishedEventUID), "Cancelled event must be gone")
        XCTAssertEqual(Set(uids).count, uids.count, "Event uids must stay unique after re-import")

        // 2 (kept) + 1 (deduped) + 1 (added)
        let occurrences = try await occurrenceCount()
        XCTAssertEqual(occurrences, 4)

        let camps = try await playaDB.fetchCamps()
        XCTAssertEqual(camps.count, 1)
        XCTAssertEqual(camps.first?.name, "Test Camp (renamed)")
    }

    // MARK: - needsImport transitions

    func testNeedsImportFlipsAcrossTheUpgrade() async throws {
        try await importSnapshotA()

        let beforeUpgrade = try await playaDB.needsImport(
            bundleUpdateData: Self.updateJSON(updated: Self.snapshotBUpdated))
        XCTAssertTrue(beforeUpgrade, "A newer bundle must trigger an import")

        try await importSnapshotB()

        let afterUpgrade = try await playaDB.needsImport(
            bundleUpdateData: Self.updateJSON(updated: Self.snapshotBUpdated))
        XCTAssertFalse(afterUpgrade, "Re-importing the same bundle must be a no-op afterwards")

        let againstOlder = try await playaDB.needsImport(
            bundleUpdateData: Self.updateJSON(updated: Self.snapshotAUpdated))
        XCTAssertFalse(againstOlder, "An older bundle must never re-trigger an import")
    }

    func testReimportRewritesUpdateInfo() async throws {
        try await importSnapshotA()
        try await importSnapshotB()

        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: Self.snapshotBUpdated))
        let info = try await playaDB.getUpdateInfo()
        XCTAssertEqual(info.count, 3, "One row per imported data type")
        for row in info {
            XCTAssertEqual(row.lastUpdated.timeIntervalSince1970,
                           expected.timeIntervalSince1970,
                           accuracy: 0.001,
                           "\(row.dataType) should carry the new bundle timestamp")
        }
    }

    // MARK: - User data survival

    func testFavoritesAndNotesSurviveReimport() async throws {
        try await importSnapshotA()
        let favoriteIdentity = try await seedUserState()

        try await importSnapshotB()

        let keptArt = try await playaDB.fetchArt(uid: Self.keptArtUID)
        let keptArtObject = try XCTUnwrap(keptArt)
        let keptArtIsFavorite = try await playaDB.isFavorite(keptArtObject)
        XCTAssertTrue(keptArtIsFavorite, "A surviving object keeps its favorite")

        let favorites = try await playaDB.getFavorites()
        let favoriteUIDs = Set(favorites.map { $0.uid })
        XCTAssertTrue(favoriteUIDs.contains(Self.keptArtUID))

        let camp = try await playaDB.fetchCamp(uid: Self.campUID)
        let campObject = try XCTUnwrap(camp)
        let metadata = try await playaDB.metadata(for: campObject)
        XCTAssertEqual(metadata.userNotes, "Meet Jo at the gate", "Notes survive the re-import")

        // The favorited showing is keyed on (event uid, start instant), not on the
        // AUTOINCREMENT occurrence rowid the import reissues.
        let occurrence = try await favoritedOccurrence()
        XCTAssertEqual(occurrence.favoriteIdentity, favoriteIdentity)
        let occurrenceIsFavorite = try await playaDB.isFavorite(occurrence)
        XCTAssertTrue(occurrenceIsFavorite, "Per-occurrence favorite resolves after re-import")

        let favoriteEvents = try await playaDB.fetchFavoriteEvents()
        XCTAssertEqual(favoriteEvents.count, 1)
        XCTAssertEqual(favoriteEvents.first?.favoriteIdentity, favoriteIdentity)
    }

    func testFavoriteOfVanishedObjectBecomesBenignOrphan() async throws {
        try await importSnapshotA()
        _ = try await seedUserState()

        try await importSnapshotB()

        // The metadata row is deliberately not cleaned up (no FKs, no cascade) — it costs
        // nothing and lets a favorite come back if the record reappears in a later refresh.
        let orphanRows = try await metadataRowCount(objectID: Self.vanishedArtUID)
        XCTAssertEqual(orphanRows, 1, "Orphaned favorite metadata is kept")

        let vanished = try await playaDB.fetchArt(uid: Self.vanishedArtUID)
        XCTAssertNil(vanished, "The object itself is gone")

        // ...and it must not blow up or surface an empty row in any favorites read.
        let favorites = try await playaDB.getFavorites()
        let favoriteUIDs = Set(favorites.map { $0.uid })
        XCTAssertFalse(favoriteUIDs.contains(Self.vanishedArtUID),
                       "A favorite with no object drops out of getFavorites()")
        // The favorited occurrence resolves back to its parent event, so the surviving
        // favorites are exactly the kept art plus the kept event.
        XCTAssertEqual(favoriteUIDs, [Self.keptArtUID, Self.keptEventUID],
                       "Only favorites whose objects survived remain")
    }

    /// The upgrade path in one pass: populated store → reopen (migrations run) → import.
    func testUpgradeAcrossDatabaseReopen() async throws {
        try await importSnapshotA()
        let favoriteIdentity = try await seedUserState()

        // Close and reopen the same file, which re-runs the migrator over an existing store
        // exactly as an app launched from an older seed would.
        playaDB = nil
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)

        let needsImport = try await playaDB.needsImport(
            bundleUpdateData: Self.updateJSON(updated: Self.snapshotBUpdated))
        XCTAssertTrue(needsImport)

        try await importSnapshotB()

        let occurrence = try await favoritedOccurrence()
        let occurrenceIsFavorite = try await playaDB.isFavorite(occurrence)
        XCTAssertEqual(occurrence.favoriteIdentity, favoriteIdentity)
        XCTAssertTrue(occurrenceIsFavorite)

        let favorites = try await playaDB.getFavorites()
        XCTAssertEqual(Set(favorites.map { $0.uid }), [Self.keptArtUID, Self.keptEventUID])
    }
}
