import XCTest
@testable import PlayaDB

/// Last-writer-wins merge semantics for user map pins, plus the soft-delete
/// behaviour that makes deletions propagate between phone and watch.
final class UserMapPinSyncTests: XCTestCase {
    private var playaDB: PlayaDB!

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// A whole-second date so it round-trips exactly through SQLite storage.
    private func date(_ secondsSince1970: TimeInterval) -> Date {
        Date(timeIntervalSince1970: secondsSince1970)
    }

    private func makePin(
        id: String = "pin-1",
        title: String? = "Bike",
        latitude: Double = 40.7864,
        longitude: Double = -119.2065,
        type: UserMapPinType = .userBike,
        created: TimeInterval = 1_000,
        modified: TimeInterval = 1_000,
        isDeleted: Bool = false
    ) -> UserMapPin {
        UserMapPin(
            id: id,
            title: title,
            latitude: latitude,
            longitude: longitude,
            pinType: type.rawValue,
            createdDate: date(created),
            modifiedDate: date(modified),
            isDeleted: isDeleted
        )
    }

    private func pin(id: String) async throws -> UserMapPin {
        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        return try XCTUnwrap(snapshot.first { $0.id == id })
    }

    // MARK: - Soft delete

    func testDeleteTombstonesRatherThanRemovingTheRow() async throws {
        try await playaDB.saveUserMapPin(makePin())
        try await playaDB.deleteUserMapPin(id: "pin-1")

        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertTrue(visible.isEmpty, "a deleted pin must not show up in the app")

        let tombstone = try await pin(id: "pin-1")
        XCTAssertTrue(tombstone.isDeleted)
        XCTAssertEqual(tombstone.title, "Bike", "the tombstone keeps the row's fields")
    }

    func testDeleteBumpsModifiedDateSoItCanWinAMerge() async throws {
        try await playaDB.saveUserMapPin(makePin(modified: 1_000))
        try await playaDB.deleteUserMapPin(id: "pin-1")

        let tombstone = try await pin(id: "pin-1")
        XCTAssertGreaterThan(tombstone.modifiedDate, date(1_000))
    }

    func testSavingAgainResurrectsADeletedPin() async throws {
        try await playaDB.saveUserMapPin(makePin())
        try await playaDB.deleteUserMapPin(id: "pin-1")
        try await playaDB.saveUserMapPin(makePin(title: "Bike again", modified: 9_000))

        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.map(\.title), ["Bike again"])
    }

    // MARK: - Snapshot

    func testSnapshotIncludesTombstonesButFetchDoesNot() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "live"))
        try await playaDB.saveUserMapPin(makePin(id: "gone"))
        try await playaDB.deleteUserMapPin(id: "gone")

        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        XCTAssertEqual(snapshot.map(\.id).sorted(), ["gone", "live"])

        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.map(\.id), ["live"])
    }

    // MARK: - Merge

    func testIncomingPinIsInserted() async throws {
        let applied = try await playaDB.applyUserMapPinSync([makePin(id: "from-watch")])

        XCTAssertEqual(applied.map(\.id), ["from-watch"])
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.map(\.id), ["from-watch"])
    }

    func testNewerIncomingWins() async throws {
        try await playaDB.saveUserMapPin(makePin(title: "Local", modified: 1_000))

        let applied = try await playaDB.applyUserMapPinSync([
            makePin(title: "Peer", latitude: 40.79, modified: 2_000)
        ])

        XCTAssertEqual(applied.count, 1)
        let merged = try await pin(id: "pin-1")
        XCTAssertEqual(merged.title, "Peer")
        XCTAssertEqual(merged.latitude, 40.79, accuracy: 0.0001)
        XCTAssertEqual(merged.modifiedDate, date(2_000))
    }

    func testOlderIncomingLoses() async throws {
        try await playaDB.saveUserMapPin(makePin(title: "Local", modified: 2_000))

        let applied = try await playaDB.applyUserMapPinSync([makePin(title: "Peer", modified: 1_000)])

        XCTAssertTrue(applied.isEmpty)
        let merged = try await pin(id: "pin-1")
        XCTAssertEqual(merged.title, "Local")
    }

    func testEqualStampIsNotApplied() async throws {
        try await playaDB.saveUserMapPin(makePin(title: "Local", modified: 2_000))

        let applied = try await playaDB.applyUserMapPinSync([makePin(title: "Peer", modified: 2_000)])

        XCTAssertTrue(applied.isEmpty, "ties must not flip-flop between devices")
        let merged = try await pin(id: "pin-1")
        XCTAssertEqual(merged.title, "Local")
    }

    func testApplyingOwnSnapshotIsANoOp() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "a"))
        try await playaDB.saveUserMapPin(makePin(id: "b"))
        try await playaDB.deleteUserMapPin(id: "b")

        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        let applied = try await playaDB.applyUserMapPinSync(snapshot)

        // The invariant that stops the two devices ping-ponging pushes forever.
        XCTAssertTrue(applied.isEmpty)
    }

    func testIncomingTombstoneDeletesLocalPin() async throws {
        try await playaDB.saveUserMapPin(makePin(modified: 1_000))

        let applied = try await playaDB.applyUserMapPinSync([makePin(modified: 2_000, isDeleted: true)])

        XCTAssertEqual(applied.count, 1)
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertTrue(visible.isEmpty)
    }

    func testTombstoneForUnknownPinIsIgnored() async throws {
        let applied = try await playaDB.applyUserMapPinSync([
            makePin(id: "never-seen", isDeleted: true)
        ])

        XCTAssertTrue(applied.isEmpty)
        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        XCTAssertTrue(snapshot.isEmpty, "we don't store tombstones for pins we never had")
    }

    func testNewerLocalCreateBeatsOlderPeerTombstone() async throws {
        try await playaDB.saveUserMapPin(makePin(modified: 5_000))

        let applied = try await playaDB.applyUserMapPinSync([makePin(modified: 2_000, isDeleted: true)])

        XCTAssertTrue(applied.isEmpty)
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.map(\.id), ["pin-1"])
    }

    func testMergeKeepsEarliestCreationDate() async throws {
        try await playaDB.saveUserMapPin(makePin(created: 1_000, modified: 1_000))

        try await playaDB.applyUserMapPinSync([makePin(created: 8_000, modified: 2_000)])

        let merged = try await pin(id: "pin-1")
        XCTAssertEqual(merged.createdDate, date(1_000))
    }

    func testMergeIsIdempotent() async throws {
        let incoming = [makePin(id: "a", modified: 3_000), makePin(id: "b", modified: 3_000)]

        let first = try await playaDB.applyUserMapPinSync(incoming)
        let second = try await playaDB.applyUserMapPinSync(incoming)

        XCTAssertEqual(first.count, 2)
        XCTAssertTrue(second.isEmpty)
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.map(\.id), ["a", "b"])
    }

    // MARK: - Payload compatibility

    func testDecodesPayloadWithoutIsDeleted() throws {
        // A peer running a build that predates tombstones omits the key; the
        // whole array must still decode rather than failing.
        let json = Data("""
        [{"id":"legacy","title":"Bike","latitude":40.78,"longitude":-119.2,
          "pin_type":"userBike","created_date":1000,"modified_date":2000}]
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let pins = try decoder.decode([UserMapPin].self, from: json)

        XCTAssertEqual(pins.count, 1)
        XCTAssertFalse(try XCTUnwrap(pins.first).isDeleted)
    }
}
