//
//  Bundle+iBurn.swift
//  iBurn
//
//  Created by Claude on 7/7/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import UIKit
import iBurn2025APIData
import iBurn2025Map  
import iBurn2025MediaFiles

extension Bundle {
    // MARK: - Data Bundle Access
    
    /// Return current year's API Data bundle
    static var brc_dataBundle: Bundle {
        return iBurn2025APIData.bundle
    }
    
    /// Return current year's Map bundle  
    static var brc_mapBundle: Bundle {
        return iBurn2025Map.bundle
    }
    
    /// Return current year's MediaFiles bundle
    static var brc_mediaBundle: Bundle {
        return iBurn2025MediaFiles.bundle
    }
    
    
    // MARK: - Convenience Resource Access
    
    /// Get map.mbtiles URL
    static var brc_mbtilesURL: URL? {
        return iBurn2025Map.MapResource.mbtiles.url
    }
    
    /// Get map style URL for current interface style
    static func brc_mapStyleURL(for userInterfaceStyle: UIUserInterfaceStyle) -> URL? {
        return userInterfaceStyle == .light ? 
               iBurn2025Map.MapResource.lightStyle.url : 
               iBurn2025Map.MapResource.darkStyle.url
    }
    
    /// Get glyphs directory URL
    static var brc_glyphsDirectoryURL: URL? {
        return iBurn2025Map.MapResource.glyphsDirectory
    }
    
    // MARK: - Map Cache Management
    
    /// Get the map cache directory for the current year
    static var brc_mapCacheDirectory: URL {
        let year = iBurn2025Map.year
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                     in: .userDomainMask).first!
        return appSupportURL
            .appendingPathComponent("iBurn")
            .appendingPathComponent("\(year)")
            .appendingPathComponent("Map")
    }
    
    /// Get cached MBTiles URL, copying from bundle if needed
    static var brc_cachedMbtilesURL: URL? {
        let cacheDirectory = brc_mapCacheDirectory
        var cachedMbtilesURL = cacheDirectory.appendingPathComponent("map.mbtiles")
        
        // Create directory structure if needed
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
        } catch {
            print("Error creating map cache directory: \(error)")
            // Fall back to bundle URL
            return brc_mbtilesURL
        }
        
        // Check if cached file exists
        if !FileManager.default.fileExists(atPath: cachedMbtilesURL.path) {
            // Copy from bundle
            guard let bundleMbtilesURL = brc_mbtilesURL else {
                print("Could not find mbtiles in bundle")
                return nil
            }
            
            do {
                try FileManager.default.copyItem(at: bundleMbtilesURL, to: cachedMbtilesURL)
                
                // Exclude from backup
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try cachedMbtilesURL.setResourceValues(resourceValues)
                
                print("Successfully copied mbtiles to cache: \(cachedMbtilesURL.path)")
            } catch {
                print("Error copying mbtiles to cache: \(error)")
                // Fall back to bundle URL
                return bundleMbtilesURL
            }
        }
        
        return cachedMbtilesURL
    }
    
    /// Get cached style JSON URL for the given interface style
    static func brc_cachedStyleURL(for userInterfaceStyle: UIUserInterfaceStyle) -> URL {
        let cacheDirectory = brc_mapCacheDirectory
        let styleName = userInterfaceStyle == .light ? "style-light.json" : "style-dark.json"
        return cacheDirectory.appendingPathComponent(styleName)
    }
    
    /// Load media file data
    static func brc_loadMediaData(fileId: String) -> Data? {
        return iBurn2025MediaFiles.loadImageData(fileId: fileId)
    }
    
    /// Get media file URL
    static func brc_mediaFileURL(fileId: String, extension ext: String = "jpg") -> URL? {
        return iBurn2025MediaFiles.url(forResource: fileId, withExtension: ext)
    }
}

// MARK: - Objective-C Bridging Methods

extension Bundle {
    /// Objective-C bridge for brc_dataBundle - returns the data bundle
    @objc(brc_dataBundle) 
    public static func _brc_dataBundle() -> Bundle {
        return Bundle.brc_dataBundle
    }
    
    /// Objective-C bridge for brc_mapBundle - returns the map bundle  
    @objc(brc_mapBundle)
    public static func _brc_mapBundle() -> Bundle {
        return Bundle.brc_mapBundle
    }
    
    /// Objective-C bridge for brc_mediaBundle - returns the media bundle
    @objc(brc_mediaBundle)
    public static func _brc_mediaBundle() -> Bundle {
        return Bundle.brc_mediaBundle
    }
    
    /// Legacy bridge for brc_tilesCache - now maps to map bundle
    @objc(brc_tilesCache)
    public static func _brc_tilesCache() -> Bundle {
        return Bundle.brc_mapBundle
    }
}