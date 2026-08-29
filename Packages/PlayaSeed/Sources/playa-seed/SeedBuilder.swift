import Foundation
import PlayaDB

/// Builds a pre-populated `PlayaDB.sqlite` and zips it for the app to restore on first
/// launch, replacing the old routine of running the app once and pulling the database
/// out of the simulator container by hand.
struct SeedBuilder {
    let options: SeedOptions
    let log: Logger

    struct Summary {
        var art = 0
        var camps = 0
        var events = 0
        var mutantVehicles = 0
        var colors = 0
        var thumbnailsMissing: [String] = []
        var thumbnailsUnreadable: [String] = []
        var mediaDownloaded = 0
        var mediaFailed: [(uid: String, error: String)] = []
        var archiveBytes = 0
        var archives: [URL] = []
    }

    func build() async throws -> Summary {
        var summary = Summary()

        guard FileManager.default.fileExists(atPath: options.apiDataDirectory.path) else {
            throw SeedError.missingDataDirectory(options.apiDataDirectory)
        }
        let dataFiles = try APIDataFiles(directory: options.apiDataDirectory)

        // 1. Optionally top up the media bundle before anything reads it.
        var catalog = try MediaCatalog(directory: options.mediaDirectory)
        if options.fetchMedia {
            let references = try dataFiles.thumbnailReferences()
            let missing = references.filter { !catalog.availableUIDs.contains($0.uid) }
            if missing.isEmpty {
                log.info("Media bundle already has every referenced thumbnail (\(references.count)).")
            } else {
                log.step("Downloading \(missing.count) missing thumbnail(s)…")
                let result = await MediaFetcher(destination: options.mediaDirectory).fetch(missing)
                summary.mediaDownloaded = result.downloaded.count
                summary.mediaFailed = result.failed
                try catalog.refresh()
                log.info("Downloaded \(result.downloaded.count), failed \(result.failed.count).")
            }
        }

        // 2. Build the database in a scratch directory. Working on a throwaway copy
        //    means a failed run can never leave a half-written seed behind.
        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("playa-seed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        let databaseURL = workDirectory.appendingPathComponent("PlayaDB.sqlite")

        // Populating in a separate scope closes the database connection (flushing its
        // WAL) before the file is archived.
        try await populate(databaseAt: databaseURL, from: dataFiles, catalog: catalog, into: &summary)

        // 4. Archive — one copy per app target, since each restores from its own bundle.
        for output in options.outputs {
            log.step("Writing \(output.path.replacingOccurrences(of: options.repositoryRoot.path + "/", with: ""))…")
            try Archiver.archive(databaseAt: databaseURL, to: output)
            summary.archives.append(output)
            summary.archiveBytes = (try? FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
        }

        return summary
    }

    private func populate(
        databaseAt databaseURL: URL,
        from dataFiles: APIDataFiles,
        catalog: MediaCatalog,
        into summary: inout Summary
    ) async throws {
        let db = try createPlayaDB(atPath: databaseURL.path)

        log.step("Importing \(options.year) API data…")
        try await db.importFromData(
            artData: dataFiles.art,
            campData: dataFiles.camp,
            eventData: dataFiles.event,
            mvData: dataFiles.mutantVehicle,
            updateData: dataFiles.update
        )

        summary.art = try await db.fetchArt().count
        summary.camps = try await db.fetchCamps().count
        summary.events = try await db.fetchEvents().count
        summary.mutantVehicles = try await db.fetchMutantVehicles().count
        guard summary.art > 0, summary.camps > 0 else { throw SeedError.emptyDatabase }
        log.info("Imported \(summary.art) art, \(summary.camps) camps, \(summary.events) event occurrences, \(summary.mutantVehicles) mutant vehicles.")

        // 3. Bake thumbnail colours for everything the app would otherwise compute on
        //    first launch. Uses the same object set as ColorPrefetcher does at runtime.
        if options.skipColors {
            log.info("Skipping colour extraction (--skip-colors).")
        } else {
            var uids: [String] = []
            uids.append(contentsOf: try await db.fetchArtImageURLs().keys)
            uids.append(contentsOf: try await db.fetchCampImageURLs().keys)
            uids.append(contentsOf: try await db.fetchMutantVehicleImageURLs().keys)

            log.step("Extracting colours for \(uids.count) thumbnail(s)…")
            let baker = ColorBaker(catalog: catalog)
            let result = await baker.bake(uids: uids) { done, total in
                log.progress(done, of: total)
            }
            log.endProgress()

            try await db.saveThumbnailColorsBatch(result.colors)
            summary.colors = result.colors.count
            summary.thumbnailsMissing = result.missingThumbnail.sorted()
            summary.thumbnailsUnreadable = result.unreadable
            log.info("Cached \(result.colors.count) colour rows.")
        }

        log.step("Compacting database…")
        try await db.compactForDistribution()
    }
}
