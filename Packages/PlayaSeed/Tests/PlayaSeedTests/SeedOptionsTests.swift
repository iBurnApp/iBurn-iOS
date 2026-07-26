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
        XCTAssertEqual(options.output.path, "\(root)/iBurn/PlayaDB-2026.zip")
        XCTAssertFalse(options.fetchMedia)
        XCTAssertFalse(options.skipColors)
    }

    func testYearFlagMovesDataAndOutputPathsTogether() throws {
        let options = try parse(["--year", "2027"])

        XCTAssertEqual(options.year, 2027)
        XCTAssertEqual(options.dataRoot.path, "\(root)/Submodules/iBurn-Data/data/2027")
        XCTAssertEqual(options.output.path, "\(root)/iBurn/PlayaDB-2027.zip")
    }

    func testExplicitPathsOverrideTheYearDerivedDefaults() throws {
        let options = try parse([
            "--year", "2027",
            "--data-root", "/data/elsewhere",
            "--output", "/out/seed.zip",
        ])

        XCTAssertEqual(options.dataRoot.path, "/data/elsewhere")
        XCTAssertEqual(options.mediaDirectory.path, "/data/elsewhere/MediaFiles/MediaFiles.bundle")
        XCTAssertEqual(options.output.path, "/out/seed.zip")
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
