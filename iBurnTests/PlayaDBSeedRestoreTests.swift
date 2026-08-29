//
//  PlayaDBSeedRestoreTests.swift
//  iBurnTests
//
//  Created by Claude Code on 7/18/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import XCTest
import Zip
@testable import iBurn

/// Exercises PlayaDBSeeder.restoreBundledSeedIfNeeded — the synchronous
/// "restore pre-populated DB from bundle" step that runs before PlayaDB opens.
final class PlayaDBSeedRestoreTests: XCTestCase {

    private var workDir: URL!
    private var documentsDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayaDBSeedRestoreTests-\(UUID().uuidString)")
        documentsDir = workDir.appendingPathComponent("Documents")
        try FileManager.default.createDirectory(at: documentsDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workDir {
            try? FileManager.default.removeItem(at: workDir)
        }
        workDir = nil
        documentsDir = nil
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    /// Minimal but valid SQLite file header so fixtures resemble a real DB. The
    /// restore step never opens the file, so any recognizable bytes suffice.
    private func sqliteBytes(marker: String) -> Data {
        var data = Data("SQLite format 3\u{0}".utf8)
        data.append(Data(marker.utf8))
        return data
    }

    /// Writes `contents` to a `PlayaDB.sqlite` file and zips it into a single-entry
    /// archive, matching the shipped `PlayaDB-<year>.zip` layout.
    private func makeSeedZip(contents: Data) throws -> URL {
        let stagingDir = workDir.appendingPathComponent("stage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let sqliteURL = stagingDir.appendingPathComponent("PlayaDB.sqlite")
        try contents.write(to: sqliteURL)

        let zipURL = workDir.appendingPathComponent("seed-\(UUID().uuidString).zip")
        try Zip.zipFiles(paths: [sqliteURL], zipFilePath: zipURL, password: nil, progress: nil)
        return zipURL
    }

    private var destinationURL: URL {
        documentsDir.appendingPathComponent("PlayaDB.sqlite")
    }

    // MARK: - Tests

    /// (a) Restores when the destination is absent.
    func testRestoresWhenDestinationAbsent() throws {
        let expected = sqliteBytes(marker: "seed-payload")
        let zipURL = try makeSeedZip(contents: expected)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))

        PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL: documentsDir, seedZipURL: zipURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        let restored = try Data(contentsOf: destinationURL)
        XCTAssertEqual(restored, expected)
    }

    /// (b) No-op when a database already exists — the file is left untouched.
    func testNoOpWhenDestinationExists() throws {
        let existing = sqliteBytes(marker: "existing-install")
        try existing.write(to: destinationURL)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let originalModified = try XCTUnwrap(originalAttributes[.modificationDate] as? Date)

        let zipURL = try makeSeedZip(contents: sqliteBytes(marker: "should-not-apply"))
        PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL: documentsDir, seedZipURL: zipURL)

        let after = try Data(contentsOf: destinationURL)
        XCTAssertEqual(after, existing, "existing DB must not be overwritten")

        let afterAttributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let afterModified = try XCTUnwrap(afterAttributes[.modificationDate] as? Date)
        XCTAssertEqual(afterModified, originalModified, "existing DB must not be rewritten")
    }

    /// (c) No-op when the seed is missing — no database is created.
    func testNoOpWhenSeedMissing() throws {
        let missingZip = workDir.appendingPathComponent("does-not-exist.zip")
        PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL: documentsDir, seedZipURL: missingZip)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    /// (d) A corrupt zip (garbage bytes) must not crash and must leave no DB behind.
    func testCorruptZipLeavesDestinationAbsent() throws {
        let corruptZip = workDir.appendingPathComponent("corrupt-\(UUID().uuidString).zip")
        try Data("this is not a zip file".utf8).write(to: corruptZip)

        PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL: documentsDir, seedZipURL: corruptZip)

        XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    /// (e) Stray WAL/SHM sidecars from a deleted DB are removed on restore.
    func testRestoreClearsStrayWalAndShm() throws {
        let staleWal = documentsDir.appendingPathComponent("PlayaDB.sqlite-wal")
        let staleShm = documentsDir.appendingPathComponent("PlayaDB.sqlite-shm")
        try Data("stale-wal".utf8).write(to: staleWal)
        try Data("stale-shm".utf8).write(to: staleShm)

        let expected = sqliteBytes(marker: "fresh-seed")
        let zipURL = try makeSeedZip(contents: expected)

        PlayaDBSeeder.restoreBundledSeedIfNeeded(documentsURL: documentsDir, seedZipURL: zipURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try Data(contentsOf: destinationURL), expected)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleWal.path), "stray -wal must be removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleShm.path), "stray -shm must be removed")
    }
}
