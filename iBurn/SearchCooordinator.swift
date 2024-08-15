//
//  SearchCooordinator.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

protocol SearchCooordinator: NSObjectProtocol {
    var searchController: UISearchController { get }
    func setupSearchButton()
    func searchButtonPressed(_ sender: Any?)
}

extension SearchCooordinator where Self: UIViewController {
    func setupSearchButton() {
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            let search = UIBarButtonItem(barButtonSystemItem: .search) { [weak self](button) in
                self?.searchButtonPressed(button)
            }
            var buttons: [UIBarButtonItem] = navigationItem.rightBarButtonItems ?? []
            buttons.append(search)
            navigationItem.rightBarButtonItems = buttons
        }
    }
    
    func searchButtonPressed(_ sender: Any) {
        present(searchController, animated: true, completion: nil)
    }
    
    /// Call me in viewWillAppear
    func searchWillAppear() {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    /// Call me in viewDidAppear
    func searchDidAppear() {
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = true
        }
    }
}
