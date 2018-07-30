//
//  YapTableViewAdapter.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc public protocol YapTableViewAdapterDelegate: NSObjectProtocol {
    func didSelectObject(_ adapter: YapTableViewAdapter,
                         object: DataObject,
                         in tableView: UITableView,
                         at indexPath: IndexPath)
}

@objc public final class YapTableViewAdapter: NSObject {
    let tableView: UITableView
    let viewHandler: YapViewHandler
    let writeConnection: YapDatabaseConnection
    /// For converting sectionIndexTitles
    public var groupTransformer: ((String) -> String)?
    public weak var delegate: YapTableViewAdapterDelegate?
    var audioObserver: NSObjectProtocol?

    /// This will take control of the UITableViewDataSource
    /// and YapViewHandlerDelegate
    @objc public init(viewHandler: YapViewHandler,
                      tableView: UITableView,
                      writeConnection: YapDatabaseConnection = BRCDatabaseManager.shared.readWriteConnection) {
        self.tableView = tableView
        self.viewHandler = viewHandler
        self.writeConnection = writeConnection
        super.init()
        tableView.dataSource = self
        tableView.delegate = self
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

extension YapTableViewAdapter: UITableViewDataSource {
    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var groups = viewHandler.allGroups
        if let groupTransformer = self.groupTransformer {
            groups = groups.map {
                groupTransformer($0)
            }
        }
        groups.insert(UITableViewIndexSearch, at: 0)
        return groups
    }
    
    public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if index > 0 {
            return viewHandler.sectionForGroup(title)
        } else {
            tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
            return NSNotFound
        }
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewHandler.numberOfSections
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewHandler.numberOfItemsInSection(section)
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let object = viewHandler.dataObjectAtIndexPath(indexPath) else {
            return UITableViewCell()
        }
        let cell = BRCDataObjectTableViewCell.cell(at: indexPath, tableView: tableView, dataObject: object, writeConnection: writeConnection)
        return cell
    }
}

extension YapTableViewAdapter: YapViewHandlerDelegate {
    public func didSetupMappings(_ handler: YapViewHandler) {
        tableView.reloadData()
    }
    
    public func didReceiveChanges(_ handler: YapViewHandler, sectionChanges: [YapDatabaseViewSectionChange], rowChanges: [YapDatabaseViewRowChange]) {
        tableView.handleYapViewChanges(sectionChanges: sectionChanges, rowChanges: rowChanges)
    }
}


