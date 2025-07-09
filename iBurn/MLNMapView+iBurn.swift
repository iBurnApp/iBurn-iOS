//
//  MLNMapView+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import MapLibre

private final class BRCMapView: MLNMapView {
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.brc_setDefaults(moveToCenter: false)
    }
}

extension MLNMapView {
    @objc public static func brcMapView() -> MLNMapView {
        let mapView = BRCMapView()
        mapView.brc_setDefaults(moveToCenter: true)
        return mapView
    }
    
    /// Sets default iBurn behavior for mapView
    @objc public func brc_setDefaults(moveToCenter: Bool) {
        guard let mbtilesURL = Bundle.brc_mbtilesURL,
              let styleJSONURL = Bundle.brc_mapStyleURL(for: traitCollection.userInterfaceStyle) else {
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
        if moveToCenter {
            brc_moveToBlackRockCityCenter(animated: false)
        }
        
        #if DEBUG
        MLNLoggingConfiguration.shared.loggingLevel = .debug
        #endif
//        debugMask = [
//            MLNMapDebugMaskOptions.tileBoundariesMask,
//            MLNMapDebugMaskOptions.tileInfoMask,
//            MLNMapDebugMaskOptions.timestampsMask,
//            MLNMapDebugMaskOptions.collisionBoxesMask,
//        ]
    }
}
