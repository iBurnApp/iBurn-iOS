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
        self.searchDisplayManager.searchController.delegate = self
    }
}

extension ListCoordinator: YapTableViewAdapterDelegate {
    public func didSelectObject(_ adapter: YapTableViewAdapter, object: DataObject, in tableView: UITableView, at indexPath: IndexPath) {
        let nav = parent?.presentingViewController?.navigationController ??
         parent?.navigationController
        let vc = pageViewManager.pageViewController(for: object.object, at: indexPath, navBar: nav?.navigationBar)
        nav?.pushViewController(vc, animated: true)
    }
}

extension ListCoordinator: UISearchControllerDelegate {
    func didPresentSearchController(_ searchController: UISearchController) {
        pageViewManager.tableView = self.searchDisplayManager.tableViewAdapter.tableView
        pageViewManager.objectProvider = self.searchDisplayManager.viewHandler
        // hack to fix https://github.com/iBurnApp/iBurn-iOS/issues/139
        if #available(iOS 16.0, *) {
            parent?.navigationItem.rightBarButtonItem?.isHidden = true
        } else {
            parent?.navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        pageViewManager.tableView = self.tableViewAdapter.tableView
        pageViewManager.objectProvider = self.tableViewAdapter.viewHandler
        // hack to fix https://github.com/iBurnApp/iBurn-iOS/issues/139
        if #available(iOS 16.0, *) {
            parent?.navigationItem.rightBarButtonItem?.isHidden = false
        } else {
            parent?.navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
}
