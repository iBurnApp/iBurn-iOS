//
//  UserSettings.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc
public final class UserSettings: NSObject {
    
    private struct Keys {
        static let searchSelectedDayOnly = "kBRCSearchSelectedDayOnlyKey"
        static let theme = "Theme"
        static let contrast = "Contrast"
    }
    
    /** Whether or not search on event view shows results for all days */
    @objc public static var searchSelectedDayOnly: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.searchSelectedDayOnly)
        }
        get {
            return UserDefaults.standard.bool(forKey: Keys.searchSelectedDayOnly)
        }
    }
    
    /// Use Appearance.theme instead
    static var theme: AppTheme {
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.theme)
        }
        get {
            let rawValue = UserDefaults.standard.integer(forKey: Keys.theme)
            return AppTheme(rawValue: rawValue) ?? .light
        }
    }
    
    /// Use Appearance.contrast instead
    static var contrast: AppColors {
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.contrast)
        }
        get {
            let rawValue = UserDefaults.standard.integer(forKey: Keys.contrast)
            return AppColors(rawValue: rawValue) ?? .colorful
        }
    }
}
