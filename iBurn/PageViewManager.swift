//
//  PageViewManager.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit

@objc public final class PageViewManager: NSObject {
    
    let tableView: UITableView
    let objectProvider: DataObjectProvider
    
    @objc public init(objectProvider: DataObjectProvider,
                      tableView: UITableView) {
        self.tableView = tableView
        self.objectProvider = objectProvider
        super.init()
    }
    
    @objc public func pageViewController(for dataObject: BRCDataObject,
                                                at indexPath: IndexPath,
                                                navBar: UINavigationBar? = nil) -> UIViewController {
        let detailVC = BRCDetailViewController(dataObject: dataObject)
        detailVC.indexPath = indexPath
        detailVC.hidesBottomBarWhenPushed = true
        let colors = detailVC.colors
        let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageVC.delegate = self
        pageVC.dataSource = self
        pageVC.hidesBottomBarWhenPushed = true
        navBar?.isTranslucent = false
        navBar?.setColorTheme(colors, animated: false)
        pageVC.setViewControllers([detailVC], direction: .forward, animated: false, completion: nil)
        pageVC.copyChildParameters()
        return pageVC
    }
}

private extension PageViewManager {
    private func pageViewController(_ pageViewController: UIPageViewController, viewControllerNear viewController: UIViewController, direction: IndexPathDirection) -> UIViewController? {
        guard let detailVC = viewController as? BRCDetailViewController,
            let oldIndex = detailVC.indexPath,
            let newIndex = oldIndex.nextIndexPath(direction: direction, tableView: tableView),
            let dataObject = objectProvider.dataObjectAtIndexPath(newIndex) else {
                return nil
        }
        let newDetailVC = BRCDetailViewController(dataObject: dataObject.object)
        newDetailVC.indexPath = newIndex
        self.tableView.scrollToRow(at: newIndex, at: .middle, animated: false)
        return newDetailVC
    }
}

extension PageViewManager: UIPageViewControllerDelegate {
    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        pageViewController.copyChildParameters()
    }
}

extension PageViewManager: UIPageViewControllerDataSource {
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return self.pageViewController(pageViewController, viewControllerNear: viewController, direction: .before)
    }
    
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return self.pageViewController(pageViewController, viewControllerNear: viewController, direction: .after)
    }
}
