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
    public let tableView = UITableView()
    
    // MARK: - Private Properties
    
    private let searchDisplayManager: SearchDisplayManager
    private let pageViewManager: PageViewManager
    private let tableViewAdapter: YapTableViewAdapter

    // MARK: - Init
    
    @objc public init(viewName: String,
                      searchViewName: String) {
        self.viewName = viewName
        self.searchViewName = searchViewName
        self.searchDisplayManager = SearchDisplayManager(viewName: searchViewName)
        let viewHandler = YapViewHandler(viewName: viewName)
        self.tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler,
                                                    tableView: tableView)
        self.pageViewManager = PageViewManager(objectProvider: viewHandler, tableView: tableView)
        super.init(nibName: nil, bundle: nil)
        self.tableViewAdapter.delegate = self
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        
        view.addSubview(tableView)
        tableView.edgeAnchors == view.edgeAnchors
    }
}

extension ObjectListViewController: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let vc = pageViewManager.pageViewController(for: object.object, at: indexPath, navBar: self.navigationController?.navigationBar)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}

private extension ObjectListViewController {
    func setupTableView() {
        tableView.registerCustomCellClasses()
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableHeaderView = searchDisplayManager.searchController.searchBar
    }
}
