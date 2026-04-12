import Foundation
import PlayaDB
import CocoaLumberjack

/// Downloads art and camp thumbnail images from remote URLs and caches them locally.
/// Uses the same `<uid>.jpg` naming convention as `BRCMediaDownloader` so that
/// `BRCMediaAssetProvider` / `RowAssetsLoader` picks them up automatically.
final class ThumbnailImageDownloader {

    private let playaDB: PlayaDB
    private let session: URLSession

    init(playaDB: PlayaDB, session: URLSession = .shared) {
        self.playaDB = playaDB
        self.session = session
    }

    /// Downloads images for all art and camp objects that don't have a valid local cache yet.
    /// Returns a Task whose value is the set of newly downloaded UIDs.
    @discardableResult
    func downloadUncachedImages() -> Task<Set<String>, Never> {
        Task.detached(priority: .utility) { [playaDB, session] in
            var newlyDownloaded: Set<String> = []
            var imageURLs: [String: URL] = [:]
            do {
                let artURLs = try await playaDB.fetchArtImageURLs()
                let campURLs = try await playaDB.fetchCampImageURLs()
                imageURLs.merge(artURLs) { first, _ in first }
                imageURLs.merge(campURLs) { first, _ in first }
            } catch {
                DDLogError("Thumbnail download: failed to fetch URLs: \(error)")
                return newlyDownloaded
            }

            for (uid, remoteURL) in imageURLs {
                let fileName = "\(uid).jpg"
                // Validate existing file: must exist and be non-empty
                if let localURL = BRCMediaDownloader.localMediaURL(fileName) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                       let size = attrs[.size] as? Int, size > 0 {
                        continue
                    }
                    try? FileManager.default.removeItem(at: localURL)
                }

                do {
                    let (tempURL, _) = try await session.download(from: remoteURL)
                    let destURL = BRCMediaDownloader.localCacheURL(fileName)

                    let parent = destURL.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: parent.path) {
                        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                    }

                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    try (destURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
                    newlyDownloaded.insert(uid)
                    DDLogInfo("Thumbnail cached: \(uid)")
                } catch {
                    DDLogError("Thumbnail download failed for \(uid): \(error)")
                }
            }
            return newlyDownloaded
        }
    }
}
