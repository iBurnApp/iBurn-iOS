//
//  ObjectListViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit
import Anchorage

@objc
public final class ObjectListViewController: UIViewController {
    
    // MARK: - Public Properties
    
    public let viewName: String
    public let searchViewName: String
    public let tableView = UITableView.iBurnTableView()
    
    // MARK: - Private Properties
    
    let listCoordinator: ListCoordinator

    // MARK: - Init
    
    @objc public init(viewName: String,
                      searchViewName: String) {
        self.viewName = viewName
        self.searchViewName = searchViewName
        self.listCoordinator = ListCoordinator(viewName: viewName,
                                               searchViewName: searchViewName,
                                               tableView: tableView)
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = listCoordinator.searchDisplayManager.searchController.searchBar
        self.listCoordinator.parent = self
        
        view.addSubview(tableView)
        tableView.edgeAnchors == view.edgeAnchors
    }
}
