//
//  ListButtonHelper.swift
//  iBurn
//
//  Created by Claude on 8/3/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre

@MainActor
protocol ListButtonHelper: NSObjectProtocol {
    var mapView: MLNMapView { get }
    func setupListButton()
    func listButtonPressed(_ sender: Any?)
}

extension ListButtonHelper where Self: UIViewController {
    func setupListButton() {
        let listImage = UIImage(systemName: "list.bullet")
        let list = UIBarButtonItem(image: listImage, style: .plain) { [weak self] (button) in
            self?.listButtonPressed(button)
        }
        var buttons: [UIBarButtonItem] = navigationItem.rightBarButtonItems ?? []
        buttons.append(list)
        navigationItem.rightBarButtonItems = buttons
    }

    /// Shows what is currently drawn inside the map's visible bounds.
    ///
    /// Every map in the app — the main map (`FilteredMapDataSource`) and the SwiftUI list
    /// screens' map push (`StaticAnnotationDataSource` of `PlayaObjectAnnotation`s) — gets
    /// the PlayaDB-native `VisiblePinsHostingController`, which also lists
    /// `BRCUserMapPoint` user pins.
    func listButtonPressed(_ sender: Any?) {
        let visibleAnnotations = mapView.annotations ?? []
        let visibleBounds = mapView.visibleCoordinateBounds
        let inBounds = visibleAnnotations.filter { visibleBounds.brc_contains($0.coordinate) }

        let dependencies = BRCAppDelegate.shared.dependencies
        let listVC = VisiblePinsHostingController(annotations: inBounds, dependencies: dependencies) { [weak self] pin in
            guard let self else { return }
            self.navigationController?.popToViewController(self, animated: true)
            // Center without animation so the pin is inside the viewport by the time it is
            // selected, otherwise MapLibre drops the callout.
            self.mapView.setCenter(pin.coordinate, animated: false)
            self.mapView.selectAnnotation(pin, animated: true, completionHandler: nil)
        }
        navigationController?.pushViewController(listVC, animated: true)
    }
}

// MARK: - Bounds

extension MLNCoordinateBounds {
    func brc_contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= sw.latitude &&
        coordinate.latitude <= ne.latitude &&
        coordinate.longitude >= sw.longitude &&
        coordinate.longitude <= ne.longitude
    }
}
