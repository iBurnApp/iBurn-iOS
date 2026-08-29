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
        // Stars, so the two pins can be alive at once: saving a second *bike* now retires
        // the first (see `UserMapPinType.singletonTypes`).
        try await playaDB.saveUserMapPin(makePin(id: "live", type: .userStar))
        try await playaDB.saveUserMapPin(makePin(id: "gone", type: .userStar))
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

    // MARK: - Local writes must advance the stamp

    /// The reported bug: a pin moved on the phone came back at its original position
    /// after a relaunch. The map hands `saveUserMapPin` the `modifiedDate` it read at
    /// load time, so the edit used to be written with the *pre-edit* stamp and lost the
    /// last-writer-wins merge against the peer snapshot `PeerSyncManager` replays on
    /// every session activation.
    func testEditWrittenWithAStaleStampStillBeatsThePeersPreEditCopy() async throws {
        let original = makePin(latitude: 40.0, longitude: -119.0, modified: 1_000)
        try await playaDB.saveUserMapPin(original)

        // The move: same object the app loaded, new coordinate, stamp untouched.
        var moved = original
        moved.latitude = 41.0
        moved.longitude = -118.0
        try await playaDB.saveUserMapPin(moved)

        // Next launch: the watch replays the pin as it was before the move.
        let applied = try await playaDB.applyUserMapPinSync([original])

        XCTAssertTrue(applied.isEmpty, "the peer's pre-edit copy must not win")
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(visible.first?.latitude, 41.0)
        XCTAssertEqual(visible.first?.longitude, -118.0)
    }

    func testSaveAdvancesTheModifiedStampPastTheRowItReplaces() async throws {
        // A stamp in the future relative to this device's clock: the iOS app writes one
        // whenever the debug date override is on (`Date.present` defaults to event week).
        let future = Date().addingTimeInterval(7 * 24 * 60 * 60)
        var pin = makePin()
        pin.modifiedDate = future
        try await playaDB.saveUserMapPin(pin)

        // What the app writes back: the row as it was loaded, with one field changed.
        var edited = try await self.pin(id: "pin-1")
        let stampAtLoad = edited.modifiedDate
        edited.title = "Renamed"
        try await playaDB.saveUserMapPin(edited)

        let stored = try await self.pin(id: "pin-1")
        XCTAssertGreaterThan(stored.modifiedDate, stampAtLoad)
        XCTAssertEqual(stored.title, "Renamed")
    }

    func testSaveDoesNotRewriteTheCreationDate() async throws {
        try await playaDB.saveUserMapPin(makePin(created: 1_000))

        // The app rebuilds `createdDate` from the current clock on every load.
        var edited = makePin(created: 9_000)
        edited.title = "Renamed"
        try await playaDB.saveUserMapPin(edited)

        let stored = try await pin(id: "pin-1")
        XCTAssertEqual(stored.createdDate, date(1_000))
    }

    /// The other half of the bug: a deleted pin reappeared after a relaunch, because the
    /// tombstone was stamped with the local clock while the live row it retired carried a
    /// future (mock-date) stamp — so the peer's live copy won the merge.
    func testTombstoneOutranksAFutureDatedLiveRow() async throws {
        let future = Date().addingTimeInterval(7 * 24 * 60 * 60)
        var pin = makePin()
        pin.modifiedDate = future
        try await playaDB.saveUserMapPin(pin)
        let live = try await self.pin(id: "pin-1")

        try await playaDB.deleteUserMapPin(id: "pin-1")

        let tombstone = try await self.pin(id: "pin-1")
        XCTAssertTrue(tombstone.isDeleted)
        XCTAssertGreaterThan(tombstone.modifiedDate, live.modifiedDate)

        // Next launch: the peer replays the pin as still live.
        let applied = try await playaDB.applyUserMapPinSync([live])

        XCTAssertTrue(applied.isEmpty, "a deleted pin must not be resurrected")
        let visible = try await playaDB.fetchUserMapPins()
        XCTAssertTrue(visible.isEmpty)
    }

    func testDeletingAnUnknownPinIsANoOp() async throws {
        try await playaDB.deleteUserMapPin(id: "never-seen")

        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        XCTAssertTrue(snapshot.isEmpty)
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
