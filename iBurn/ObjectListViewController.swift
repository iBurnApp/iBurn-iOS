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
public class ObjectListViewController: UIViewController {
    
    // MARK: - Public Properties
    
    public let viewName: String
    public let searchViewName: String
    public var tableView = UITableView.iBurnTableView() {
        didSet {
            listCoordinator.tableViewAdapter.tableView = tableView
        }
    }
    
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
        setupSearchButton()
        self.listCoordinator.parent = self
        definesPresentationContext = true
        
        view.addSubview(tableView)
        tableView.edgeAnchors == view.edgeAnchors
        setupMapButton()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchWillAppear()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchDidAppear()
    }
}

extension ObjectListViewController: SearchCooordinator {
    var searchController: UISearchController {
        return listCoordinator.searchDisplayManager.searchController
    }
}

extension ObjectListViewController: MapButtonHelper {
    func mapButtonPressed(_ sender: Any) {
        //let mapVC = MapDetailViewController
    }
}
