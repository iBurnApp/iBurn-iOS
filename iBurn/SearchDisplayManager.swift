//
//  SearchDisplayManager.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/17/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import YapDatabase
import CocoaLumberjack

public final class SearchDisplayManager: NSObject {
    let viewName: String
    public let searchController: UISearchController
    let viewHandler: YapViewHandler
    public let tableViewAdapter: YapTableViewAdapter
    let writeConnection: YapDatabaseConnection
    let searchConnection: YapDatabaseConnection
    let searchQueue = YapDatabaseSearchQueue()
    
    private var tableViewController: UITableViewController? {
        return searchController.searchResultsController as? UITableViewController
    }
    
    public init(viewName: String) {
        self.viewName = viewName
        
        // Setup connections
        viewHandler = YapViewHandler(viewName: self.viewName)
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        searchConnection = BRCDatabaseManager.shared.database.newConnection()
        
        // Setup UISearchController
        let src = UITableViewController(style: .plain)
        searchController = UISearchController(searchResultsController: src)
        searchController.searchBar.barStyle = Appearance.currentBarStyle
        
        tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler, tableView: src.tableView)
        
        super.init()
        setupDefaults(for: src.tableView)
        setupDefaults(for: searchController)
    }

    private func setupDefaults(for tableView: UITableView) {
        tableView.setDataObjectDefaults()
    }
    
    private func setupDefaults(for searchController: UISearchController) {
        searchController.obscuresBackgroundDuringPresentation = true
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.delegate = self
    }
}

extension SearchDisplayManager: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        guard var searchString = searchController.searchBar.text, searchString.count > 0 else {
            return
        }
        searchString = "\(searchString)*"
        searchQueue.enqueueQuery(searchString)
        searchConnection.asyncReadWrite { transaction in
            guard let searchView = transaction.ext(self.viewName) as? YapDatabaseSearchResultsViewTransaction else {
                DDLogWarn("SearchResults not ready!")
                return
            }
            searchView.performSearch(with: self.searchQueue)
        }
    }
}

extension SearchDisplayManager: UISearchBarDelegate { }

extension SearchDisplayManager: UISearchControllerDelegate { }
