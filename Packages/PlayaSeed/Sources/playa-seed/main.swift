import Foundation

let logger = Logger()

do {
    guard let options = try SeedOptions.parse(Array(CommandLine.arguments.dropFirst())) else {
        print(SeedOptions.usage)
        exit(0)
    }

    // scripts/mock_locations.js writes this sentinel when it fabricates placement
    // data from a previous year. Refusing here (with no override) guarantees a
    // production seed can never be baked from mock locations.
    let mockSentinel = options.apiDataDirectory.appendingPathComponent("MOCK_LOCATIONS")
    if FileManager.default.fileExists(atPath: mockSentinel.path) {
        FileHandle.standardError.write("""
        error: \(mockSentinel.path) exists — the API bundle contains MOCK location data.
        Revert it first: node scripts/mock_locations.js revert (in Submodules/iBurn-Data)
        \n
        """.data(using: .utf8)!)
        exit(1)
    }

    logger.step("Building the \(options.year) PlayaDB seed")
    logger.info("data:   \(options.dataRoot.path)")
    logger.info("media:  \(options.mediaDirectory.path)")
    for output in options.outputs {
        logger.info("output: \(output.path)")
    }

    let summary = try await SeedBuilder(options: options, log: logger).build()

    print("")
    logger.step("Done")
    logger.info("art \(summary.art) · camps \(summary.camps) · events \(summary.events) · mutant vehicles \(summary.mutantVehicles)")
    logger.info("thumbnail colours: \(summary.colors)")
    if summary.mediaDownloaded > 0 {
        logger.info("thumbnails downloaded: \(summary.mediaDownloaded)")
    }
    logger.info("archives: \(summary.archives.count) × \(summary.archiveBytes / 1024) KB")
    for archive in summary.archives {
        logger.info("  \(archive.path)")
    }

    // Surface data gaps rather than silently shipping an incomplete seed.
    if !summary.thumbnailsMissing.isEmpty {
        logger.warn("\(summary.thumbnailsMissing.count) object(s) reference a thumbnail that is not in the media bundle; re-run with --fetch-media. First few: \(summary.thumbnailsMissing.prefix(5).joined(separator: ", "))")
    }
    if !summary.thumbnailsUnreadable.isEmpty {
        logger.warn("\(summary.thumbnailsUnreadable.count) thumbnail(s) could not be decoded: \(summary.thumbnailsUnreadable.prefix(5).joined(separator: ", "))")
    }
    for failure in summary.mediaFailed.prefix(10) {
        logger.warn("download failed for \(failure.uid): \(failure.error)")
    }
} catch {
    FileHandle.standardError.write("error: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
