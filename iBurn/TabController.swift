//
//  TabController.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/14/22.
//  Copyright © 2022 iBurn. All rights reserved.
//

import UIKit

@objc public final class TabController: UITabBarController {
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshTheme()
    }
}

extension TabController {
    func refreshTheme() {
        viewControllers?.forEach {
            $0.refreshNavigationBarColors(false)
            $0.setColorTheme(Appearance.currentColors, animated: false)
            
        }
        tabBar.setColorTheme(Appearance.currentColors, animated: false)
        refreshGlobalTheme()
        Appearance.setGlobalAppearance()
    }
}

extension TabController: ThemeRefreshable {}
