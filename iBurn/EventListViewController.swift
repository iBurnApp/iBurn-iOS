//
//  EventListViewController.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit
import Anchorage

@objc
public final class EventListViewController: UIViewController {
    
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
        self.listCoordinator.navigationController = self.navigationController
        
        view.addSubview(tableView)
        tableView.edgeAnchors == view.edgeAnchors
    }
}


private extension ObjectListViewController {
    
    // MARK: UI Actions
    
    @objc func filterButtonPressed(_ sender: Any) {
        let filterVC = BRCEventsFilterTableViewController(delegate: self)
        let nav = UINavigationController(rootViewController: filterVC)
        present(nav, animated: true, completion: nil)
    }
}

extension ObjectListViewController: BRCEventsFilterTableViewControllerDelegate {
    public func didSetNewFilterSettings(_ viewController: BRCEventsFilterTableViewController) {
        
    }
    
    public func didSetNewSortSettings(_ viewController: BRCEventsFilterTableViewController) {
        
    }
    
    
}
