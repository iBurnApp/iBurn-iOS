//
//  PageViewManager.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/29/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit
import SafariServices
import EventKitUI

@objc public final class PageViewManager: NSObject {
    
    var tableView: UITableView
    var objectProvider: DataObjectProvider
    
    @objc public init(objectProvider: DataObjectProvider,
                      tableView: UITableView) {
        self.tableView = tableView
        self.objectProvider = objectProvider
        super.init()
    }
    
    @objc public func pageViewController(for dataObject: BRCDataObject,
                                                at indexPath: IndexPath,
                                                navBar: UINavigationBar? = nil) -> UIViewController {
        let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        
        // Create detail view controller (coordinator is handled internally)
        let detailVC = DetailViewControllerFactory.createDetailViewController(for: dataObject)
        
        // Set indexPath and get colors based on controller type
        let colors: BRCImageColors
        if let brcDetail = detailVC as? BRCDetailViewController {
            brcDetail.indexPath = indexPath
            colors = brcDetail.colors
        } else if let hostingDetail = detailVC as? DetailHostingController {
            hostingDetail.indexPath = indexPath
            colors = hostingDetail.colors
        } else {
            colors = Appearance.currentColors
        }
        
        pageVC.delegate = self
        pageVC.dataSource = self
        navBar?.isTranslucent = false
        navBar?.setColorTheme(colors, animated: false)
        pageVC.setViewControllers([detailVC], direction: .forward, animated: false, completion: nil)
        pageVC.copyChildParameters()
        return pageVC
    }
}

private extension PageViewManager {
    private func pageViewController(_ pageViewController: UIPageViewController, viewControllerNear viewController: UIViewController, direction: IndexPathDirection) -> UIViewController? {
        guard let detailVC = viewController as? DetailHostingController,
            let oldIndex = detailVC.indexPath,
            let newIndex = oldIndex.nextIndexPath(direction: direction, tableView: tableView),
            let dataObject = objectProvider.dataObjectAtIndexPath(newIndex) else {
                return nil
        }
        
        // Create new detail view controller (coordinator is handled internally)
        let newDetailVC = DetailViewControllerFactory.createDetailViewController(for: dataObject.object)
        
        // Set indexPath based on controller type
        if let brcDetail = newDetailVC as? BRCDetailViewController {
            brcDetail.indexPath = newIndex
        } else if let hostingDetail = newDetailVC as? DetailHostingController {
            hostingDetail.indexPath = newIndex
        }
        // there was a crash sometimes when the index isn't found
        // i am guessing it's happening when filters are applied so the indices don't match up
        if tableView.hasRow(at: newIndex) {
            self.tableView.scrollToRow(at: newIndex, at: .middle, animated: false)
        }
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

extension UITableView {
    /// https://stackoverflow.com/a/36884941
    func hasRow(at indexPath: IndexPath) -> Bool {
        return indexPath.section < self.numberOfSections && indexPath.row < self.numberOfRows(inSection: indexPath.section)
    }
}
