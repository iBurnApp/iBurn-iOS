//
//  ListButtonHelper.swift
//  iBurn
//
//  Created by Claude on 8/3/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import UIKit

protocol ListButtonHelper: NSObjectProtocol {
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
}