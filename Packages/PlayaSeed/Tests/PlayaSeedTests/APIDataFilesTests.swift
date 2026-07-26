import XCTest
@testable import playa_seed

final class APIDataFilesTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("playa-seed-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func write(_ name: String, _ json: String) throws {
        try json.write(to: directory.appendingPathComponent("\(name).json"), atomically: true, encoding: .utf8)
    }

    private func writeRequiredFiles() throws {
        try write("art", "[]")
        try write("camp", "[]")
        try write("event", "[]")
    }

    func testMissingRequiredFileThrows() throws {
        try write("art", "[]")
        XCTAssertThrowsError(try APIDataFiles(directory: directory))
    }

    func testOptionalFilesAreAbsentRatherThanFatal() throws {
        try writeRequiredFiles()
        let files = try APIDataFiles(directory: directory)

        XCTAssertNil(files.mutantVehicle)
        XCTAssertNil(files.update)
    }

    func testThumbnailReferencesSpanArtCampsAndMutantVehicles() throws {
        try writeRequiredFiles()
        try write("art", """
        [{"uid": "art1", "images": [{"thumbnail_url": "https://example.com/art1.jpg"}]}]
        """)
        try write("camp", """
        [{"uid": "camp1", "images": [{"thumbnail_url": "https://example.com/camp1.jpg"}]}]
        """)
        try write("mv", """
        [{"uid": "mv1", "images": [{"thumbnail_url": "https://example.com/mv1.jpg"}]}]
        """)

        let references = try APIDataFiles(directory: directory).thumbnailReferences()

        XCTAssertEqual(Set(references.map(\.uid)), ["art1", "camp1", "mv1"])
        let art = try XCTUnwrap(references.first { $0.uid == "art1" })
        XCTAssertEqual(art.remoteURL.absoluteString, "https://example.com/art1.jpg")
    }

    func testObjectsWithoutUsableThumbnailsAreSkipped() throws {
        try writeRequiredFiles()
        try write("art", """
        [
          {"uid": "none", "images": []},
          {"uid": "null-field", "images": [{"thumbnail_url": null}]},
          {"uid": "no-images"},
          {"uid": "good", "images": [{"thumbnail_url": "https://example.com/good.jpg"}]}
        ]
        """)

        let references = try APIDataFiles(directory: directory).thumbnailReferences()

        XCTAssertEqual(references.map(\.uid), ["good"])
    }

    /// The org's API reports `"processing"` in place of a URL while an upload is still
    /// being converted, and has served `ftp:`/relative values in past years. None of
    /// those are downloadable, so they must not reach the fetcher.
    func testNonHTTPThumbnailValuesAreTreatedAsAbsent() throws {
        try writeRequiredFiles()
        try write("art", """
        [
          {"uid": "processing", "images": [{"thumbnail_url": "processing"}]},
          {"uid": "relative", "images": [{"thumbnail_url": "/images/foo.jpg"}]},
          {"uid": "ftp", "images": [{"thumbnail_url": "ftp://example.com/foo.jpg"}]},
          {"uid": "empty", "images": [{"thumbnail_url": ""}]},
          {"uid": "http-ok", "images": [{"thumbnail_url": "http://example.com/ok.jpg"}]},
          {"uid": "https-ok", "images": [{"thumbnail_url": "https://example.com/ok.jpg"}]}
        ]
        """)

        let references = try APIDataFiles(directory: directory).thumbnailReferences()

        XCTAssertEqual(Set(references.map(\.uid)), ["http-ok", "https-ok"])
    }

    func testAnUnusableFirstThumbnailFallsThroughToTheNextOne() throws {
        try writeRequiredFiles()
        try write("art", """
        [{"uid": "mixed", "images": [
          {"thumbnail_url": "processing"},
          {"thumbnail_url": "https://example.com/usable.jpg"}
        ]}]
        """)

        let references = try APIDataFiles(directory: directory).thumbnailReferences()

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references[0].remoteURL.absoluteString, "https://example.com/usable.jpg")
    }

    func testFirstThumbnailWinsWhenAnObjectHasSeveral() throws {
        try writeRequiredFiles()
        try write("art", """
        [{"uid": "multi", "images": [
          {"thumbnail_url": "https://example.com/first.jpg"},
          {"thumbnail_url": "https://example.com/second.jpg"}
        ]}]
        """)

        let references = try APIDataFiles(directory: directory).thumbnailReferences()

        XCTAssertEqual(references.count, 1)
        XCTAssertEqual(references[0].remoteURL.absoluteString, "https://example.com/first.jpg")
    }
}
