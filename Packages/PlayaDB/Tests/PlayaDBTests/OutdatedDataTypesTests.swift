import XCTest
import Foundation
@testable import PlayaDB

/// `outdatedDataTypes(comparedTo:)` is the single newer-than comparison shared by the
/// bundled-seed path (`needsImport`) and the over-the-air update service, which uses it
/// to decide *which* per-type files to download. These tests pin that contract.
final class OutdatedDataTypesTests: XCTestCase {
    private var playaDB: PlayaDBImpl!
    private var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDBPath = NSTemporaryDirectory() + "OutdatedDataTypesTests-\(UUID().uuidString).sqlite"
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

    private static let importedStamp = "2026-08-20T10:00:00-07:00"
    private static let newerStamp = "2026-08-27T10:00:00-07:00"
    private static let olderStamp = "2026-08-01T10:00:00-07:00"

    private static func updateJSON(
        art: String? = importedStamp,
        camps: String? = importedStamp,
        events: String? = importedStamp,
        mv: String? = nil
    ) -> Data {
        var entries: [String] = []
        if let art { entries.append("\"art\": {\"file\": \"art.json\", \"updated\": \"\(art)\"}") }
        if let camps { entries.append("\"camps\": {\"file\": \"camp.json\", \"updated\": \"\(camps)\"}") }
        if let events { entries.append("\"events\": {\"file\": \"event.json\", \"updated\": \"\(events)\"}") }
        if let mv { entries.append("\"mv\": {\"file\": \"mv.json\", \"updated\": \"\(mv)\"}") }
        return Data("{\(entries.joined(separator: ","))}".utf8)
    }

    /// An import of empty-but-valid payloads: all this test cares about is the
    /// `update_info` rows the import writes.
    private func importBaseline(updateData: Data) async throws {
        try await playaDB.importFromData(
            artData: Data("[]".utf8),
            campData: Data("[]".utf8),
            eventData: Data("[]".utf8),
            mvData: nil,
            updateData: updateData
        )
    }

    // MARK: - Tests

    func testEveryTypeIsOutdatedOnAnEmptyDatabase() async throws {
        let outdated = try await playaDB.outdatedDataTypes(comparedTo: Self.updateJSON())
        XCTAssertEqual(outdated, [.art, .camp, .event])
    }

    func testNothingIsOutdatedAgainstTheSameTimestamps() async throws {
        try await importBaseline(updateData: Self.updateJSON())
        let outdated = try await playaDB.outdatedDataTypes(comparedTo: Self.updateJSON())
        XCTAssertTrue(outdated.isEmpty)
    }

    func testOnlyTheNewerTypeIsReported() async throws {
        try await importBaseline(updateData: Self.updateJSON())
        let outdated = try await playaDB.outdatedDataTypes(
            comparedTo: Self.updateJSON(events: Self.newerStamp)
        )
        XCTAssertEqual(outdated, [.event])
    }

    func testOlderServerDataIsNotOutdated() async throws {
        try await importBaseline(updateData: Self.updateJSON())
        let outdated = try await playaDB.outdatedDataTypes(
            comparedTo: Self.updateJSON(art: Self.olderStamp, camps: Self.olderStamp, events: Self.olderStamp)
        )
        XCTAssertTrue(outdated.isEmpty)
    }

    func testTypeWithNoImportedCounterpartIsOutdated() async throws {
        // The baseline import carries no mutant vehicles, so no mv row exists.
        try await importBaseline(updateData: Self.updateJSON())
        let outdated = try await playaDB.outdatedDataTypes(
            comparedTo: Self.updateJSON(mv: Self.olderStamp)
        )
        XCTAssertEqual(outdated, [.mutantVehicle])
    }

    func testTypesAbsentFromThePayloadAreNeverReported() async throws {
        let outdated = try await playaDB.outdatedDataTypes(
            comparedTo: Self.updateJSON(art: nil, camps: nil)
        )
        XCTAssertEqual(outdated, [.event])
    }

    func testNeedsImportAgreesWithOutdatedDataTypes() async throws {
        try await importBaseline(updateData: Self.updateJSON())

        let unchanged = try await playaDB.needsImport(bundleUpdateData: Self.updateJSON())
        XCTAssertFalse(unchanged)

        let newer = try await playaDB.needsImport(
            bundleUpdateData: Self.updateJSON(events: Self.newerStamp)
        )
        XCTAssertTrue(newer)
    }
}
