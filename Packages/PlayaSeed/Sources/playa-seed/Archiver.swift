import Foundation

/// Zips the finished database into the archive the app ships.
///
/// `PlayaDBSeeder.restoreBundledSeedIfNeeded` looks for a `PlayaDB.sqlite` entry at the
/// root of the zip, so the file is archived without its directory path.
enum Archiver {
    static func archive(databaseAt database: URL, to output: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // zip appends to an existing archive, so start clean.
        try? fileManager.removeItem(at: output)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        // -j flattens paths (entry becomes "PlayaDB.sqlite"), -X drops extra file
        // attributes so the archive is reproducible across machines.
        process.arguments = ["-j", "-q", "-X", output.path, database.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        // Read before waiting so a chatty failure can't deadlock on a full pipe.
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "zip exited \(process.terminationStatus)"
            throw SeedError.archiveFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard fileManager.fileExists(atPath: output.path) else {
            throw SeedError.archiveFailed("zip reported success but produced no file at \(output.path)")
        }
    }
}
