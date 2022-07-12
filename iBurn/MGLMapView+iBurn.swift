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
        let mbtilesURL = Bundle.main.url(forResource: "map", withExtension: "mbtiles", subdirectory: "Map")
        let styleJSONURL = Bundle.main.url(forResource: "style", withExtension: "json", subdirectory: "Map")
        let styleData = try! Data(contentsOf: styleJSONURL!)
        var styleJSON = try! JSONSerialization.jsonObject(with: styleData, options: .allowFragments) as! [String: Any]
        // maybe this? https://github.com/maplibre/maplibre-gl-native/issues/17#issuecomment-883869688
        styleJSON["sources"] = [
            "composite": [
                "type": "vector",
                "tiles": ["mbtiles://\(mbtilesURL!.path)"]
            ]
        ]
        let outData = try! JSONSerialization.data(withJSONObject: styleJSON, options: [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys])
        let outStyleURL = try! FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("style.json")
        try! outData.write(to: outStyleURL)
        print("wrote styleJSON to: \(outStyleURL.path)")
        self.styleURL = outStyleURL
        showsUserLocation = true
        minimumZoomLevel = 12
        backgroundColor = UIColor.brc_mapBackground
        translatesAutoresizingMaskIntoConstraints = false
        brc_moveToBlackRockCityCenter(animated: false)
    }
}
