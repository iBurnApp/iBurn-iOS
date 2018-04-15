//
//  BRCDataImporter.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import Mapbox
import CocoaLumberjack



public extension BRCDataImporter {
    
    /** This is where Mapbox stores its tile cache */
    private static var mapTilesDirectory: URL {
        guard var cachesUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            let bundleId = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String else {
                fatalError("Could not get map tiles directory")
        }
        cachesUrl.appendPathComponent(bundleId)
        cachesUrl.appendPathComponent(".mapbox")
        return cachesUrl
    }
    
    /** Downloads offline tiles directly from official Mapbox server */
    @objc public static func downloadMapboxOfflineTiles() {
        let storage = MGLOfflineStorage.shared()
        let styleURL = URL(string: kBRCMapBoxStyleURL)!
        let bounds = MGLMapView.brc_bounds
        let region =  MGLTilePyramidOfflineRegion(styleURL: styleURL, bounds: bounds, fromZoomLevel: 13, toZoomLevel: 17)
        
        storage.addPack(for: region, withContext: Data(), completionHandler: { pack, error in
            if let pack = pack {
                pack.resume()
            } else if let error = error {
                DDLogError("Error downloading tiles: \(error)")
            }
        })
    }
    
    /** Copies the bundled Mapbox "offline" tiles to where Mapbox expects them */
    @objc public static func copyBundledTilesIfNeeded() {
        var tilesUrl = mapTilesDirectory
        if FileManager.default.fileExists(atPath: tilesUrl.path) {
            DDLogVerbose("Tiles already exist at path \(tilesUrl.path)")
            // Tiles already exist
            return
        }
        let bundle = Bundle.brc_tilesCache
        DDLogInfo("Cached tiles not found, copying from bundle... \(bundle.bundleURL) ==> \(tilesUrl)")
        do {
            let parentDir = tilesUrl.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.copyItem(atPath: bundle.bundlePath, toPath: tilesUrl.path)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try tilesUrl.setResourceValues(resourceValues)
        } catch let error {
            DDLogError("Error copying bundled tiles: \(error)")
        }
    }
    
    /** Downloads offline tiles from iBurn server */
    public static func downloadOfflineTiles() {
        // TODO: download our own offline tiles
        
    }

}
