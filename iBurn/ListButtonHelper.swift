//
//  ListButtonHelper.swift
//  iBurn
//
//  Created by Claude on 8/3/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import MapLibre

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
    
    func listButtonPressed(_ sender: Any?) {
        let visibleAnnotations = mapView.annotations ?? []
        let visibleBounds = mapView.visibleCoordinateBounds
        let listVC = MapPinListViewController(visibleAnnotations: visibleAnnotations, visibleBounds: visibleBounds)
        navigationController?.pushViewController(listVC, animated: true)
    }
}