//
//  MGLMapView+iBurn.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/14/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import Mapbox

extension MGLMapView {
    static func brcMapView() -> MGLMapView {
        let mapView = MGLMapView()
        mapView.brc_setDefaults()
        return mapView
    }
    
    /// Sets default iBurn behavior for mapView
    @objc public func brc_setDefaults() {
        MGLLoggingConfiguration.shared.loggingLevel = .verbose
        // FIXME: Clean this up big time
        let spritesURL = Bundle.main.url(forResource: "sprites", withExtension: "", subdirectory: "Map")!
        let glyphsURL = Bundle.main.url(forResource: "glyphs", withExtension: "", subdirectory: "Map")!

        let mbtilesURL = Bundle.main.url(forResource: "map", withExtension: "mbtiles", subdirectory: "Map")!
        let styleJSONURL = Bundle.main.url(forResource: "style", withExtension: "json", subdirectory: "Map")
        let styleJSONString = try! String(contentsOf: styleJSONURL!)
            .replacingOccurrences(of: "{{mbtiles_path}}", with: mbtilesURL.path)
            .replacingOccurrences(of: "{{sprites_path}}", with: spritesURL.path)
            .replacingOccurrences(of: "{{glyphs_path}}", with: glyphsURL.path)
        let outStyleURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("style.json")
        try! styleJSONString.write(to: outStyleURL, atomically: true, encoding: .utf8)
        print("wrote styleJSON to: \(outStyleURL.path)")
        self.styleURL = outStyleURL
        showsUserLocation = true
        minimumZoomLevel = 12
        backgroundColor = UIColor.brc_mapBackground
        translatesAutoresizingMaskIntoConstraints = false
        brc_moveToBlackRockCityCenter(animated: false)
    }
}
