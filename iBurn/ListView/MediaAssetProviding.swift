//
//  MediaAssetProviding.swift
//  iBurn
//
//  Created by Codex on 1/25/26.
//

import Foundation

protocol MediaAssetProviding {
    func localThumbnailURL(objectID: String) -> URL?
}

/// Default implementation that matches the legacy media cache layout:
/// `Documents/MediaFiles/<uid>.jpg` (or bundled media if present).
final class BRCMediaAssetProvider: MediaAssetProviding {
    func localThumbnailURL(objectID: String) -> URL? {
        BRCMediaDownloader.localMediaURL("\(objectID).jpg")
    }
}

