//
//  MapButtonHelper.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/6/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

protocol MapButtonHelper: NSObjectProtocol {
    func setupMapButton()
    func mapButtonPressed(_ sender: Any?)
}

extension MapButtonHelper where Self: UIViewController {
    func setupMapButton() {
        let map = UIBarButtonItem(title: "Map", style: .plain) { [weak self] (button) in
            self?.mapButtonPressed(button)
        }
        var buttons: [UIBarButtonItem] = navigationItem.rightBarButtonItems ?? []
        buttons.append(map)
        navigationItem.rightBarButtonItems = buttons
    }
}
