import XCTest
import Foundation
import GRDB
@testable import PlayaDB

/// `ORDER BY name` with SQLite's default BINARY collation sorts by UTF-8 code point, so
/// every capitalized name lands ahead of every lowercase one ("Zebra" before "apple").
/// The browse lists (Art, Camps, Mutant Vehicles) all funnel through `orderedByName()`,
/// which now collates with `localizedStandardCompare` — case-insensitive and
/// numeric-aware, matching `GlobalSearchViewModel.sortedByName` in the app.
final class NameOrderingTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    private var dbQueue: any DatabaseWriter { playaDB.dbQueue }

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "NameOrderingTests-\(UUID().uuidString).sqlite"
        playaDB = try PlayaDBImpl(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        playaDB = nil
        if let tempDBPath {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: tempDBPath + suffix)
            }
        }
        tempDBPath = nil
        try await super.tearDown()
    }

    // MARK: - Fixtures

    /// Deliberately inserted out of order, and in an order whose BINARY sort
    /// ("Banana", "Zebra", "apple", "cherry") differs from the expected one.
    private static let mixedCaseNames = ["cherry", "Zebra", "apple", "Banana"]
    private static let expectedOrder = ["apple", "Banana", "cherry", "Zebra"]

    private func insertArt(named names: [String]) async throws {
        try await dbQueue.write { db in
            for (index, name) in names.enumerated() {
                var art = ArtObject(uid: "art-\(index)", name: name, year: 2026)
                try art.insert(db)
            }
        }
    }

    private func insertCamps(named names: [String]) async throws {
        try await dbQueue.write { db in
            for (index, name) in names.enumerated() {
                var camp = CampObject(uid: "camp-\(index)", name: name, year: 2026)
                try camp.insert(db)
            }
        }
    }

    private func insertMutantVehicles(named names: [String]) async throws {
        try await dbQueue.write { db in
            for (index, name) in names.enumerated() {
                var mv = MutantVehicleObject(uid: "mv-\(index)", name: name, year: 2026)
                try mv.insert(db)
            }
        }
    }

    // MARK: - Case-insensitive ordering

    func testFetchArtIsCaseInsensitivelyOrdered() async throws {
        try await insertArt(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchArt().map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    func testFetchCampsIsCaseInsensitivelyOrdered() async throws {
        try await insertCamps(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchCamps().map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    func testFetchMutantVehiclesIsCaseInsensitivelyOrdered() async throws {
        try await insertMutantVehicles(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchMutantVehicles().map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    /// The filtered requests are what the SwiftUI browse lists actually observe.
    func testFilteredArtRequestIsCaseInsensitivelyOrdered() async throws {
        try await insertArt(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchArt(filter: ArtFilter()).map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    func testFilteredCampRequestIsCaseInsensitivelyOrdered() async throws {
        try await insertCamps(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchCamps(filter: CampFilter()).map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    func testFilteredMutantVehicleRequestIsCaseInsensitivelyOrdered() async throws {
        try await insertMutantVehicles(named: Self.mixedCaseNames)

        let names = try await playaDB.fetchMutantVehicles(filter: MutantVehicleFilter()).map(\.name)

        XCTAssertEqual(names, Self.expectedOrder)
    }

    // MARK: - Numeric-aware ordering

    /// `localizedStandardCompare` is Finder-style, so embedded numbers sort numerically:
    /// "Camp 2" precedes "Camp 10" rather than following it lexicographically.
    func testNumbersInNamesSortNumerically() async throws {
        try await insertCamps(named: ["Camp 10", "Camp 2", "camp 1"])

        let names = try await playaDB.fetchCamps().map(\.name)

        XCTAssertEqual(names, ["camp 1", "Camp 2", "Camp 10"])
    }

    // MARK: - Stable tiebreaker

    /// Names that compare equal (pure case variants) must still come back in a
    /// deterministic order — `uid` is the tiebreaker.
    func testEqualNamesAreOrderedByUID() async throws {
        try await dbQueue.write { db in
            for uid in ["art-z", "art-a", "art-m"] {
                var art = ArtObject(uid: uid, name: "Duplicate", year: 2026)
                try art.insert(db)
            }
        }

        let uids = try await playaDB.fetchArt().map(\.uid)

        XCTAssertEqual(uids, ["art-a", "art-m", "art-z"])
    }
}
