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
        XCTAssertEqual(fetched.modifiedDate, date(60))
    }

    func testDistinctIDsCoexist() async throws {
        try await playaDB.saveUserMapPin(makePin(id: "pin-1", created: 0))
        try await playaDB.saveUserMapPin(makePin(id: "pin-2", created: 1))

        let pins = try await playaDB.fetchUserMapPins()
        XCTAssertEqual(pins.map(\.id), ["pin-1", "pin-2"])
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
