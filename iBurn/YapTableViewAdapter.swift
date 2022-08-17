//
//  YapTableViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol YapTableViewAdapterDelegate: NSObjectProtocol {
    func didSelectObject(_ adapter: YapTableViewAdapter,
                         object: DataObject,
                         in tableView: UITableView,
                         at indexPath: IndexPath)
}

@objc public final class YapTableViewAdapter: NSObject {
    var tableView: UITableView {
        didSet {
            tableView.delegate = self
            tableView.dataSource = dataSource
        }
    }
    let viewHandler: YapViewHandler
    let writeConnection: YapDatabaseConnection
    /// For converting sectionIndexTitles
    public var groupTransformer: (String) -> String = { $0 } {
        didSet {
            dataSource.groupTransformer = groupTransformer
        }
    }
    public weak var delegate: YapTableViewAdapterDelegate?
    var audioObserver: NSObjectProtocol?
    /// on the right side quick scroll bar
    var showSectionIndexTitles = true {
        didSet {
            dataSource.showSectionIndexTitles = showSectionIndexTitles
        }
    }
    /// header sections
    var showSectionHeaderTitles = false {
        didSet {
            dataSource.showSectionHeaderTitles = showSectionHeaderTitles
        }
    }
    private lazy var dataSource = DiffableDataSource(viewHandler: viewHandler, tableView: tableView) {
        let tableView = $0
        let indexPath = $1
        let _ = $2
        guard let object = self.viewHandler.dataObjectAtIndexPath(indexPath) else {
            return nil
        }
       return BRCDataObjectTableViewCell.cell(at: indexPath, tableView: tableView, dataObject: object, writeConnection: self.writeConnection)
    }

    /// This will take control of the UITableViewDataSource
    /// and YapViewHandlerDelegate
    @objc public init(viewHandler: YapViewHandler,
                      tableView: UITableView,
                      writeConnection: YapDatabaseConnection = BRCDatabaseManager.shared.readWriteConnection) {
        self.tableView = tableView
        self.viewHandler = viewHandler
        self.writeConnection = writeConnection
        super.init()
        tableView.delegate = self
        tableView.dataSource = dataSource
        viewHandler.delegate = self
        setupNotifications()
    }
}

private extension YapTableViewAdapter {
    func setupNotifications() {
        audioObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: BRCAudioPlayer.BRCAudioPlayerChangeNotification), object: BRCAudioPlayer.sharedInstance, queue: OperationQueue.main, using: { [weak self] (notification) in
            self?.audioPlayerChangeNotification(notification)
        })
    }
    
    @objc func audioPlayerChangeNotification(_ notification: Notification) {
        tableView.reloadData()
    }
}

extension YapTableViewAdapter: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let object = viewHandler.dataObjectAtIndexPath(indexPath) else { return }
        delegate?.didSelectObject(self, object: object, in: tableView, at: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
//
//extension YapTableViewAdapter: UITableViewDataSource {
//
//    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        guard showSectionHeaderTitles else { return nil }
//        return groupTransformer(viewHandler.allGroups[section])
//    }
//
//    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
//        guard showSectionIndexTitles else {
//            return nil
//        }
//        let groups = viewHandler.allGroups.map {
//            groupTransformer($0)
//        }
////        groups.insert(UITableViewIndexSearch, at: 0)
//        return groups
//    }
//
////    public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
////        if index > 0 {
////            return viewHandler.sectionForGroup(title)
////        } else {
////            tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
////            return NSNotFound
////        }
////    }
//
//    public func numberOfSections(in tableView: UITableView) -> Int {
//        return viewHandler.numberOfSections
//    }
//
//    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        return viewHandler.numberOfItemsInSection(section)
//    }
//
//    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
//        guard let object = viewHandler.dataObjectAtIndexPath(indexPath) else {
//            return UITableViewCell()
//        }
//        let cell = BRCDataObjectTableViewCell.cell(at: indexPath, tableView: tableView, dataObject: object, writeConnection: writeConnection)
//        return cell
//    }
//}

extension YapTableViewAdapter: YapViewHandlerDelegate {
    public func didSetupMappings(_ handler: YapViewHandler) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, IndexPath>()

        let sections = Array(0..<handler.numberOfSections)
        snapshot.appendSections(sections)
        
        for section in sections {
            let numberOfItems = handler.numberOfItemsInSection(section)
            let rows = (0..<numberOfItems).map {
                IndexPath(row: $0, section: section)
            }
            snapshot.appendItems(rows, toSection: section)
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    public func didReceiveChanges(_ handler: YapViewHandler, sectionChanges: [YapDatabaseViewSectionChange], rowChanges: [YapDatabaseViewRowChange]) {
        var snapshot = self.dataSource.snapshot()
        
        let updates = {
            sectionChanges.forEach {
                switch $0.type {
                case .insert:
                    snapshot.appendSections([Int($0.index)])
                case .delete:
                    snapshot.deleteSections([Int($0.index)])
                case .move, .update:
                    // moves and updates are not supported
                    break
                @unknown default:
                    break
                }
            }
            rowChanges.forEach {
                switch $0.type {
                case .insert:
                    if let newIndexPath = $0.newIndexPath {
                        let identifiers = snapshot.itemIdentifiers(inSection: newIndexPath.section)
                        if let lastItem = identifiers.last {
                            snapshot.insertItems([newIndexPath], afterItem: lastItem)
                        }
                    }
                case .delete:
                    if let indexPath = $0.indexPath {
                        snapshot.deleteItems([indexPath])
                    }
                case .move:
                    if let _ = $0.indexPath,
                        let newIndexPath = $0.newIndexPath {
                        let identifiers = snapshot.itemIdentifiers(inSection: newIndexPath.section)
                        if let lastItem = identifiers.last {
                            snapshot.moveItem(newIndexPath, afterItem: lastItem)
                        }
                    }
                case .update:
                    if let indexPath = $0.indexPath {
                        snapshot.reloadItems([indexPath])
                    }
                @unknown default:
                    break
                }
            }
        }
        updates()
        
        // Getting lots of crashes for section animation errors, so let's disable those
        guard rowChanges.count < 20, sectionChanges.count == 0 else {
            dataSource.apply(snapshot, animatingDifferences: false)
            return
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

private final class DiffableDataSource: UITableViewDiffableDataSource<Int, IndexPath> {
    /// header sections
    var showSectionHeaderTitles = false
    /// on the right side quick scroll bar
    var showSectionIndexTitles = true
    /// For converting sectionIndexTitles
    public var groupTransformer: (String) -> String = { $0 }
    let viewHandler: YapViewHandler
    
    init(
        viewHandler: YapViewHandler,
        tableView: UITableView,
        cellProvider: @escaping CellProvider
    ) {
        self.viewHandler = viewHandler
        super.init(tableView: tableView, cellProvider: cellProvider)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard showSectionHeaderTitles else { return nil }
        return groupTransformer(viewHandler.allGroups[section])
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard showSectionIndexTitles else {
            return nil
        }
        let groups = viewHandler.allGroups.map {
            groupTransformer($0)
        }
//        groups.insert(UITableViewIndexSearch, at: 0)
        return groups
    }
}
