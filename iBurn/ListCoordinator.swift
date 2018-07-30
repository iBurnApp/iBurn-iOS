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
    var navigationController: UINavigationController?
    
    init(viewName: String,
         searchViewName: String,
         tableView: UITableView,
         navigationController: UINavigationController? = nil) {
        self.searchDisplayManager = SearchDisplayManager(viewName: searchViewName)
        let viewHandler = YapViewHandler(viewName: viewName)
        self.tableViewAdapter = YapTableViewAdapter(viewHandler: viewHandler,
                                                    tableView: tableView)
        self.pageViewManager = PageViewManager(objectProvider: viewHandler, tableView: tableView)
        self.navigationController = navigationController
        super.init()
        self.tableViewAdapter.delegate = self
    }
}

extension ListCoordinator: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let vc = pageViewManager.pageViewController(for: object.object, at: indexPath, navBar: navigationController?.navigationBar)
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
