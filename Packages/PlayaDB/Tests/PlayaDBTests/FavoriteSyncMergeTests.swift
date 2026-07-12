import XCTest
@testable import PlayaDB
import PlayaAPITestHelpers

final class FavoriteSyncMergeTests: XCTestCase {
    private var playaDB: PlayaDB!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")

        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func firstArt() async throws -> ArtObject {
        let arts = try await playaDB.fetchArt()
        return try XCTUnwrap(arts.first)
    }

    private func firstCamp() async throws -> CampObject {
        let camps = try await playaDB.fetchCamps()
        return try XCTUnwrap(camps.first)
    }

    private func firstEvent() async throws -> EventObjectOccurrence {
        let events = try await playaDB.fetchEvents()
        return try XCTUnwrap(events.first)
    }

    /// A whole-second date so it round-trips exactly through SQLite storage.
    private func date(_ secondsSince1970: TimeInterval) -> Date {
        Date(timeIntervalSince1970: secondsSince1970)
    }

    // MARK: - Stamping

    func testSetFavoriteStampsFavoriteUpdatedAt() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)

        let metadata = try await playaDB.metadata(for: art)
        XCTAssertTrue(metadata.isFavorite)
        XCTAssertNotNil(metadata.favoriteUpdatedAt)
    }

    func testToggleFavoriteStampsFavoriteUpdatedAt() async throws {
        let camp = try await firstCamp()
        try await playaDB.toggleFavorite(camp)

        let metadata = try await playaDB.metadata(for: camp)
        XCTAssertTrue(metadata.isFavorite)
        XCTAssertNotNil(metadata.favoriteUpdatedAt)
    }

    func testSetLastViewedDoesNotStampFavoriteUpdatedAt() async throws {
        let camp = try await firstCamp()
        try await playaDB.setLastViewed(Date(), for: camp)

        let metadata = try await playaDB.metadata(for: camp)
        XCTAssertNotNil(metadata.lastViewed)
        XCTAssertNil(metadata.favoriteUpdatedAt)
    }

    // MARK: - Snapshot

    func testSnapshotIncludesFavoritedAndUnfavoritedExcludesViewedOnly() async throws {
        let art = try await firstArt()
        let camp = try await firstCamp()
        let event = try await firstEvent()

        // Favorited row.
        try await playaDB.setFavorite(true, for: art)
        // Explicitly-unfavorited row (was favorited, then unfavorited).
        try await playaDB.setFavorite(true, for: camp)
        try await playaDB.setFavorite(false, for: camp)
        // Viewed-only row: must not appear in the snapshot. Occurrence metadata
        // is keyed by the parent event uid, so resolve the actual objectId.
        try await playaDB.setLastViewed(Date(), for: event)
        let eventMetadata = try await playaDB.metadata(for: event)

        let snapshot = try await playaDB.favoriteSyncSnapshot()

        let artItem = try XCTUnwrap(snapshot.first { $0.objectId == art.uid && $0.objectType == "art" })
        XCTAssertTrue(artItem.isFavorite)

        let campItem = try XCTUnwrap(snapshot.first { $0.objectId == camp.uid && $0.objectType == "camp" })
        XCTAssertFalse(campItem.isFavorite)

        XCTAssertFalse(snapshot.contains { $0.objectId == eventMetadata.objectId && $0.objectType == "event" },
                       "Viewed-only rows must not appear in the sync snapshot")

        // Deterministic ordering: objectType then objectId.
        let keys = snapshot.map { [$0.objectType, $0.objectId] }
        let sortedKeys = keys.sorted { lhs, rhs in
            lhs.lexicographicallyPrecedes(rhs)
        }
        XCTAssertEqual(keys, sortedKeys)
    }

    // MARK: - Merge (applyFavoriteSync)

    func testNewerIncomingWins() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)

        // Far-future stamp: strictly newer than the local Date() stamp.
        let incoming = FavoriteSyncItem(
            objectType: "art",
            objectId: art.uid,
            isFavorite: false,
            updatedAt: date(4_000_000_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertEqual(applied, [incoming])
        let metadata = try await playaDB.metadata(for: art)
        XCTAssertFalse(metadata.isFavorite)
        XCTAssertEqual(metadata.favoriteUpdatedAt, incoming.updatedAt,
                       "Applied item must install the incoming stamp")
    }

    func testOlderIncomingIgnored() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)

        let incoming = FavoriteSyncItem(
            objectType: "art",
            objectId: art.uid,
            isFavorite: false,
            updatedAt: date(1_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertTrue(applied.isEmpty)
        let isFavorite = try await playaDB.isFavorite(art)
        XCTAssertTrue(isFavorite, "Older incoming state must lose to the newer local state")
    }

    func testSameStateSkippedEvenIfIncomingIsNewer() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)
        let metadataBefore = try await playaDB.metadata(for: art)
        let stampBefore = try XCTUnwrap(metadataBefore.favoriteUpdatedAt)

        let incoming = FavoriteSyncItem(
            objectType: "art",
            objectId: art.uid,
            isFavorite: true,
            updatedAt: date(4_000_000_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertTrue(applied.isEmpty, "Same-state items must be skipped to prevent observation loops")
        let metadataAfter = try await playaDB.metadata(for: art)
        let stampAfter = try XCTUnwrap(metadataAfter.favoriteUpdatedAt)
        XCTAssertEqual(stampAfter, stampBefore, "Skipped items must not bump the local stamp")
    }

    func testMissingRowWithFavoriteTrueInserts() async throws {
        let incoming = FavoriteSyncItem(
            objectType: "art",
            objectId: "ghost-art-uid",
            isFavorite: true,
            updatedAt: date(2_000_000_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertEqual(applied, [incoming])
        let snapshot = try await playaDB.favoriteSyncSnapshot()
        let item = try XCTUnwrap(snapshot.first { $0.objectId == "ghost-art-uid" })
        XCTAssertTrue(item.isFavorite)
        XCTAssertEqual(item.updatedAt, incoming.updatedAt)
    }

    func testMissingRowWithFavoriteFalseSkipped() async throws {
        let incoming = FavoriteSyncItem(
            objectType: "camp",
            objectId: "ghost-camp-uid",
            isFavorite: false,
            updatedAt: date(2_000_000_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertTrue(applied.isEmpty, "Unfavorite for a row we never had must not create junk rows")
        let snapshot = try await playaDB.favoriteSyncSnapshot()
        XCTAssertFalse(snapshot.contains { $0.objectId == "ghost-camp-uid" })
    }

    func testUnknownObjectTypeSkipped() async throws {
        let incoming = FavoriteSyncItem(
            objectType: "spaceship",
            objectId: "ufo-1",
            isFavorite: true,
            updatedAt: date(2_000_000_000)
        )
        let applied = try await playaDB.applyFavoriteSync([incoming])

        XCTAssertTrue(applied.isEmpty)
        let snapshot = try await playaDB.favoriteSyncSnapshot()
        XCTAssertFalse(snapshot.contains { $0.objectId == "ufo-1" })
    }

    func testReturnValueContainsExactlyAppliedItems() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)

        let winner = FavoriteSyncItem(
            objectType: "art", objectId: art.uid,
            isFavorite: false, updatedAt: date(4_000_000_000)
        )
        let insert = FavoriteSyncItem(
            objectType: "camp", objectId: "new-camp-uid",
            isFavorite: true, updatedAt: date(2_000_000_000)
        )
        let junkUnfavorite = FavoriteSyncItem(
            objectType: "event", objectId: "never-seen-event",
            isFavorite: false, updatedAt: date(2_000_000_000)
        )
        let unknownType = FavoriteSyncItem(
            objectType: "spaceship", objectId: "ufo-2",
            isFavorite: true, updatedAt: date(2_000_000_000)
        )

        let applied = try await playaDB.applyFavoriteSync([winner, insert, junkUnfavorite, unknownType])
        XCTAssertEqual(applied, [winner, insert])
    }

    func testSecondIdenticalApplyIsNoOp() async throws {
        let art = try await firstArt()
        try await playaDB.setFavorite(true, for: art)

        let items = [
            FavoriteSyncItem(
                objectType: "art", objectId: art.uid,
                isFavorite: false, updatedAt: date(4_000_000_000)
            ),
            FavoriteSyncItem(
                objectType: "camp", objectId: "idempotent-camp",
                isFavorite: true, updatedAt: date(2_000_000_000)
            ),
        ]

        let firstApplied = try await playaDB.applyFavoriteSync(items)
        XCTAssertEqual(firstApplied, items)

        let snapshotAfterFirst = try await playaDB.favoriteSyncSnapshot()
        let secondApplied = try await playaDB.applyFavoriteSync(items)
        XCTAssertTrue(secondApplied.isEmpty, "Re-applying the same items must be a no-op")

        let snapshotAfterSecond = try await playaDB.favoriteSyncSnapshot()
        XCTAssertEqual(snapshotAfterSecond, snapshotAfterFirst)
    }
}
