import CoreGraphics
import Foundation
import ImageIO
import PlayaColors
import PlayaDB

/// Extracts thumbnail colours for every object that has a bundled image, so the app
/// doesn't have to do it on first launch.
///
/// Uses the same `PlayaColors` extractor the app runs at runtime, so a colour baked
/// here is byte-identical to the one the device would have computed.
struct ColorBaker {
    let catalog: MediaCatalog
    /// Parallelism for decode + extraction. Defaults to the machine's core count.
    var concurrency = max(1, ProcessInfo.processInfo.activeProcessorCount)

    struct Result {
        var colors: [ThumbnailColors] = []
        /// Objects with a thumbnail on disk whose image couldn't be decoded.
        var unreadable: [String] = []
        /// Objects the API says have a thumbnail that isn't in the media bundle.
        var missingThumbnail: [String] = []
    }

    /// - Parameter uids: Object IDs known to reference a thumbnail.
    func bake(uids: [String], progress: (Int, Int) -> Void) async -> Result {
        var result = Result()

        var resolvable: [(uid: String, url: URL)] = []
        for uid in uids.sorted() {
            if let url = catalog.url(for: uid) {
                resolvable.append((uid, url))
            } else {
                result.missingThumbnail.append(uid)
            }
        }

        let total = resolvable.count
        var completed = 0

        await withTaskGroup(of: (String, ExtractedColors?).self) { group in
            var index = 0
            func addTask() {
                guard index < resolvable.count else { return }
                let item = resolvable[index]
                index += 1
                group.addTask {
                    (item.uid, Self.extractColors(at: item.url))
                }
            }

            for _ in 0..<min(concurrency, resolvable.count) { addTask() }

            while let (uid, extracted) = await group.next() {
                if let extracted {
                    result.colors.append(ThumbnailColors(objectId: uid, colors: extracted))
                } else {
                    result.unreadable.append(uid)
                }
                completed += 1
                progress(completed, total)
                addTask()
            }
        }

        // Stable order keeps the generated database byte-comparable between runs.
        result.colors.sort { $0.objectId < $1.objectId }
        result.unreadable.sort()
        return result
    }

    private static func extractColors(at url: URL) -> ExtractedColors? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return ImageColorExtractor.extract(from: image, quality: .high)
    }
}
