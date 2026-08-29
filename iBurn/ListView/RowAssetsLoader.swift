//
//  RowAssetsLoader.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import Foundation
import UIKit

@MainActor
final class RowAssetsLoader: ObservableObject {
    @Published private(set) var thumbnail: UIImage?
    @Published private(set) var colors: BRCImageColors?
    @Published private(set) var audioURL: URL?

    private let objectID: String
    private let provider: MediaAssetProviding

    private var didStart = false
    private var assetsTask: Task<Void, Never>?
    private var colorsTask: Task<Void, Never>?

    private nonisolated(unsafe) static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 250
        return cache
    }()

    nonisolated(unsafe) static let colorsCache: NSCache<NSString, BRCImageColors> = {
        let cache = NSCache<NSString, BRCImageColors>()
        cache.countLimit = 500
        return cache
    }()

    private nonisolated(unsafe) static let audioURLCache: NSCache<NSString, NSURL> = {
        let cache = NSCache<NSString, NSURL>()
        cache.countLimit = 500
        return cache
    }()

    /// Objects that have no thumbnail / no audio on disk.
    ///
    /// `NSCache` can't hold `nil`, so a miss gets its own entry. Without it every rebuild
    /// of a media-free row (which is most of them) would go back to the filesystem, and
    /// resolving a media URL is not free: it stats the caches directory and then asks the
    /// media bundle. `NSCache` is thread-safe, so the background loader writes it directly.
    private nonisolated(unsafe) static let missingAssetCache: NSCache<NSString, NSNumber> = {
        let cache = NSCache<NSString, NSNumber>()
        cache.countLimit = 2000
        return cache
    }()

    init(
        objectID: String,
        provider: MediaAssetProviding = BRCMediaAssetProvider()
    ) {
        self.objectID = objectID
        self.provider = provider

        // Prime from in-memory caches so the first render doesn't flicker if already loaded.
        // This is the only work the initializer does: everything below it touches the
        // filesystem, and a search that lands fifty rows at once would otherwise run fifty
        // stat-and-decode passes on the main thread before the next keystroke could draw.
        let cacheKey = objectID as NSString
        self.thumbnail = Self.thumbnailCache.object(forKey: cacheKey)
        self.colors = Self.colorsCache.object(forKey: cacheKey)
        self.audioURL = Self.audioURLCache.object(forKey: cacheKey) as URL?

        loadAssetsIfNeeded()
    }

    /// Resolve and decode whatever the in-memory caches didn't already have, off the main
    /// thread. Rows whose assets were warm never get here.
    private func loadAssetsIfNeeded() {
        let needsThumbnail = thumbnail == nil && !Self.isKnownMissing(.thumbnail, objectID: objectID)
        let needsAudio = audioURL == nil && !Self.isKnownMissing(.audio, objectID: objectID)
        guard needsThumbnail || needsAudio else { return }

        let objectID = self.objectID
        let provider = self.provider
        assetsTask?.cancel()
        // Strong capture: the task is a single disk read and decode, and it releases the
        // closure the moment it finishes, so at worst a scrolled-away row's loader lives a
        // few milliseconds longer than its view.
        assetsTask = Task.detached(priority: .userInitiated) { [self] in
            var image: UIImage?
            if needsThumbnail {
                if let url = provider.localThumbnailURL(objectID: objectID) {
                    // `preparingForDisplay()` does the JPEG decode here rather than leaving
                    // it for the render server to trigger on the main thread at draw time.
                    image = UIImage(contentsOfFile: url.path)?.preparingForDisplay()
                }
                if image == nil {
                    Self.markMissing(.thumbnail, objectID: objectID)
                }
            }
            if Task.isCancelled { return }

            var audio: URL?
            if needsAudio {
                audio = provider.localAudioURL(objectID: objectID)
                if audio == nil {
                    Self.markMissing(.audio, objectID: objectID)
                }
            }
            if Task.isCancelled { return }

            let cacheKey = objectID as NSString
            if let image {
                Self.thumbnailCache.setObject(image, forKey: cacheKey)
            }
            if let audio {
                Self.audioURLCache.setObject(audio as NSURL, forKey: cacheKey)
            }

            await self.apply(thumbnail: image, audioURL: audio)
        }
    }

    private func apply(thumbnail: UIImage?, audioURL: URL?) {
        guard !Task.isCancelled else { return }
        if let thumbnail, self.thumbnail == nil {
            self.thumbnail = thumbnail
        }
        if let audioURL, self.audioURL == nil {
            self.audioURL = audioURL
        }
        // The thumbnail is what colors are extracted from, so a row that asked for colors
        // before the image existed gets served now.
        extractColorsIfNeeded()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        extractColorsIfNeeded()
    }

    private func extractColorsIfNeeded() {
        guard didStart, Appearance.useImageColorsTheming, colors == nil else { return }
        guard colorsTask == nil, let image = thumbnail else { return }

        let objectID = self.objectID
        colorsTask = Task.detached(priority: .utility) {
            if Task.isCancelled { return }
            let extracted = image.brc_extractColors()
            if Task.isCancelled { return }
            guard let extracted else { return }

            await MainActor.run {
                if Task.isCancelled { return }
                let cacheKey = objectID as NSString
                Self.colorsCache.setObject(extracted, forKey: cacheKey)
                self.colors = extracted
            }
        }
    }

    deinit {
        assetsTask?.cancel()
        colorsTask?.cancel()
    }

    // MARK: - Missing-asset bookkeeping

    private enum AssetKind: String {
        case thumbnail
        case audio
    }

    private nonisolated static func missingKey(_ kind: AssetKind, objectID: String) -> NSString {
        "\(kind.rawValue):\(objectID)" as NSString
    }

    private nonisolated static func isKnownMissing(_ kind: AssetKind, objectID: String) -> Bool {
        missingAssetCache.object(forKey: missingKey(kind, objectID: objectID)) != nil
    }

    private nonisolated static func markMissing(_ kind: AssetKind, objectID: String) {
        missingAssetCache.setObject(true as NSNumber, forKey: missingKey(kind, objectID: objectID))
    }
}
