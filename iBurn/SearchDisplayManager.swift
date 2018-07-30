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

public extension UITableView {
    /** Registers custom cell classes for BRC data objects */
    @objc public func registerCustomCellClasses() {
        let mapping = BRCDataObjectTableViewCell.cellIdentifiers
        mapping.forEach { cellIdentifier, cellClass in
            let nibName = NSStringFromClass(cellClass);
            let nib = UINib.init(nibName: nibName, bundle: nil)
            self.register(nib, forCellReuseIdentifier: cellIdentifier)
        }
    }
}

public final class SearchDisplayManager: NSObject {
    let viewName: String
    public let searchController: UISearchController
    let viewHandler: YapViewHandler
    public let tableViewAdapter: YapTableViewAdapter
    let readConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    let searchConnection: YapDatabaseConnection
    let searchQueue = YapDatabaseSearchQueue()
    var observer: NSObjectProtocol?
    
    private var tableViewController: UITableViewController? {
        return searchController.searchResultsController as? UITableViewController
    }
    
    public init(viewName: String) {
        self.viewName = viewName
        
        // Setup connections
        viewHandler = YapViewHandler(viewName: self.viewName)
        readConnection = BRCDatabaseManager.shared.readConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        searchConnection = BRCDatabaseManager.shared.database.newConnection()
        
        // Setup UISearchController
        let src = UITableViewController(style: .plain)
        searchController = UISearchController(searchResultsController: src)
        
        tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler, tableView: src.tableView)
        
        super.init()
        setupDefaults(for: src.tableView)
        setupDefaults(for: searchController)
        setupNotifications()
    }
    
    private func setupNotifications() {
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: BRCAudioPlayer.sharedInstance, queue: OperationQueue.main, using: { [weak self] (notification) in
            self?.audioPlayerChangeNotification(notification)
        })
    }
    
    private func setupDefaults(for tableView: UITableView) {
        tableView.registerCustomCellClasses()
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    private func setupDefaults(for searchController: UISearchController) {
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.delegate = self
    }
    
    @objc func audioPlayerChangeNotification(_ notification: Notification) {
        refreshData()
    }
    
    private func refreshData() {
        tableViewController?.tableView.reloadData()
    }
}

extension SearchDisplayManager: UISearchControllerDelegate {
    
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

extension SearchDisplayManager: UISearchBarDelegate {
    
}

