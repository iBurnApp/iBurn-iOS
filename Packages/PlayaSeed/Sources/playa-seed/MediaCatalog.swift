import Foundation

/// The thumbnails present on disk in a year's `MediaFiles.bundle`.
///
/// Files are named `<uid>.jpg`, matching `BRCMediaDownloader.localMediaURL(_:)` in the
/// app, so a uid resolved here is the same file the device would use.
struct MediaCatalog {
    let directory: URL
    private(set) var availableUIDs: Set<String>

    init(directory: URL) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw SeedError.missingMediaDirectory(directory)
        }
        self.directory = directory
        self.availableUIDs = try Self.scan(directory)
    }

    private static func scan(_ directory: URL) throws -> Set<String> {
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return Set(
            names
                .filter { $0.hasSuffix(".jpg") && !$0.hasPrefix(".") }
                .map { String($0.dropLast(4)) }
        )
    }

    func url(for uid: String) -> URL? {
        guard availableUIDs.contains(uid) else { return nil }
        return directory.appendingPathComponent("\(uid).jpg")
    }

    /// Re-reads the directory; call after downloading new thumbnails.
    mutating func refresh() throws {
        availableUIDs = try Self.scan(directory)
    }
}
