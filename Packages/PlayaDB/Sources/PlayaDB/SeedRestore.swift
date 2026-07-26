import Foundation

/// Restores a pre-populated `PlayaDB.sqlite` from a seed archive before the database
/// is opened, so a fresh install doesn't have to import JSON on device.
///
/// Lives in PlayaDB rather than an app target because both the phone and the watch
/// perform the same restore, and the rules for what makes a restore safe (never touch
/// an existing install, never leave a partial file behind) belong with the database.
///
/// The archive format is the caller's business: pass an `unzip` closure so PlayaDB
/// doesn't take a dependency on a compression library. Seeds are built by
/// `Packages/PlayaSeed` and contain a single `PlayaDB.sqlite` entry at the archive root.
public enum PlayaDBSeedRestore {

    /// What a restore attempt did, so callers can log at the right level.
    public enum Outcome: Equatable {
        /// A database already exists — an upgrade, not a fresh install.
        case skippedDatabaseExists
        /// No seed shipped with this build. Expected: seeds are gitignored local
        /// artifacts, and the JSON import path covers their absence.
        case skippedNoSeed
        /// Restored; the database is ready to open.
        case restored
        /// The seed was present but unusable. The destination is left absent so the
        /// JSON import path takes over.
        case failed(String)
    }

    /// Documents-directory URL where PlayaDB lives, matching `PlayaDBImpl`'s default
    /// on-disk path resolution.
    public static var defaultDocumentsURL: URL {
        URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    }

    /// The database filename inside both the seed archive and the Documents directory.
    public static let databaseFileName = "PlayaDB.sqlite"

    /// Restores the seed when — and only when — no database exists yet.
    ///
    /// Degrades gracefully in every failure mode: a missing seed, a corrupt archive, or
    /// an interrupted move all leave the destination absent so the JSON import path can
    /// take over. Existing installs are never touched.
    ///
    /// - Parameters:
    ///   - documentsURL: Destination directory for `PlayaDB.sqlite`.
    ///   - seedZipURL: The seed archive, or nil when this build ships without one.
    ///   - unzip: Extracts the archive (first argument) into a directory (second).
    @discardableResult
    public static func restoreIfNeeded(
        documentsURL: URL = PlayaDBSeedRestore.defaultDocumentsURL,
        seedZipURL: URL?,
        unzip: (_ archive: URL, _ destination: URL) throws -> Void
    ) -> Outcome {
        let fileManager = FileManager.default
        let destination = documentsURL.appendingPathComponent(databaseFileName)

        // Existing installs keep their database; needsImport() handles data updates.
        guard !fileManager.fileExists(atPath: destination.path) else { return .skippedDatabaseExists }
        guard let seedZipURL, fileManager.fileExists(atPath: seedZipURL.path) else { return .skippedNoSeed }

        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("PlayaDBSeed-\(UUID().uuidString)")
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDirectory) }

            try unzip(seedZipURL, tempDirectory)

            let unzippedDatabase = tempDirectory.appendingPathComponent(databaseFileName)
            guard fileManager.fileExists(atPath: unzippedDatabase.path) else {
                return .failed("\(seedZipURL.lastPathComponent) has no \(databaseFileName) entry")
            }

            // Ensure Documents exists, then clear stray WAL/SHM sidecars left by a
            // previously deleted database — they'd corrupt the freshly restored file.
            try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            for sidecar in ["\(databaseFileName)-wal", "\(databaseFileName)-shm"] {
                try? fileManager.removeItem(at: documentsURL.appendingPathComponent(sidecar))
            }

            try fileManager.moveItem(at: unzippedDatabase, to: destination)
            return .restored
        } catch {
            // Never leave a partial/corrupt database behind — JSON import takes over.
            try? fileManager.removeItem(at: destination)
            return .failed("\(error)")
        }
    }
}
