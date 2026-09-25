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
}

extension SearchCooordinator where Self: UIViewController {
    func setupSearchButton() {
        navigationItem.searchController = searchController
    }
    
    /// Call me in viewWillAppear
    func searchWillAppear() {
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    /// Call me in viewDidAppear
    func searchDidAppear() {
        navigationItem.hidesSearchBarWhenScrolling = true
    }
}
