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

extension YapDatabaseViewMappings {
    class func basicMappings(viewName: String) -> YapDatabaseViewMappings {
        let groupFilter: YapDatabaseViewMappingGroupFilter = { (group, transaction) -> Bool in
            return true
        }
        let groupSort: YapDatabaseViewMappingGroupSort = { (group1, group2, transaction) -> ComparisonResult in
            return group1.compare(group2)
        }
        let mappings = YapDatabaseViewMappings(groupFilterBlock: groupFilter, sortBlock: groupSort, view: viewName)
        return mappings
    }
}

public class SearchDisplayManager: NSObject {
    let viewName: String
    public let searchController: UISearchController
    let mappings: YapDatabaseViewMappings
    let longLivedReadConnection: YapDatabaseConnection
    let readConnection: YapDatabaseConnection
    let writeConnection: YapDatabaseConnection
    let searchConnection: YapDatabaseConnection
    let searchQueue = YapDatabaseSearchQueue()
    
    private var tableViewController: UITableViewController? {
        return searchController.searchResultsController as? UITableViewController
    }
    
    public var selectedObjectAction: (_ selected: BRCDataObject) -> Void
    
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
        mappings = YapDatabaseViewMappings.basicMappings(viewName: viewName)
        
        // Setup UISearchController
        let src = UITableViewController(style: .plain)
        searchController = UISearchController(searchResultsController: src)
        selectedObjectAction = {_ in }
        
        super.init()
        setupDefaults(for: src.tableView)
        setupDefaults(for: searchController)
        longLivedReadConnection.read { transaction in
            self.mappings.update(with: transaction)
        }
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(yapDatabaseModified(_:)), name: NSNotification.Name.YapDatabaseModified, object: BRCDatabaseManager.shared.database)
        NotificationCenter.default.addObserver(self, selector: #selector(audioPlayerChangeNotification(_:)), name: NSNotification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: BRCAudioPlayer.sharedInstance)
    }
    
    private func setupDefaults(for tableView: UITableView) {
        tableView.registerCustomCellClasses()
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    private func setupDefaults(for searchController: UISearchController) {
        searchController.dimsBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.delegate = self
        searchController.searchResultsUpdater = self
        searchController.delegate = self
    }
    
    func audioPlayerChangeNotification(_ notification: Notification) {
        refreshData()
    }
    
    func yapDatabaseModified(_ notification: Notification) {
        let notifications = longLivedReadConnection.beginLongLivedReadTransaction()
        longLivedReadConnection.read { transaction in
            self.mappings.update(with: transaction)
        }
        guard notifications.count > 0 else {
            return
        }
        refreshData()
        // TODO: fix animations
    }
    
    fileprivate func dataObjectAtIndexPath(_ indexPath: IndexPath) -> BRCDataObject? {
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
    
    private func refreshData() {
        tableViewController?.tableView.reloadData()
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
        selectedObjectAction(dataObject)
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BRCDataObjectTableViewCell else {
            DDLogWarn("Couldnt dequeue cell of proper class!")
            return UITableViewCell()
        }
        let currentLocation = BRCAppDelegate.shared.locationManager.location
        cell.setDataObject(dataObject)
        cell.updateDistanceLabel(from: currentLocation, dataObject: dataObject)
        cell.favoriteButtonAction = { sender in
            self.writeConnection.readWrite { transaction in
                guard let dataObject = dataObject.refetch(with: transaction) else { return }
                dataObject.isFavorite = sender.favoriteButton.isSelected
                dataObject.save(with: transaction)
            }
        }
        if let artCell = cell as? BRCArtObjectTableViewCell, let art = dataObject as? BRCArtObject {
            artCell.configurePlayPauseButton(art)
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
