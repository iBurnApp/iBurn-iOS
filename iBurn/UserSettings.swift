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
        static let favoritesFilter = "FavoritesFilter"
        static let nearbyFilter = "NearbyFilter"
        static let useImageColorsTheming = "UseImageColorsTheming"
    }
    
    /// Selected favorites filter
    public static var favoritesFilter: FavoritesFilter {
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.favoritesFilter)
        }
        get {
            guard let string = UserDefaults.standard.string(forKey: Keys.favoritesFilter),
                let filter = FavoritesFilter(rawValue: string) else {
                    return .all
            }
            return filter
        }
    }
    
    /// Selected Nearby filter
    public static var nearbyFilter: NearbyFilter {
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.nearbyFilter)
        }
        get {
            guard let string = UserDefaults.standard.string(forKey: Keys.nearbyFilter),
                let filter = NearbyFilter(rawValue: string) else {
                    return .all
            }
            return filter
        }
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
            return AppTheme(rawValue: rawValue) ?? .system
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
    
    /// Whether to use image colors theming for cells and detail screens
    @objc public static var useImageColorsTheming: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.useImageColorsTheming)
        }
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: Keys.useImageColorsTheming) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.useImageColorsTheming)
        }
    }
}
