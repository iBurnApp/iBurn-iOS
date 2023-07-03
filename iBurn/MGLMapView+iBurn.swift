//
//  MGLMapView+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import Mapbox

private final class BRCMapView: MGLMapView {
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.brc_setDefaults()
    }
}

extension MGLMapView {
    @objc public static func brcMapView() -> MGLMapView {
        let mapView = BRCMapView()
        mapView.brc_setDefaults()
        return mapView
    }
    
    /// Sets default iBurn behavior for mapView
    @objc public func brc_setDefaults() {
        let styleJSON = traitCollection.userInterfaceStyle == .light ? "iburn-2022.json" : "iburn-2022-dark.json"
        
        guard let mbtilesURL = Bundle.main.url(forResource: "map", withExtension: "mbtiles", subdirectory: "Map"),
              let styleJSONURL = Bundle.main.url(forResource: "styles", withExtension: "", subdirectory: "Map")?.appendingPathComponent(styleJSON) else {
            print("Couldn't find mbtiles!")
            return
        }
        do {
            let styleJSONString = try String(contentsOf: styleJSONURL)
                .replacingOccurrences(of: "{{mbtiles_path}}", with: mbtilesURL.path)
            let outStyleURL = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("style.json")
            try styleJSONString.write(to: outStyleURL, atomically: true, encoding: .utf8)
            self.styleURL = outStyleURL
        } catch {
            print("Error loading map tiles! \(error)")
        }
        
        showsUserLocation = true
        minimumZoomLevel = 12
        backgroundColor = UIColor.brc_mapBackgroundColor
        translatesAutoresizingMaskIntoConstraints = false
        brc_moveToBlackRockCityCenter(animated: false)
        
        #if DEBUG
        MGLLoggingConfiguration.shared.loggingLevel = .verbose
        #endif
//        debugMask = [
//            MGLMapDebugMaskOptions.tileBoundariesMask,
//            MGLMapDebugMaskOptions.tileInfoMask,
//            MGLMapDebugMaskOptions.timestampsMask,
//            MGLMapDebugMaskOptions.collisionBoxesMask,
//        ]
    }
}
