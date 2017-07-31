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
    
    /** Downloads offline tiles directly from official Mapbox server */
    public static func downloadMapboxOfflineTiles() {
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
    
    /** Downloads offline tiles from iBurn server */
    public static func downloadOfflineTiles() {
        // TODO: download our own offline tiles
        
    }

}
