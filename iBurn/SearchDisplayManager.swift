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
        let mapping = BRCDataObjectTableViewCell.cellIdentifiers
        mapping.forEach { cellIdentifier, cellClass in
            let nibName = NSStringFromClass(cellClass);
            let nib = UINib.init(nibName: nibName, bundle: nil)
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
    
    public var selectedObjectAction: (_ selected: DataObject) -> Void
    
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
    
    fileprivate func dataObjectAtIndexPath(_ indexPath: IndexPath) -> DataObject? {
        var dataObject: DataObject? = nil
        longLivedReadConnection.read { transaction in
            guard let object = BRCDataObject.object(at: indexPath, mappings: self.mappings, transaction: transaction, viewName: self.viewName) else { return }
            let metadata = object.metadata(with: transaction)
            dataObject = DataObject(object: object, metadata: metadata)
        }
        return dataObject
    }
    
    private func refreshData() {
        tableViewController?.tableView.reloadData()
    }
}

extension BRCDataObject {
    static func object(at indexPath: IndexPath,
                mappings: YapDatabaseViewMappings,
                transaction: YapDatabaseReadTransaction,
                viewName: String) -> BRCDataObject? {
        guard let viewTransaction = transaction.ext(viewName) as? YapDatabaseViewTransaction else {
            DDLogWarn("View not ready \(viewName)")
            return nil
        }
        let dataObject = viewTransaction.object(at: indexPath, with: mappings) as? BRCDataObject
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
            fatalError()
        }
        guard let cell = BRCDataObjectTableViewCell.cell(at: indexPath, tableView: tableView, dataObject: dataObject, writeConnection: writeConnection) else {
            fatalError()
        }
        return cell
    }
}

extension BRCDataObjectTableViewCell {
    class func cell(at indexPath: IndexPath,
                    tableView: UITableView,
                    dataObject: DataObject,
                    writeConnection: YapDatabaseConnection) -> BRCDataObjectTableViewCell? {
        let cellIdentifier = dataObject.object.tableCellIdentifier
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? BRCDataObjectTableViewCell else {
            DDLogWarn("Couldnt dequeue cell of proper class!")
            return nil
        }
        
        let currentLocation = BRCAppDelegate.shared.locationManager.location
        cell.setDataObject(dataObject.object, metadata: dataObject.metadata)
        cell.updateDistanceLabel(from: currentLocation, dataObject: dataObject.object)
        cell.favoriteButtonAction = { sender in
            writeConnection.readWrite { transaction in
                guard let metadata = dataObject.object.metadata(with: transaction).copy() as? BRCObjectMetadata else { return }
                metadata.isFavorite = sender.favoriteButton.isSelected
                dataObject.object.replace(metadata, transaction: transaction)
            }
        }
        if let artCell = cell as? BRCArtObjectTableViewCell, let art = dataObject.object as? BRCArtObject {
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
