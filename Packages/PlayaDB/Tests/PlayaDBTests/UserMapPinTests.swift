import XCTest
@testable import PlayaDB

/// Coverage for the `user_map_pins` CRUD + observation surface, which backs the
/// map's user-dropped pins (home/bike/star) after the YapDatabase migration.
final class UserMapPinTests: XCTestCase {
    private var playaDB: PlayaDBImpl!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Whole-second dates so the TEXT round-trip through SQLite compares exactly.
    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + offset)
    }

    private func makePin(
        id: String,
        title: String? = "Camp",
        latitude: Double = 40.786,
        longitude: Double = -119.204,
        pinType: String = "userStar",
        created: TimeInterval = 0,
        modified: TimeInterval = 0
    ) -> UserMapPin {
        UserMapPin(
            id: id,
            title: title,
            latitude: latitude,
            longitude: longitude,
            pinType: pinType,
            createdDate: date(created),
            modifiedDate: date(modified)
        )
    }

    /// Writes rows the way builds before the singleton upsert did — a plain insert with
    /// no per-type collapse — so the fold has something to clean up.
    private func insertBypassingUpsert(_ pins: [UserMapPin]) async throws {
        try await playaDB.dbQueue.write { db in
            for var pin in pins {
                try pin.insert(db)
            }
        }
    }

    // MARK: - Save / Fetch

    func testSaveAndFetchRoundTrip() async throws {
        let pin = makePin(id: "pin-1", title: "My Bike", pinType: "userBike", created: 10, modified: 20)
        try await playaDB.saveUserMapPin(pin)

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.count, 1)

        let fetched = try XCTUnwrap(pins.first)
        XCTAssertEqual(fetched.id, "pin-1")
        XCTAssertEqual(fetched.title, "My Bike")
        XCTAssertEqual(fetched.latitude, 40.786, accuracy: 0.000001)
        XCTAssertEqual(fetched.longitude, -119.204, accuracy: 0.000001)
        XCTAssertEqual(fetched.pinType, "userBike")
        XCTAssertEqual(fetched.createdDate, date(10))
        XCTAssertEqual(fetched.modifiedDate, date(20))
    }

    func testSaveRoundTripsNilTitle() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-untitled", title: nil))

        let pins = try await playaDB.fetchUserMapPins()
        let fetched = try XCTUnwrap(pins.first)
        XCTAssertNil(fetched.title)
    }

    func testFetchIsEmptyOnFreshDatabase() async throws {
        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertTrue(pins.isEmpty)
    }

    // MARK: - Upsert

    func testSaveWithSameIDReplacesExistingPin() async throws {
        try await playaDB.saveUserMapPin(
            makePin(id: "pin-1", title: "Original", latitude: 40.0, longitude: -119.0, created: 0, modified: 0)
        )
        try await playaDB.saveUserMapPin(
            makePin(
                id: "pin-1",
                title: "Renamed",
                latitude: 41.5,
                longitude: -118.5,
                pinType: "userHome",
                created: 0,
                modified: 60
            )
        )

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.count, 1, "Saving the same id must replace, not duplicate")

        let fetched = try XCTUnwrap(pins.first)
        XCTAssertEqual(fetched.title, "Renamed")
        XCTAssertEqual(fetched.latitude, 41.5, accuracy: 0.000001)
        XCTAssertEqual(fetched.longitude, -118.5, accuracy: 0.000001)
        XCTAssertEqual(fetched.pinType, "userHome")
        // An edit stamps its own `modified_date`: the last-writer-wins merge has to be
        // able to tell the edited row from the one it replaced.
        XCTAssertGreaterThan(fetched.modifiedDate, date(60))
    }

    func testDistinctIDsCoexist() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-1", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "pin-2", created: 1))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["pin-1", "pin-2"])
    }

    // MARK: - Singleton types (home / bike)

    func testSavingSecondHomeRetiresTheFirst() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "home-1", title: "Old camp", pinType: "userHome", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "home-2", title: "New camp", pinType: "userHome", created: 10))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["home-2"], "Home is a singleton: the newer save replaces the older row")
    }

    func testRetiredSingletonBecomesTombstoneRatherThanVanishing() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "bike-1", pinType: "userBike", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "bike-2", pinType: "userBike", created: 10))

        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        let retired = try XCTUnwrap(snapshot.first { $0.id == "bike-1" })
        XCTAssertTrue(retired.isDeleted, "A hard delete would be resurrected by the peer's snapshot")
        XCTAssertGreaterThan(retired.modifiedDate, date(0), "Tombstone must outrank the row it replaces")
    }

    func testResavingTheSameSingletonKeepsIt() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "bike", title: "Bike", pinType: "userBike", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "bike", title: "Moved bike", pinType: "userBike", created: 0, modified: 60))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["bike"])
        XCTAssertEqual(pins.first?.title, "Moved bike")
    }

    func testDifferentSingletonTypesCoexist() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "home", pinType: "userHome", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "bike", pinType: "userBike", created: 10))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["home", "bike"])
    }

    func testStarsAccumulate() async throws {
        for index in 0..<3 {
            try await playaDB.saveUserMapPin(
                makePin(id: "star-\(index)", pinType: "userStar", created: TimeInterval(index))
            )
        }

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["star-0", "star-1", "star-2"], "Stars are not singletons")
    }

    func testBreadcrumbsAccumulate() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "crumb-1", pinType: "userBreadcrumb", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "crumb-2", pinType: "userBreadcrumb", created: 1))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.count, 2)
    }

    // MARK: - Duplicate fold (databases written before the upsert)

    func testFoldCollapsesDuplicateSingletonsToTheNewest() async throws {
        try await insertBypassingUpsert([
            makePin(id: "home-old", title: "Old", pinType: "userHome", created: 0, modified: 0),
            makePin(id: "home-new", title: "New", pinType: "userHome", created: 5, modified: 50),
            makePin(id: "home-mid", title: "Mid", pinType: "userHome", created: 1, modified: 10),
            makePin(id: "star-1", pinType: "userStar", created: 0, modified: 0),
            makePin(id: "star-2", pinType: "userStar", created: 1, modified: 1),
        ])

        try await playaDB.dbQueue.write { db in
            try PlayaDBImpl.collapseDuplicateSingletonPins(db)
        }

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(Set(pins.map(\.id)), ["home-new", "star-1", "star-2"], "Stars are untouched by the fold")
    }

    func testFoldIsIdempotentAndLeavesASinglePinAlone() async throws {
        try await insertBypassingUpsert([
            makePin(id: "home", pinType: "userHome", created: 0, modified: 0),
            makePin(id: "bike", pinType: "userBike", created: 0, modified: 0),
        ])

        for _ in 0..<3 {
            try await playaDB.dbQueue.write { db in
                try PlayaDBImpl.collapseDuplicateSingletonPins(db)
            }
        }

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(Set(pins.map(\.id)), ["home", "bike"])
        let snapshot = try await playaDB.userMapPinSyncSnapshot()
        XCTAssertTrue(snapshot.allSatisfy { !$0.isDeleted }, "Nothing to fold means nothing written")
    }

    func testDuplicatesAreFoldedWhenAnExistingDatabaseIsOpened() async throws {
        let path = NSTemporaryDirectory().appending("PlayaDB-fold-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(atPath: path) }

        var first: PlayaDBImpl? = try PlayaDBImpl(dbPath: path)
        try await XCTUnwrap(first).dbQueue.write { db in
            // Straight inserts: this is what the racing pre-upsert placement path left behind.
            for var pin in [
                self.makePin(id: "bike-old", pinType: "userBike", created: 0, modified: 0),
                self.makePin(id: "bike-new", pinType: "userBike", created: 5, modified: 50),
            ] {
                try pin.insert(db)
            }
        }
        first = nil

        let reopened = try PlayaDBImpl(dbPath: path)
        let pins = try await reopened.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["bike-new"])
    }

    // MARK: - Delete

    func testDeleteRemovesOnlyTargetPin() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-1", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "pin-2", created: 1))

        try await playaDB.deleteUserMapPin(id: "pin-1")

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["pin-2"])
    }

    func testDeleteUnknownIDIsNoOp() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-1"))

        try await playaDB.deleteUserMapPin(id: "does-not-exist")

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["pin-1"])
    }

    // MARK: - Ordering

    func testFetchOrdersByCreatedDateAscending() async throws {
        // Saved out of order on purpose.
        try await playaDB.saveUserMapPin(makePin(id: "middle", created: 100))
        try await playaDB.saveUserMapPin(makePin(id: "newest", created: 200))
        try await playaDB.saveUserMapPin(makePin(id: "oldest", created: 0))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["oldest", "middle", "newest"])
    }

    // MARK: - Observation

    func testObserveEmitsInitialValueAndInsert() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-existing", created: 0))

        let initial = expectation(description: "Initial pins emitted")
        let inserted = expectation(description: "Inserted pin emitted")

        let token = playaDB.observeUserMapPins { pins in
            let ids = pins.map(\.id)
            if ids == ["pin-existing"] {
                initial.fulfill()
            }
            if ids.contains("pin-new") {
                inserted.fulfill()
            }
        }
        defer { token.cancel() }

        await fulfillment(of: [initial], timeout: 2.0)

        try await playaDB.saveUserMapPin(makePin(id: "pin-new", created: 10))

        await fulfillment(of: [inserted], timeout: 2.0)
    }

    func testObserveEmitsOnUpdateAndDelete() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-1", title: "Before", created: 0))

        let renamed = expectation(description: "Renamed pin emitted")
        let deleted = expectation(description: "Empty list emitted after delete")

        let token = playaDB.observeUserMapPins { pins in
            if pins.first?.title == "After" {
                renamed.fulfill()
            }
            if pins.isEmpty {
                deleted.fulfill()
            }
        }
        defer { token.cancel() }

        try await playaDB.saveUserMapPin(makePin(id: "pin-1", title: "After", created: 0, modified: 30))
        await fulfillment(of: [renamed], timeout: 2.0)

        try await playaDB.deleteUserMapPin(id: "pin-1")
        await fulfillment(of: [deleted], timeout: 2.0)
    }
}
