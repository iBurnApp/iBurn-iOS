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
import Combine

public final class SearchDisplayManager: NSObject {
    let viewName: String
    public let searchController: UISearchController
    let viewHandler: YapViewHandler
    public let tableViewAdapter: YapTableViewAdapter
    let writeConnection: YapDatabaseConnection
    let searchConnection: YapDatabaseConnection
    let searchQueue = YapDatabaseSearchQueue()
    private let searchText = PassthroughSubject<String, Never>()
    private var cancellables: Set<AnyCancellable> = .init()
    
    public init(viewName: String) {
        self.viewName = viewName
        
        // Setup connections
        viewHandler = YapViewHandler(viewName: self.viewName)
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        searchConnection = BRCDatabaseManager.shared.database.newConnection()
        
        // Setup UISearchController
        let src = UITableViewController()
        searchController = UISearchController(searchResultsController: src)
        searchController.searchBar.barStyle = Appearance.currentBarStyle
        
        tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler, tableView: src.tableView)
        
        super.init()
        setupDefaults(for: src.tableView)
        setupDefaults(for: searchController)
        searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in
                self?.updateSearchResults(searchText: value)
        }).store(in: &cancellables)
    }

    private func setupDefaults(for tableView: UITableView) {
        tableView.setDataObjectDefaults()
    }
    
    private func setupDefaults(for searchController: UISearchController) {
        searchController.obscuresBackgroundDuringPresentation = true
        // works around a bug introduced in iOS 16(?) https://github.com/iBurnApp/iBurn-iOS/issues/139
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.delegate = self
    }
    
    private func updateSearchResults(searchText: String) {
        guard searchText.count > 0 else {
            return
        }
        let searchString = "\(searchText)*"
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

extension SearchDisplayManager: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        searchText.send(searchController.searchBar.text ?? "")
    }
}

extension SearchDisplayManager: UISearchBarDelegate { }

extension SearchDisplayManager: UISearchControllerDelegate { }
