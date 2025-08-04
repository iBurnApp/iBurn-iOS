//
//  UserSettings.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

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
    
    // MARK: - Time Shift Configuration
    
    private struct TimeShiftKeys {
        static let isTimeShiftActive = "NearbyTimeShiftActive"
        static let timeShiftDate = "NearbyTimeShiftDate"
        static let timeShiftLatitude = "NearbyTimeShiftLatitude"
        static let timeShiftLongitude = "NearbyTimeShiftLongitude"
    }
    
    /// Time shift configuration for the Nearby screen
    public static var nearbyTimeShiftConfig: TimeShiftConfiguration? {
        get {
            guard UserDefaults.standard.bool(forKey: TimeShiftKeys.isTimeShiftActive) else {
                return nil
            }
            
            let date = UserDefaults.standard.object(forKey: TimeShiftKeys.timeShiftDate) as? Date ?? Date.present
            
            var location: CLLocation? = nil
            let lat = UserDefaults.standard.double(forKey: TimeShiftKeys.timeShiftLatitude)
            let lon = UserDefaults.standard.double(forKey: TimeShiftKeys.timeShiftLongitude)
            if lat != 0 && lon != 0 {
                location = CLLocation(latitude: lat, longitude: lon)
            }
            
            return TimeShiftConfiguration(
                date: date,
                location: location,
                isActive: true
            )
        }
        set {
            if let config = newValue {
                UserDefaults.standard.set(config.isActive, forKey: TimeShiftKeys.isTimeShiftActive)
                UserDefaults.standard.set(config.date, forKey: TimeShiftKeys.timeShiftDate)
                if let location = config.location {
                    UserDefaults.standard.set(location.coordinate.latitude, forKey: TimeShiftKeys.timeShiftLatitude)
                    UserDefaults.standard.set(location.coordinate.longitude, forKey: TimeShiftKeys.timeShiftLongitude)
                } else {
                    UserDefaults.standard.removeObject(forKey: TimeShiftKeys.timeShiftLatitude)
                    UserDefaults.standard.removeObject(forKey: TimeShiftKeys.timeShiftLongitude)
                }
            } else {
                UserDefaults.standard.set(false, forKey: TimeShiftKeys.isTimeShiftActive)
                UserDefaults.standard.removeObject(forKey: TimeShiftKeys.timeShiftDate)
                UserDefaults.standard.removeObject(forKey: TimeShiftKeys.timeShiftLatitude)
                UserDefaults.standard.removeObject(forKey: TimeShiftKeys.timeShiftLongitude)
            }
        }
    }
}
