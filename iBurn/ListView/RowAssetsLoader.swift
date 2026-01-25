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

    private let objectID: String
    private let provider: MediaAssetProviding

    private var didStart = false

    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 250
        return cache
    }()

    private static let colorsCache: NSCache<NSString, BRCImageColors> = {
        let cache = NSCache<NSString, BRCImageColors>()
        cache.countLimit = 500
        return cache
    }()

    init(
        objectID: String,
        provider: MediaAssetProviding = BRCMediaAssetProvider()
    ) {
        self.objectID = objectID
        self.provider = provider
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        let cacheKey = objectID as NSString
        if let cachedImage = Self.thumbnailCache.object(forKey: cacheKey) {
            thumbnail = cachedImage
        }
        if let cachedColors = Self.colorsCache.object(forKey: cacheKey) {
            colors = cachedColors
        }

        guard thumbnail == nil else { return }
        guard let url = provider.localThumbnailURL(objectID: objectID) else { return }
        let path = url.path
        let keyString = objectID

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let image = UIImage(contentsOfFile: path) else { return }

            let extractedColors: BRCImageColors?
            if Appearance.useImageColorsTheming {
                extractedColors = image.getColors(quality: .high)?.brc_ImageColors
            } else {
                extractedColors = nil
            }

            DispatchQueue.main.async {
                guard let self else { return }
                let cacheKey = keyString as NSString
                Self.thumbnailCache.setObject(image, forKey: cacheKey)
                self.thumbnail = image

                if let extractedColors {
                    Self.colorsCache.setObject(extractedColors, forKey: cacheKey)
                    self.colors = extractedColors
                }
            }
        }
    }
}
