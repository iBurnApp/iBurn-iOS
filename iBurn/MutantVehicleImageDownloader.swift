import Foundation
import PlayaDB
import CocoaLumberjack

/// Downloads mutant vehicle thumbnail images from remote URLs and caches them locally.
/// Uses the same `<uid>.jpg` naming convention as `BRCMediaDownloader` so that
/// `BRCMediaAssetProvider` / `RowAssetsLoader` picks them up automatically.
final class MutantVehicleImageDownloader {

    private let playaDB: PlayaDB
    private let session: URLSession

    init(playaDB: PlayaDB, session: URLSession = .shared) {
        self.playaDB = playaDB
        self.session = session
    }

    /// Downloads images for all mutant vehicles that don't have a local cache yet.
    func downloadUncachedImages() {
        Task.detached(priority: .utility) { [playaDB, session] in
            let imageURLs: [String: URL]
            do {
                imageURLs = try await playaDB.fetchMutantVehicleImageURLs()
            } catch {
                DDLogError("MV image download: failed to fetch URLs: \(error)")
                return
            }

            for (uid, remoteURL) in imageURLs {
                let fileName = "\(uid).jpg"
                if BRCMediaDownloader.localMediaURL(fileName) != nil {
                    continue
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
                    DDLogInfo("MV image cached: \(uid)")
                } catch {
                    DDLogError("MV image download failed for \(uid): \(error)")
                }
            }
        }
    }
}
