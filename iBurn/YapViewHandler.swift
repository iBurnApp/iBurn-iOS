//
//  YapViewHandler.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/28/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase
import CocoaLumberjack

@objc public protocol YapViewHandlerDelegate: NSObjectProtocol {
    /** Recommeded to do a reloadData here */
    func didSetupMappings(_ handler: YapViewHandler)
    func didReceiveChanges(_ handler: YapViewHandler,
                           sectionChanges: [YapDatabaseViewSectionChange],
                           rowChanges: [YapDatabaseViewRowChange])
}

/// The public API should be used on the main thread only
@objc public final class YapViewHandler: NSObject {
    // MARK: Public Properties

    @objc public weak var delegate: YapViewHandlerDelegate?
    @objc public let viewName: String
    
    public enum MappingsGroups {
        case all
        case names([String])
        case filter(YapDatabaseViewMappingGroupFilter)
        case filterSort(YapDatabaseViewMappingGroupFilter, YapDatabaseViewMappingGroupSort)    }
    
    /// Setting this will reset the internal mappings
    public var groups: MappingsGroups {
        didSet {
            self.mappings = nil
            let _ = setupMappings()
        }
    }
    
    // MARK: Private Properties
    private let connection: YapDatabaseConnection
    private var mappings: YapDatabaseViewMappings? {
        didSet {
            self.delegate?.didSetupMappings(self)
        }
    }

    
    // MARK: Init
    
    /// Init must be called on the main thread
    public init(viewName: String,
                manager: LongLivedConnectionManager = BRCDatabaseManager.shared.longLived,
                delegate: YapViewHandlerDelegate? = nil,
                groups: MappingsGroups = MappingsGroups.all) {
        self.connection = manager.connection
        self.delegate = delegate
        self.viewName = viewName
        self.groups = groups
        super.init()
        manager.registerHandler(self)
        let _ = setupMappings()
    }
    
    /// Init must be called on the main thread
    @objc public convenience init(viewName: String,
                                  manager: LongLivedConnectionManager,
                                  delegate: YapViewHandlerDelegate,
                                  groupNames: [String]) {
        let groups = MappingsGroups.names(groupNames)
        self.init(viewName: viewName,
                  manager: manager,
                  delegate: delegate,
                  groups: groups)
    }
    
    /// Init must be called on the main thread
    @objc public convenience init(manager: LongLivedConnectionManager,
                                  delegate: YapViewHandlerDelegate,
                                  viewName: String,
                                  groupFilter: @escaping YapDatabaseViewMappingGroupFilter,
                                  groupSort: @escaping YapDatabaseViewMappingGroupSort) {
        let groups = MappingsGroups.filterSort(groupFilter, groupSort)
        self.init(viewName: viewName,
                  manager: manager,
                  delegate: delegate,
                  groups: groups)
    }
    
    // MARK: Public API
    
    // MARK: Groups
    
    @objc public func setGroupNames(_ groupNames: [String]) {
        self.groups = MappingsGroups.names(groupNames)
    }
    
    @objc public func setGroupFilter(_ groupFilter: @escaping YapDatabaseViewMappingGroupFilter,
                                        groupSort: @escaping YapDatabaseViewMappingGroupSort) {
        self.groups = MappingsGroups.filterSort(groupFilter, groupSort)
    }
    
    @objc public var allGroups: [String] {
        return self.mappings?.allGroups ?? []
    }
    
    @objc public func sectionForGroup(_ group: String) -> Int {
        guard let section = self.mappings?.section(forGroup: group) else {
            return NSNotFound
        }
        return Int(section)
    }
    
    // MARK: Table Mappings
    
    @objc public func numberOfItemsInSection(_ section: Int) -> Int {
        let count = self.mappings?.numberOfItems(inSection: UInt(section)) ?? 0
        return Int(count)
    }
    
    @objc public var numberOfSections: Int {
        let count = self.mappings?.numberOfSections() ?? 0
        return Int(count)
    }
    
    @objc public func objectAtIndexPath(_ indexPath: IndexPath) -> AnyObject? {
        return objectAtIndexPath(indexPath, readBlock: nil)
    }
    
    @objc public func objectAtIndexPath(_ indexPath: IndexPath,
                                        readBlock: ((AnyObject, YapDatabaseReadTransaction) -> Void)? = nil) -> AnyObject? {
        return object(at: indexPath, readBlock: readBlock)
    }
    
    public func object<T>(at indexPath: IndexPath,
                          readBlock: ((T, YapDatabaseReadTransaction) -> Void)? = nil) -> T? {
        let row = UInt(indexPath.row)
        let section = UInt(indexPath.section)
        guard let mappings = self.mappings,
            row < mappings.numberOfItems(inSection: section) else {
            return nil
        }
        let object: T? = read {
            guard let viewTransaction = $0.ext(self.viewName) as? YapDatabaseViewTransaction,
                let object = viewTransaction.object(atRow: row,
                                                    inSection: section,
                                                    with: mappings) as? T else {
                return nil
            }
            readBlock?(object, $0)
            return object
        }
        return object
    }
    
    public func read<T>(_ block: @escaping ((YapDatabaseReadTransaction) -> T?)) -> T? {
        return connection.read(block)
    }
    
    @objc public func read(block: @escaping ((YapDatabaseReadTransaction) -> Any?)) -> Any? {
        return read(block)
    }
}

// MARK: Private API
private extension YapViewHandler {
    
