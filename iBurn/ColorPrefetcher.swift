import Foundation
import UIKit
import UIImageColors
import PlayaDB
import CocoaLumberjack

/// Background color extraction for thumbnails.
/// Computes missing colors for all objects with local thumbnail images,
/// then batch-writes to the `thumbnail_colors` table in a single transaction.
enum ColorPrefetcher {

    /// Prefetch colors for all objects that have local thumbnails but no cached colors.
    /// Should be called after thumbnail downloads complete.
    static func prefetchMissingColors(playaDB: PlayaDB) async {
        guard Appearance.useImageColorsTheming else { return }

        let cachedIDs: Set<String>
        do {
            cachedIDs = try await playaDB.fetchCachedColorObjectIDs()
        } catch {
            DDLogError("ColorPrefetcher: failed to fetch cached IDs: \(error)")
            cachedIDs = []
        }

        // Gather all UIDs with thumbnails (art + camp + MV)
        var allUIDs: [String] = []
        if let artURLs = try? await playaDB.fetchArtImageURLs() {
            allUIDs.append(contentsOf: artURLs.keys)
        }
        if let campURLs = try? await playaDB.fetchCampImageURLs() {
            allUIDs.append(contentsOf: campURLs.keys)
        }
        if let mvURLs = try? await playaDB.fetchMutantVehicleImageURLs() {
            allUIDs.append(contentsOf: mvURLs.keys)
        }

        let needsProcessing = allUIDs.filter { uid in
            !cachedIDs.contains(uid) && BRCMediaDownloader.localMediaURL("\(uid).jpg") != nil
        }

        guard !needsProcessing.isEmpty else {
            DDLogInfo("ColorPrefetcher: all \(allUIDs.count) objects already have cached colors")
            return
        }

        DDLogInfo("ColorPrefetcher: processing \(needsProcessing.count) objects")

        var batch: [ThumbnailColors] = []
        for uid in needsProcessing {
            autoreleasepool {
                let fileName = "\(uid).jpg"
                guard let fileURL = BRCMediaDownloader.localMediaURL(fileName),
                      let image = UIImage(contentsOfFile: fileURL.path),
                      let extracted = image.getColors(quality: .high)?.brc_ImageColors
                else { return }

                let tc = ThumbnailColors(objectId: uid, brcColors: extracted)
                batch.append(tc)
            }
        }

        if !batch.isEmpty {
            do {
                try await playaDB.saveThumbnailColorsBatch(batch)
                DDLogInfo("ColorPrefetcher: cached \(batch.count) new color entries")
            } catch {
                DDLogError("ColorPrefetcher: batch save failed: \(error)")
            }
        }
    }
}
