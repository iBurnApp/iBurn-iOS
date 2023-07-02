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
        
        let coloredAppearance = UINavigationBarAppearance()
        coloredAppearance.configureWithOpaqueBackground()
        coloredAppearance.backgroundColor = colors.backgroundColor
        coloredAppearance.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
        coloredAppearance.largeTitleTextAttributes = [.foregroundColor: colors.secondaryColor]
               
        UINavigationBar.appearance().standardAppearance = coloredAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = coloredAppearance

        UINavigationBar.appearance().backgroundColor = colors.backgroundColor
        UINavigationBar.appearance().tintColor = colors.primaryColor
        UINavigationBar.appearance().barTintColor = colors.backgroundColor
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: colors.primaryColor]
        UITabBar.appearance().backgroundColor = colors.backgroundColor
        UITabBar.appearance().tintColor = colors.primaryColor
        UITabBar.appearance().barTintColor = colors.backgroundColor
        UITableView.appearance().backgroundColor = colors.backgroundColor
        UITableView.appearance().tintColor = colors.primaryColor
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
