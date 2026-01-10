//
//  Appearance.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import UIKit

@objc public class Appearance: NSObject {
    
    @objc public static var theme: AppTheme {
        set {
            Appearance.shared.theme = newValue
        }
        get {
            return Appearance.shared.theme
        }
    }
    
    @objc public static var contrast: AppColors {
        set {
            Appearance.shared.colors = newValue
        }
        get {
            return Appearance.shared.colors
        }
    }
    
    @objc public static var useImageColorsTheming: Bool {
        set {
            UserSettings.useImageColorsTheming = newValue
        }
        get {
            return UserSettings.useImageColorsTheming
        }
    }
    
    @objc public static var currentColors: BRCImageColors {
        .dynamic
    }
    
    @objc public static var currentBarStyle: UIBarStyle {
        let barStyle: UIBarStyle
        switch theme {
        case .light:
            barStyle = .default
        case .dark:
            barStyle = .black
        case .system:
            barStyle = .default
        }
        return barStyle
    }
    
    private static let shared = Appearance()
    private var theme: AppTheme {
        didSet {
            UserSettings.theme = theme
            setGlobalAppearance()
        }
    }
    private var colors: AppColors {
        didSet {
            UserSettings.contrast = colors
            setGlobalAppearance()
        }
    }
    
    private override init() {
        self.theme = UserSettings.theme
        self.colors = UserSettings.contrast
    }
    
    @objc public static func setGlobalAppearance() {
        Appearance.shared.setGlobalAppearance()
    }
    
    private func setGlobalAppearance() {
        let colors = Appearance.currentColors
        
        Appearance.applyNavigationBarAppearance(UINavigationBar.appearance(), colors: colors, animated: false)
        Appearance.applyTabBarAppearance(UITabBar.appearance(), colors: colors)
        UITableView.appearance().backgroundColor = colors.backgroundColor
        UITableView.appearance().tintColor = colors.primaryColor
        UISwitch.appearance().tintColor = colors.primaryColor
        UISwitch.appearance().onTintColor = colors.primaryColor
    }

}

extension Appearance {
    private static let glassBlurStyle: UIBlurEffect.Style = .systemChromeMaterial
    private static let navBarGlassAlpha: CGFloat = 0.35
    private static let tabBarGlassAlpha: CGFloat = 0.45
    
    private static func glassTintedColor(base: UIColor, alpha: CGFloat) -> UIColor {
        UIColor { traitCollection in
            base.resolvedColor(with: traitCollection).withAlphaComponent(alpha)
        }
    }
    
    private static func makeNavigationBarAppearance(colors: BRCImageColors) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        if UIAccessibility.isReduceTransparencyEnabled {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = colors.backgroundColor
        } else {
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: glassBlurStyle)
            appearance.backgroundColor = glassTintedColor(base: colors.backgroundColor, alpha: navBarGlassAlpha)
        }
        appearance.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: colors.secondaryColor]
        appearance.shadowColor = .clear
        return appearance
    }
    
    private static func makeTabBarAppearance(colors: BRCImageColors) -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        if UIAccessibility.isReduceTransparencyEnabled {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = colors.backgroundColor
        } else {
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: glassBlurStyle)
            appearance.backgroundColor = glassTintedColor(base: colors.backgroundColor, alpha: tabBarGlassAlpha)
        }
        appearance.shadowColor = .clear
        let normalAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: colors.detailColor]
        let selectedAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: colors.primaryColor]
        appearance.stackedLayoutAppearance.normal.iconColor = colors.detailColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.stackedLayoutAppearance.selected.iconColor = colors.primaryColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.inlineLayoutAppearance.normal.iconColor = colors.detailColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.inlineLayoutAppearance.selected.iconColor = colors.primaryColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        appearance.compactInlineLayoutAppearance.normal.iconColor = colors.detailColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = normalAttributes
        appearance.compactInlineLayoutAppearance.selected.iconColor = colors.primaryColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = selectedAttributes
        return appearance
    }
    
    @objc public static func applyNavigationBarAppearance(_ navBar: UINavigationBar, colors: BRCImageColors, animated: Bool) {
        let appearance = makeNavigationBarAppearance(colors: colors)
        let applyTheme = {
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
            navBar.compactAppearance = appearance
            if #available(iOS 15.0, *) {
                navBar.compactScrollEdgeAppearance = appearance
            }
            navBar.tintColor = colors.primaryColor
            navBar.isTranslucent = !UIAccessibility.isReduceTransparencyEnabled
        }
        if animated {
            UIView.transition(with: navBar, duration: 0.25, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: applyTheme, completion: nil)
        } else {
            applyTheme()
        }
    }
    
    @objc public static func applyTabBarAppearance(_ tabBar: UITabBar, colors: BRCImageColors) {
        let appearance = makeTabBarAppearance(colors: colors)
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = colors.primaryColor
        tabBar.unselectedItemTintColor = colors.detailColor
        tabBar.isTranslucent = !UIAccessibility.isReduceTransparencyEnabled
    }
}


@objc public enum AppTheme: Int {
    case system
    case light
    case dark
}

@objc public enum AppColors: Int {
    case colorful
    case highContrast
}

@objc public final class NavigationController: UINavigationController {
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        switch Appearance.theme {
        case .dark:
            return .lightContent
        case .light:
            return .default
        case .system:
            return super.preferredStatusBarStyle
        }
    }
}

extension UITableViewCell: ColorTheme {
    public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        backgroundColor = colors.backgroundColor
        textLabel?.textColor = colors.secondaryColor
        detailTextLabel?.textColor = colors.detailColor
    }
}
