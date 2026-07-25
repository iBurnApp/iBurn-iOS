import XCTest
import Foundation
import GRDB
@testable import PlayaDB
@testable import PlayaAPI
import PlayaAPITestHelpers

/// Covers migration `v4-audio-tour`: the `art_objects.audio_tour_url` column, its
/// import mapping from the API's `audio_tour_url` field, and `ArtFilter.hasAudioTour`.
final class AudioTourTests: XCTestCase {
    private var playaDB: PlayaDBImpl!

    private var dbQueue: any DatabaseWriter { playaDB.dbQueue }

    override func setUp() async throws {
        try await super.setUp()
        playaDB = try PlayaDBImpl(dbPath: ":memory:")
    }

    override func tearDown() async throws {
        playaDB = nil
        try await super.tearDown()
    }

    // MARK: - Fixtures

    private static let audioTourURLString =
        "https://iburn-data.iburnapp.com/2025/audio_tour/a2Id0000000cbObEAI.mp3"

    /// Art fixture with one installation carrying `audio_tour_url` and one where the
    /// field is absent entirely (the shape of the 2026 payload).
    private static let artJSON = """
    [
        {
            "uid": "art-audio",
            "name": "Echoes of the Playa",
            "year": 2025,
            "description": "An art piece with a recorded audio tour.",
            "artist": "Audio Collective",
            "images": [],
            "guided_tours": false,
            "self_guided_tour_map": false,
            "audio_tour_url": "\(audioTourURLString)"
        },
        {
            "uid": "art-silent",
            "name": "Silent Monolith",
            "year": 2025,
            "description": "An art piece without any audio tour.",
            "artist": "Quiet Collective",
            "images": [],
            "guided_tours": false,
            "self_guided_tour_map": false
        }
    ]
    """.data(using: .utf8)!

    private func importFixture() async throws {
        try await playaDB.importFromData(
            artData: Self.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
    }

    // MARK: - Import

    func testImportPopulatesAudioTourURL() async throws {
        try await importFixture()

        let art = try await playaDB.fetchArt()
        let withAudio = try XCTUnwrap(art.first { $0.uid == "art-audio" })
        let withoutAudio = try XCTUnwrap(art.first { $0.uid == "art-silent" })

        XCTAssertEqual(withAudio.audioTourUrl?.absoluteString, Self.audioTourURLString)
        XCTAssertTrue(withAudio.hasAudioTour)
        XCTAssertNil(withoutAudio.audioTourUrl, "An absent audio_tour_url must import as NULL")
        XCTAssertFalse(withoutAudio.hasAudioTour)
    }

    func testImportOfPayloadWithoutAudioFieldSucceeds() async throws {
        // Regression guard for the 2026 payload, where no art record has the field.
        try await playaDB.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )

        let art = try await playaDB.fetchArt()
        XCTAssertFalse(art.isEmpty, "Import must succeed when no record carries audio_tour_url")
        XCTAssertTrue(art.allSatisfy { $0.audioTourUrl == nil })
    }

    func testAudioTourURLStoredAsTextInColumn() async throws {
        try await importFixture()

        let stored = try await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT audio_tour_url FROM art_objects WHERE uid = 'art-audio'")
        }

        XCTAssertEqual(stored, Self.audioTourURLString)
    }

    // MARK: - ArtFilter.hasAudioTour

    func testFilterHasAudioTourTrueReturnsOnlyAudioArt() async throws {
        try await importFixture()

        let results = try await playaDB.fetchArt(filter: ArtFilter(hasAudioTour: true))

        XCTAssertEqual(results.map(\.uid), ["art-audio"])
    }

    func testFilterHasAudioTourFalseReturnsOnlySilentArt() async throws {
        try await importFixture()

        let results = try await playaDB.fetchArt(filter: ArtFilter(hasAudioTour: false))

        XCTAssertEqual(results.map(\.uid), ["art-silent"])
    }

    func testFilterNilAppliesNoAudioFiltering() async throws {
        try await importFixture()

        let results = try await playaDB.fetchArt(filter: ArtFilter())

        XCTAssertEqual(Set(results.map(\.uid)), ["art-audio", "art-silent"])
    }

    func testEmptyAudioTourURLCountsAsMissing() async throws {
        try await importFixture()

        // An empty string is what a blank API value would land as; it must not be
        // treated as an available audio tour.
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE art_objects SET audio_tour_url = '' WHERE uid = 'art-audio'")
        }

        let withAudio = try await playaDB.fetchArt(filter: ArtFilter(hasAudioTour: true))
        XCTAssertTrue(withAudio.isEmpty, "Empty audio_tour_url must not match hasAudioTour: true")

        // The complementary predicate must pick the blanked row back up. Selecting
        // just the uid keeps the assertion on the SQL predicate: an empty string is
        // not decodable as a `URL`, and only the import writes this column (via
        // `LenientURL`, which yields nil or a valid URL — never an empty string).
        let request = playaDB
            .artRequest(filter: ArtFilter(hasAudioTour: false))
            .select(ArtObject.Columns.uid, as: String.self)
        let uids = try await dbQueue.read { db in
            try request.fetchAll(db)
        }

        XCTAssertEqual(Set(uids), ["art-audio", "art-silent"])
    }

    func testAudioFilterCombinesWithOtherPredicates() async throws {
        try await importFixture()

        // Combined with a year that excludes everything, the AND-composition must win.
        let noYearMatch = try await playaDB.fetchArt(filter: ArtFilter(year: 1999, hasAudioTour: true))
        XCTAssertTrue(noYearMatch.isEmpty)

        // Combined with FTS search on a term only the silent piece matches.
        let searchMismatch = try await playaDB.fetchArt(
            filter: ArtFilter(searchText: "Monolith", hasAudioTour: true)
        )
        XCTAssertTrue(searchMismatch.isEmpty, "hasAudioTour must AND with the search predicate")

        let searchMatch = try await playaDB.fetchArt(
            filter: ArtFilter(searchText: "Echoes", hasAudioTour: true)
        )
        XCTAssertEqual(searchMatch.map(\.uid), ["art-audio"])
    }

    // MARK: - Observation

    func testObserveArtAppliesAudioTourFilter() async throws {
        try await importFixture()

        let appeared = expectation(description: "Newly inserted audio art is observed")

        let token = playaDB.observeArt(
            filter: ArtFilter(hasAudioTour: true),
            onChange: { rows in
                XCTAssertFalse(
                    rows.contains { $0.object.uid == "art-silent" },
                    "Art without an audio tour must never be emitted by the filtered observation"
                )
                if rows.contains(where: { $0.object.uid == "art-late-audio" }) {
                    appeared.fulfill()
                }
            },
            onError: { error in
                XCTFail("Art observation error: \(error)")
            }
        )
        defer { token.cancel() }

        let lateURL = try XCTUnwrap(URL(string: "https://example.com/late.m4a"))
        try await dbQueue.write { db in
            var art = ArtObject(
                uid: "art-late-audio",
                name: "Late Audio Arrival",
                year: 2025,
                audioTourUrl: lateURL
            )
            try art.insert(db)
        }

        await fulfillment(of: [appeared], timeout: 2.0)
    }
}
