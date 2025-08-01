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