import XCTest
@testable import playa_seed

final class SeedOptionsTests: XCTestCase {

    private let root = "/tmp/iburn-fixture"

    private func parse(_ arguments: [String]) throws -> SeedOptions {
        try XCTUnwrap(try SeedOptions.parse(["--repo-root", root] + arguments))
    }

    func testDefaultsDeriveEveryPathFromTheRepositoryRoot() throws {
        let options = try parse([])

        XCTAssertEqual(options.year, 2026)
        XCTAssertEqual(options.dataRoot.path, "\(root)/Submodules/iBurn-Data/data/2026")
        XCTAssertEqual(options.apiDataDirectory.path, "\(root)/Submodules/iBurn-Data/data/2026/APIData/APIData.bundle")
        XCTAssertEqual(options.mediaDirectory.path, "\(root)/Submodules/iBurn-Data/data/2026/MediaFiles/MediaFiles.bundle")
        // One seed per app target — the phone and the watch each restore from their
        // own bundle.
        XCTAssertEqual(options.outputs.map(\.path), [
            "\(root)/iBurn/PlayaDB-2026.zip",
            "\(root)/iBurnWatch/PlayaDB-2026.zip",
        ])
        XCTAssertFalse(options.fetchMedia)
        XCTAssertFalse(options.skipColors)
    }

    func testYearFlagMovesDataAndOutputPathsTogether() throws {
        let options = try parse(["--year", "2027"])

        XCTAssertEqual(options.year, 2027)
        XCTAssertEqual(options.dataRoot.path, "\(root)/Submodules/iBurn-Data/data/2027")
        XCTAssertEqual(options.outputs.map(\.path), [
            "\(root)/iBurn/PlayaDB-2027.zip",
            "\(root)/iBurnWatch/PlayaDB-2027.zip",
        ])
    }

    func testExplicitPathsOverrideTheYearDerivedDefaults() throws {
        let options = try parse([
            "--year", "2027",
            "--data-root", "/data/elsewhere",
            "--output", "/out/seed.zip",
        ])

        XCTAssertEqual(options.dataRoot.path, "/data/elsewhere")
        XCTAssertEqual(options.mediaDirectory.path, "/data/elsewhere/MediaFiles/MediaFiles.bundle")
        XCTAssertEqual(options.outputs.map(\.path), ["/out/seed.zip"])
    }

    func testOutputIsRepeatable() throws {
        let options = try parse(["--output", "/out/a.zip", "--output", "/out/b.zip"])

        XCTAssertEqual(options.outputs.map(\.path), ["/out/a.zip", "/out/b.zip"])
    }

    func testBooleanFlags() throws {
        let options = try parse(["--fetch-media", "--skip-colors"])

        XCTAssertTrue(options.fetchMedia)
        XCTAssertTrue(options.skipColors)
    }

    func testHelpReturnsNoOptions() throws {
        XCTAssertNil(try SeedOptions.parse(["--help"]))
        XCTAssertNil(try SeedOptions.parse(["-h"]))
    }

    func testUnknownArgumentIsRejected() {
        XCTAssertThrowsError(try SeedOptions.parse(["--nope"]))
    }

    func testFlagMissingItsValueIsRejected() {
        XCTAssertThrowsError(try SeedOptions.parse(["--year"]))
        XCTAssertThrowsError(try SeedOptions.parse(["--output"]))
    }

    func testImplausibleYearIsRejected() {
        XCTAssertThrowsError(try SeedOptions.parse(["--year", "not-a-year"]))
        XCTAssertThrowsError(try SeedOptions.parse(["--year", "1999"]))
    }
}