    func setupMappings() -> Bool {
        var mappings: YapDatabaseViewMappings?
        self.connection.read { transaction in
            guard transaction.ext(self.viewName) != nil else {
                return
            }
            switch self.groups {
            case .names(let names):
                mappings = YapDatabaseViewMappings(groups: names, view: self.viewName)
            case .filterSort(let filterBlock, let sortBlock):
                mappings = YapDatabaseViewMappings(groupFilterBlock: filterBlock,
                                                   sortBlock: sortBlock,
                                                   view: self.viewName)
            case .filter(let filterBlock):
                mappings = YapDatabaseViewMappings(groupFilterBlock: filterBlock,
                                                   sortBlock: { (g1, g2, _) in return g1.compare(g2) },
                                                   view: self.viewName)
            case .all:
                mappings = YapDatabaseViewMappings(groupFilterBlock: { _,_ in true },
                                                   sortBlock: { (g1, g2, _) in return g1.compare(g2) },
                                                   view: self.viewName)
            }
            mappings?.update(with: transaction)
        }
        if let mappings = mappings {
            self.mappings = mappings
            return true
        }
        return false
    }
    
    /// Mappings cannot be setup until after the view is ready
    func setupMappingsIfNeeded() -> Bool {
        guard mappings == nil else { return false }
        return setupMappings()
    }
}


extension YapViewHandler: YapViewHandlerProtocol {
    public func yapDatabaseModified(notifications: [Notification]) {
        let newMappings = setupMappingsIfNeeded()
        guard let mappings = self.mappings,
            let viewConnection = connection.ext(viewName) as? YapDatabaseViewConnection else {
            return
        }
        guard !newMappings,
            viewConnection.hasChanges(for: notifications) else {
            connection.read { mappings.update(with: $0) }
            return
        }
        let src = viewConnection.brc_getSectionRowChanges(for: notifications, with: mappings)
        guard src.rowChanges.count > 0 ||
            src.sectionChanges.count > 0 else {
                return
        }
        delegate?.didReceiveChanges(self,
                                    sectionChanges: src.sectionChanges,
                                    rowChanges: src.rowChanges)
    }
}

@objc public protocol YapViewHandlerProtocol: NSObjectProtocol {
    func yapDatabaseModified(notifications: [Notification])
}

@objc public final class LongLivedConnectionManager: NSObject {
    fileprivate let connection: YapDatabaseConnection
    private let viewHandlers: NSHashTable<YapViewHandlerProtocol>
    private var observer: NSObjectProtocol?
    
    @objc public init(database: YapDatabase) {
        self.connection = database.newConnection()
        self.viewHandlers = NSHashTable(options: .weakMemory)
        super.init()
        self.connection.beginLongLivedReadTransaction()
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.YapDatabaseModified,
                                                               object: database,
                                                               queue: OperationQueue.main,
                                                               using: { [weak self] (notification) in
            self?.yapDatabaseModified(notification: notification)
        })
    }
}

fileprivate extension LongLivedConnectionManager {
    func registerHandler(_ handler: YapViewHandlerProtocol) {
        self.viewHandlers.add(handler)
    }
}

private extension LongLivedConnectionManager {
    func yapDatabaseModified(notification: Notification) {
        let notifications = connection.beginLongLivedReadTransaction()
        viewHandlers.allObjects.forEach {
            $0.yapDatabaseModified(notifications: notifications)
        }
    }
}

private extension YapDatabaseViewSectionChange {
    var indexSet: IndexSet {
        return IndexSet(integer: IndexSet.Element(index))
    }
}


public extension UITableView {
    @objc func handleYapViewChanges(sectionChanges: [YapDatabaseViewSectionChange],
                                    rowChanges: [YapDatabaseViewRowChange],
                                    completion: ((Bool) -> Void)? = nil) {
        let updates = {
            sectionChanges.forEach {
                switch $0.type {
                case .insert:
                    self.insertSections($0.indexSet, with: .automatic)
                case .delete:
                    self.deleteSections($0.indexSet, with: .automatic)
                case .move, .update:
                    break
                }
            }
            rowChanges.forEach {
                switch $0.type {
                case .insert:
                    if let newIndexPath = $0.newIndexPath {
                        self.insertRows(at: [newIndexPath], with: .automatic)
                    }
                case .delete:
                    if let indexPath = $0.indexPath {
                        self.deleteRows(at: [indexPath], with: .automatic)
                    }
                case .move:
                    if let indexPath = $0.indexPath,
                        let newIndexPath = $0.newIndexPath {
                        self.moveRow(at: indexPath, to: newIndexPath)
                    }
                case .update:
                    if let indexPath = $0.indexPath {
                        self.reloadRows(at: [indexPath], with: .automatic)
                    }
                }
            }
        }
        
        guard rowChanges.count < 20, sectionChanges.count < 10 else {
            reloadData()
            return
        }
        
        if #available(iOS 11.0, *) {
            self.performBatchUpdates({
                updates()
            }, completion: completion)
        } else {
            beginUpdates()
            updates()
            endUpdates()
            completion?(true)
        }
    }
}

public extension YapDatabaseConnection {
    func read<T>(_ block: @escaping ((YapDatabaseReadTransaction) -> T?)) -> T? {
        var object: T? = nil
        read { transaction in
            object = block(transaction)
        }
        return object
    }
}

@objc public class BRCSectionRowChanges: NSObject {
    @objc public let sectionChanges: [YapDatabaseViewSectionChange]
    @objc public let rowChanges: [YapDatabaseViewRowChange]
    
    @objc public init(sectionChanges: [YapDatabaseViewSectionChange],
                      rowChanges: [YapDatabaseViewRowChange]) {
        self.sectionChanges = sectionChanges
        self.rowChanges = rowChanges
    }
}
