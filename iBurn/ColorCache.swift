//
//  ColorCache.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation

extension UIViewController {
    func refreshNavigationBarColors(_ animated: Bool) {
        self.navigationController?.navigationBar.setColorTheme(Appearance.currentColors, animated: animated)
    }
}

@objc public protocol ColorTheme {
    func setColorTheme(_ colors: BRCImageColors, animated: Bool)
}

extension UINavigationBar: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        Appearance.applyNavigationBarAppearance(self, colors: colors, animated: animated)
    }
}

extension UITabBar {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        Appearance.applyTabBarAppearance(self, colors: colors)
    }
}

extension UITableView: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        self.backgroundColor = colors.backgroundColor
        self.tintColor = colors.primaryColor
    }
}

extension UIViewController: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        view.backgroundColor = colors.backgroundColor
        view.tintColor = colors.primaryColor
    }
    
    /**
     * Propagates navbar information from a detail screen to the
     * containing UIPageViewController.
     */
    @objc public func copyParameters(from fromVC: UIViewController) {
        let destination = self
        let source = fromVC

        // https://stackoverflow.com/a/35820522/805882
        let fadeTextAnimation = CATransition()
        fadeTextAnimation.duration = 0.25
        fadeTextAnimation.type = CATransitionType.fade
        navigationController?.navigationBar.layer.add(fadeTextAnimation, forKey: "fadeText")
        
        destination.title = source.title
        if let rightBarButtonItems = source.navigationItem.rightBarButtonItems {
            destination.navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            destination.navigationItem.trailingItemGroups = source.navigationItem.trailingItemGroups
        }
    }
}

extension UIPageViewController {
    /** Copy the paramters from top child view controller */
    @objc public func copyChildParameters() {
        guard let top = self.viewControllers?.first else { return }
        copyParameters(from: top)
    }
}
