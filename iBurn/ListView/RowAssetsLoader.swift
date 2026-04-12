//
//  RowAssetsLoader.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import Foundation
import UIKit
import UIImageColors

@MainActor
final class RowAssetsLoader: ObservableObject {
    @Published private(set) var thumbnail: UIImage?
    @Published private(set) var colors: BRCImageColors?
    @Published private(set) var audioURL: URL?

    private let objectID: String
    private let provider: MediaAssetProviding

    private var didStart = false
    private var loadTask: Task<Void, Never>?

    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 250
        return cache
    }()

    static let colorsCache: NSCache<NSString, BRCImageColors> = {
        let cache = NSCache<NSString, BRCImageColors>()
        cache.countLimit = 500
        return cache
    }()

    private static let audioURLCache: NSCache<NSString, NSURL> = {
        let cache = NSCache<NSString, NSURL>()
        cache.countLimit = 500
        return cache
    }()

    init(
        objectID: String,
        provider: MediaAssetProviding = BRCMediaAssetProvider()
    ) {
        self.objectID = objectID
        self.provider = provider

        // Prime from in-memory caches so the first render doesn't flicker if already loaded.
        let cacheKey = objectID as NSString
        self.thumbnail = Self.thumbnailCache.object(forKey: cacheKey)
        self.colors = Self.colorsCache.object(forKey: cacheKey)
        self.audioURL = Self.audioURLCache.object(forKey: cacheKey) as URL?

        // The legacy thumbnail cache is on-disk and is fast to load.
        // Load the thumbnail synchronously (colors can be computed later).
        if self.thumbnail == nil,
           let url = provider.localThumbnailURL(objectID: objectID) {
            if let image = UIImage(contentsOfFile: url.path) {
                Self.thumbnailCache.setObject(image, forKey: cacheKey)
                self.thumbnail = image
            }
        }

        // Audio tour is sourced from the filesystem/bundle. This is also fast to resolve.
        if self.audioURL == nil,
           let url = provider.localAudioURL(objectID: objectID) {
            Self.audioURLCache.setObject(url as NSURL, forKey: cacheKey)
            self.audioURL = url
        }
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        guard Appearance.useImageColorsTheming, colors == nil else { return }
        guard let image = thumbnail else { return }

        let objectID = self.objectID
        loadTask?.cancel()
        loadTask = Task.detached(priority: .utility) {
            if Task.isCancelled { return }
            let extracted = image.getColors(quality: .high)?.brc_ImageColors
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
        loadTask?.cancel()
    }
}
