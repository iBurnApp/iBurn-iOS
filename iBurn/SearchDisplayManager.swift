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
    public func registerCustomCellClasses() {
        let objectClasses = [BRCEventObject.self, BRCDataObject.self, BRCArtObject.self]
        objectClasses.forEach { objectClass in
            guard let cellClass = BRCDataObjectTableViewCell.cellClass(forDataObjectClass: objectClass) as? BRCDataObjectTableViewCell.Type else {
                DDLogError("Cell class not found for \(objectClass)")
                return
            }
            let cellIdentifier = cellClass.cellIdentifier()
            let nib = UINib.init(nibName: NSStringFromClass(cellClass), bundle: nil)
            self.register(nib, forCellReuseIdentifier: cellIdentifier)
        }
    }
}

public class SearchDisplayManager: NSObject {
    let viewName: String
    let searchController: UISearchController
    let mappings: YapDatabaseViewMappings
    let longLivedReadConnection: YapDatabaseConnection
    let readConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    let searchConnection: YapDatabaseConnection
    let searchQueue = YapDatabaseSearchQueue()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public init(viewName: String) {
        self.viewName = viewName
        
        // Setup connections
        longLivedReadConnection = BRCDatabaseManager.shared.database.newConnection()
        longLivedReadConnection.beginLongLivedReadTransaction()
        readConnection = BRCDatabaseManager.shared.readConnection
        writeConnection = BRCDatabaseManager.shared.readWriteConnection
        searchConnection = BRCDatabaseManager.shared.database.newConnection()
        
        // Setup mappings
        let groupFilter: YapDatabaseViewMappingGroupFilter = { (group, transaction) -> Bool in
            return true
        }
        let groupSort: YapDatabaseViewMappingGroupSort = { (group1, group2, transaction) -> ComparisonResult in
            return group1.compare(group2)
        }
        mappings = YapDatabaseViewMappings(groupFilterBlock: groupFilter, sortBlock: groupSort, view: viewName)
        
        // Setup UISearchController
        let src = UITableViewController(style: .plain)
        src.tableView.registerCustomCellClasses()
        src.tableView.estimatedRowHeight = 120
        src.tableView.rowHeight = UITableViewAutomaticDimension
        searchController = UISearchController(searchResultsController: src)
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        
        super.init()
        longLivedReadConnection.read { transaction in
            self.mappings.update(with: transaction)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModified(_:)), name: NSNotification.Name.YapDatabaseModified, object: BRCDatabaseManager.shared.database)
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        src.tableView.delegate = self
        src.tableView.dataSource = self
    }
    
    func yapDatabaseModified(_ notification: Notification) {
        let notifications = longLivedReadConnection.beginLongLivedReadTransaction()
        longLivedReadConnection.read { transaction in
            self.mappings.update(with: transaction)
        }
        guard notifications.count > 0 else {
            DDLogVerbose("Nothing to see here folks...")
            return
        }
        if let src = searchController.searchResultsController as? UITableViewController {
            src.tableView.reloadData()
        }
        // TODO: fix animations
    }
    
    func dataObjectAtIndexPath(_ indexPath: IndexPath) -> BRCDataObject? {
        var dataObject: BRCDataObject? = nil
        longLivedReadConnection.read { transaction in
            guard let viewTransaction = transaction.ext(self.viewName) as? YapDatabaseViewTransaction else {
                DDLogWarn("Search view not ready \(self.viewName)")
                return
            }
            dataObject = viewTransaction.object(at: indexPath, with: self.mappings) as? BRCDataObject
        }
        return dataObject
    }
}

extension SearchDisplayManager: UISearchControllerDelegate {
    
}

extension SearchDisplayManager: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataObject = dataObjectAtIndexPath(indexPath) else {
            DDLogWarn("No object found!")
            return
        }
        // TODO: push detail view
        DDLogInfo("Push detail view here for \(dataObject)")
    }
    
}

extension SearchDisplayManager: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(mappings.numberOfItems(inSection: UInt(section)))
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let dataObject = dataObjectAtIndexPath(indexPath) else {
            DDLogWarn("No object found!")
            return UITableViewCell()
        }
        guard let cellClass = BRCDataObjectTableViewCell.cellClass(forDataObjectClass: type(of: dataObject)) as? BRCDataObjectTableViewCell.Type else {
            DDLogWarn("No cell class!")
            return UITableViewCell()
        }
        let cellIdentifier = cellClass.cellIdentifier()
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? BRCDataObjectTableViewCell else {
            DDLogWarn("Couldnt dequeue cell of proper class!")
            return UITableViewCell()
        }
        let currentLocation = BRCAppDelegate.shared.locationManager.location
        cell.updateDistanceLabel(from: currentLocation, dataObject: dataObject)
        cell.favoriteButtonAction = { sender in
            dataObject.isFavorite = sender.favoriteButton.isSelected
            self.writeConnection.readWrite { transaction in
                
            }
        }
        return cell
    }
    
    
}

extension SearchDisplayManager: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        guard var searchString = searchController.searchBar.text, searchString.characters.count > 0 else {
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
