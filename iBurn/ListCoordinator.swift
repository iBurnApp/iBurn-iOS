//
//  ListCoordinator.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation


@objc class ListCoordinator: NSObject {
    let searchDisplayManager: SearchDisplayManager
    let pageViewManager: PageViewManager
    let tableViewAdapter: YapTableViewAdapter
    weak var parent: UIViewController?
    
    init(viewName: String,
         searchViewName: String,
         tableView: UITableView,
         parent: UIViewController? = nil) {
        self.searchDisplayManager = SearchDisplayManager(viewName: searchViewName)
        let viewHandler = YapViewHandler(viewName: viewName)
        self.tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler,
                                                    tableView: tableView)
        self.pageViewManager = PageViewManager(objectProvider: viewHandler, tableView: tableView)
        self.parent = parent
        super.init()
        self.tableViewAdapter.delegate = self
        self.searchDisplayManager.tableViewAdapter.delegate = self
    }
}

extension ListCoordinator: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let vc = pageViewManager.pageViewController(for: object.object, at: indexPath, navBar: parent?.navigationController?.navigationBar)
        parent?.navigationController?.pushViewController(vc, animated: false)
        searchDisplayManager.searchController.isActive = false
    }
}
