import PlayaAPITestHelpers
import XCTest
@testable import PlayaDB

/// Exercises the seed-restore rules shared by the phone and watch apps. The unzip step
/// is injected, so these tests drive every outcome without a compression library.
final class SeedRestoreTests: XCTestCase {

    private var workDirectory: URL!
    private var documentsDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SeedRestoreTests-\(UUID().uuidString)")
        documentsDirectory = workDirectory.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workDirectory {
            try? FileManager.default.removeItem(at: workDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private var destination: URL {
        documentsDirectory.appendingPathComponent("PlayaDB.sqlite")
    }

    /// A stand-in archive. Its contents don't matter — the injected unzip decides what
    /// lands in the extraction directory.
    private func makeArchive(named name: String = "PlayaDB-2026.zip") throws -> URL {
        let url = workDirectory.appendingPathComponent(name)
        try Data("archive".utf8).write(to: url)
        return url
    }

    /// An unzip that writes `contents` as the expected `PlayaDB.sqlite` entry.
    private func unzipProducingDatabase(_ contents: String) -> (URL, URL) throws -> Void {
        { _, extractionDirectory in
            try Data(contents.utf8)
                .write(to: extractionDirectory.appendingPathComponent("PlayaDB.sqlite"))
        }
    }

    private func contentsOfDestination() throws -> String {
        String(decoding: try Data(contentsOf: destination), as: UTF8.self)
    }

    // MARK: - Happy path

    func testRestoresWhenNoDatabaseExists() throws {
        let archive = try makeArchive()

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: archive,
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(try contentsOfDestination(), "seeded")
    }

    func testCreatesDocumentsDirectoryWhenAbsent() throws {
        try FileManager.default.removeItem(at: documentsDirectory)
        let archive = try makeArchive()

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: archive,
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .restored)
        XCTAssertEqual(try contentsOfDestination(), "seeded")
    }

    /// A previously deleted database can leave WAL/SHM sidecars behind; pairing them with
    /// a freshly restored file would corrupt it.
    func testRestoreClearsStrayWalAndShmSidecars() throws {
        let wal = documentsDirectory.appendingPathComponent("PlayaDB.sqlite-wal")
        let shm = documentsDirectory.appendingPathComponent("PlayaDB.sqlite-shm")
        try Data("stale-wal".utf8).write(to: wal)
        try Data("stale-shm".utf8).write(to: shm)

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: try makeArchive(),
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .restored)
        XCTAssertFalse(FileManager.default.fileExists(atPath: wal.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shm.path))
    }

    // MARK: - Skips

    func testExistingDatabaseIsNeverOverwritten() throws {
        try Data("existing-install".utf8).write(to: destination)

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: try makeArchive(),
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .skippedDatabaseExists)
        XCTAssertEqual(try contentsOfDestination(), "existing-install")
    }

    func testNilSeedIsSkippedNotFailed() {
        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: nil,
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .skippedNoSeed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testMissingSeedFileIsSkippedNotFailed() {
        let absent = workDirectory.appendingPathComponent("does-not-exist.zip")

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: absent,
            unzip: unzipProducingDatabase("seeded")
        )

        XCTAssertEqual(outcome, .skippedNoSeed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - Failures leave the JSON import path clear

    func testArchiveWithoutADatabaseEntryFails() throws {
        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: try makeArchive(),
            unzip: { _, extractionDirectory in
                try Data("nope".utf8)
                    .write(to: extractionDirectory.appendingPathComponent("SomethingElse.txt"))
            }
        )

        guard case .failed = outcome else { return XCTFail("expected .failed, got \(outcome)") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testThrowingUnzipLeavesNoDatabaseBehind() throws {
        struct CorruptArchive: Error {}

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: try makeArchive(),
            unzip: { _, _ in throw CorruptArchive() }
        )

        guard case .failed = outcome else { return XCTFail("expected .failed, got \(outcome)") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - Restored database is usable

    /// The whole point of the restore: opening the destination afterwards must yield a
    /// working database with the seeded rows, not a fresh empty one.
    func testRestoredDatabaseOpensWithItsSeededRows() async throws {
        // Build a real database, then hand it to the restore as if it were unzipped.
        let sourceDirectory = workDirectory.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        let sourceDatabase = sourceDirectory.appendingPathComponent("PlayaDB.sqlite")

        let seeded = try createPlayaDB(atPath: sourceDatabase.path)
        try await seeded.importFromData(
            artData: MockAPIData.artJSON,
            campData: MockAPIData.campJSON,
            eventData: MockAPIData.eventJSON
        )
        try await seeded.compactForDistribution()
        let expectedArtCount = try await seeded.fetchArt().count
        XCTAssertGreaterThan(expectedArtCount, 0)

        let outcome = PlayaDBSeedRestore.restoreIfNeeded(
            documentsURL: documentsDirectory,
            seedZipURL: try makeArchive(),
            unzip: { _, extractionDirectory in
                try FileManager.default.copyItem(
                    at: sourceDatabase,
                    to: extractionDirectory.appendingPathComponent("PlayaDB.sqlite")
                )
            }
        )
        XCTAssertEqual(outcome, .restored)

        let restored = try createPlayaDB(atPath: destination.path)
        let restoredArt = try await restored.fetchArt()
        XCTAssertEqual(restoredArt.count, expectedArtCount)
    }
}
