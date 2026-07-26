import XCTest
@testable import playa_seed

final class MediaCatalogTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("playa-media-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func touch(_ name: String) throws {
        try Data("x".utf8).write(to: directory.appendingPathComponent(name))
    }

    func testMissingDirectoryThrows() {
        let absent = directory.appendingPathComponent("nope")
        XCTAssertThrowsError(try MediaCatalog(directory: absent))
    }

    func testCatalogIndexesJPEGsByUID() throws {
        try touch("abc123.jpg")
        try touch("def456.jpg")

        let catalog = try MediaCatalog(directory: directory)

        XCTAssertEqual(catalog.availableUIDs, ["abc123", "def456"])
        XCTAssertEqual(catalog.url(for: "abc123")?.lastPathComponent, "abc123.jpg")
        XCTAssertNil(catalog.url(for: "missing"))
    }

    func testNonJPEGsAndDotfilesAreIgnored() throws {
        try touch("real.jpg")
        try touch("notes.txt")
        try touch("audio.mp3")
        try touch(".DS_Store")
        try touch(".hidden.jpg")

        let catalog = try MediaCatalog(directory: directory)

        XCTAssertEqual(catalog.availableUIDs, ["real"])
    }

    func testRefreshPicksUpNewlyDownloadedFiles() throws {
        try touch("first.jpg")
        var catalog = try MediaCatalog(directory: directory)
        XCTAssertNil(catalog.url(for: "second"))

        try touch("second.jpg")
        try catalog.refresh()

        XCTAssertEqual(catalog.availableUIDs, ["first", "second"])
        XCTAssertNotNil(catalog.url(for: "second"))
    }
}
