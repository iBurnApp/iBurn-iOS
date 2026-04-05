import XCTest
@testable import PlayaDB
import PlayaAPITestHelpers

final class MetadataUpdateTests: XCTestCase {
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

    func testSetUserNotesRoundTrip() async throws {
        let arts = try await playaDB.fetchArt()
        let art = try XCTUnwrap(arts.first)

        try await playaDB.setUserNotes("hello", for: art)
        let metadata1 = try await playaDB.metadata(for: art)
        XCTAssertEqual(metadata1.userNotes, "hello")

        try await playaDB.setUserNotes("", for: art)
        let metadata2 = try await playaDB.metadata(for: art)
        XCTAssertNil(metadata2.userNotes)
    }

    func testSetLastViewedUpdatesMetadata() async throws {
        let arts = try await playaDB.fetchArt()
        let art = try XCTUnwrap(arts.first)

        let date = Date(timeIntervalSince1970: 123)
        try await playaDB.setLastViewed(date, for: art)
        let metadata = try await playaDB.metadata(for: art)
        XCTAssertEqual(metadata.lastViewed, date)
    }
}
