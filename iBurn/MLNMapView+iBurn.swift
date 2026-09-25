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
    /// The appearance the current style was built for; the style JSON differs per light/dark.
    var styledAppearance: UIUserInterfaceStyle?

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        reloadStyleIfNeeded()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        // Catches an appearance change that happened while the map was off screen.
        reloadStyleIfNeeded()
    }

    /// Catches an appearance change that arrived while the app was in the background.
    /// `didBecomeActive` rather than `willEnterForeground`: the application state still
    /// reads `.background` during the latter, which `reloadStyleIfNeeded` skips.
    @objc func appDidBecomeActive() {
        reloadStyleIfNeeded()
    }

    /// Only light/dark picks a different style, so other trait changes are ignored.
    ///
    /// Nothing is reloaded off screen or in the background either. The system flips the
    /// appearance to take light and dark snapshots of a backgrounded app, and MapLibre
    /// tears its underlying map down on termination while the view is still in a window —
    /// setting a style after that throws `MLNUnderlyingMapUnavailableException`.
    /// `didMoveToWindow` and `appDidBecomeActive` pick up whatever was skipped.
    private func reloadStyleIfNeeded() {
        let appearance = traitCollection.userInterfaceStyle
        guard window != nil,
              UIApplication.shared.applicationState != .background,
              appearance != styledAppearance
        else { return }
        styledAppearance = appearance
        brc_setDefaults(moveToCenter: false)
    }
}

extension MLNMapView {
    @objc public static func brcMapView() -> MLNMapView {
        let mapView = BRCMapView()
        mapView.brc_setDefaults(moveToCenter: true)
        mapView.styledAppearance = mapView.traitCollection.userInterfaceStyle
        NotificationCenter.default.addObserver(
            mapView,
            selector: #selector(BRCMapView.appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        return mapView
    }
    
    /// Sets default iBurn behavior for mapView
    @objc public func brc_setDefaults(moveToCenter: Bool) {
        // Use cached MBTiles to avoid SQLite crashes
        guard let mbtilesURL = Bundle.brc_cachedMbtilesURL,
              let styleJSONURL = Bundle.brc_mapStyleURL(for: traitCollection.userInterfaceStyle) else {
            print("Couldn't find mbtiles!")
            return
        }
        do {
            // Load style JSON template and replace mbtiles path
            let styleJSONString = try String(contentsOf: styleJSONURL)
                .replacingOccurrences(of: "{{mbtiles_path}}", with: mbtilesURL.path)
            
            // Save style JSON to cache directory alongside mbtiles
            let outStyleURL = Bundle.brc_cachedStyleURL(for: traitCollection.userInterfaceStyle)
            try styleJSONString.write(to: outStyleURL, atomically: true, encoding: .utf8)
            
            // Clean up old style.json from Application Support root if it exists
            let oldStyleURL = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                .appendingPathComponent("style.json")
            if FileManager.default.fileExists(atPath: oldStyleURL.path) {
                try? FileManager.default.removeItem(at: oldStyleURL)
            }
            
            self.styleURL = outStyleURL
        } catch {
            print("Error loading map tiles! \(error)")
        }
        
        // MapLibre parks its attribution ⓘ in the bottom-trailing corner of every map,
        // which under the iOS 26 tab bar is exactly where the floating action button sits.
        // The app credits its map data elsewhere (Credits screen, and the acknowledgements
        // in Settings), so the on-map ⓘ is redundant rather than load-bearing, and the
        // corner goes to the button.
        attributionButton.isHidden = true

        showsUserLocation = true
        // Which way you're facing is half of "where am I" on a flat, landmark-poor playa,
        // and the puck only grew the arrow in follow-with-heading before — a mode you had
        // to opt into and that also rotates the map. This shows the arrow in every tracking
        // mode instead; MapLibre documents it as not rotating the camera, and it's a no-op
        // in the follow-with-heading/course modes that draw their own.
        showsUserHeadingIndicator = true
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
