//
//  BRCMediaDownloader.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/8/16.
//  Copyright 2016 Burning Man Earth. All rights reserved.

import Foundation
import CocoaLumberjackSwift


extension Bundle {
    
    /** Media files bundled w/ the app */
    static var bundledMedia: Bundle? {
        return Bundle.brc_mediaBundle
    }
}

/// Local paths for the media files (art/camp thumbnails, audio tour tracks) that ship in
/// `MediaFiles.bundle` and are copied into Documents on first use.
///
/// The old YapDatabase-driven background downloader lived here too; it was dead code by
/// 2026 (media arrives bundled, and `ThumbnailImageDownloader` /
/// `MutantVehicleImageDownloader` fetch anything missing straight from PlayaDB) and went
/// with the rest of the Yap stack. Only the path helpers remain.
public final class BRCMediaDownloader: NSObject {

    static let mediaFolderName = "MediaFiles"

    private static var mediaFilesPath: String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let folderName = BRCMediaDownloader.mediaFolderName
        let path = documentsPath.appendingPathComponent(folderName)
        return path
    }

    /** Copies media files like images/mp3s that were bundled with the app */
    private static func copyMediaFilesIfNeeded() {
        guard let bundle = Bundle.bundledMedia, let bundlePath = bundle.resourcePath else {
            return
        }
        let path = BRCMediaDownloader.mediaFilesPath
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.copyItem(atPath: bundlePath, toPath: path)
                var fileURL = URL(fileURLWithPath: path)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try fileURL.setResourceValues(resourceValues)
            } catch let error {
                DDLogError("Error copying media files \(error)")
            }
        }
    }

    /** This is where a local file WOULD be located, but the file may not be there */
    public static func localCacheURL(_ fileName: String) -> URL {
        let localCache = BRCMediaDownloader.mediaFilesPath
        let localURL = URL(fileURLWithPath: localCache)
        let fileURL = localURL.appendingPathComponent(fileName)
        return fileURL
    }

    /** Checks if file exists first, Prefer downloaded media over bundled */
    @objc public static func localMediaURL(_ fileName: String) -> URL? {
        copyMediaFilesIfNeeded()
        let fileURL = self.localCacheURL(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        let bundle = Bundle.bundledMedia
        let url = bundle?.url(forResource: fileName, withExtension: nil)
        return url
    }
}
