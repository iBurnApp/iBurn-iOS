//
//  Preferences.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/12/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Centralized preference definitions for the app
enum Preferences {
    
    // MARK: - Feature Flags (DEBUG only)
    #if DEBUG
    enum FeatureFlags {
        static let useSwiftUIDetailView = Preference<Bool>(
            key: "featureFlag.detailView.useSwiftUI",
            defaultValue: false,
            description: "Use new SwiftUI detail view instead of legacy UIKit implementation"
        )
        
        // Add more feature flags here as needed
    }
    #endif
    
    // MARK: - Location & Navigation
    enum Location {
        static let historyDisabled = Preference<Bool>(
            key: "locationHistoryDisabled",
            defaultValue: false,
            description: "Disable location history tracking"
        )
        
        static let navigationModeDisabled = Preference<Bool>(
            key: "navigationModeDisabled",
            defaultValue: false,
            description: "Disable navigation mode in map view"
        )
    }
    
    // MARK: - Data & Updates
    enum Data {
        static let downloadsDisabled = Preference<Bool>(
            key: "downloadsDisabled",
            defaultValue: false,
            description: "Disable automatic data updates"
        )
        
        static let lastUpdateCheck = Preference<Date?>(
            key: "lastUpdateCheck",
            defaultValue: nil,
            description: "Last time we checked for data updates"
        )
    }
    
    // MARK: - Embargo
    enum Embargo {
        static let enteredPasscode = Preference<Bool>(
            key: "enteredEmbargoPasscode",
            defaultValue: false,
            description: "User has entered the embargo passcode"
        )
    }
    
    // MARK: - Appearance
    enum Appearance {
        static let theme = Preference<Int>(
            key: "Theme",
            defaultValue: AppTheme.system.rawValue,
            description: "App theme: system, light, or dark"
        )
        
        static let contrast = Preference<Int>(
            key: "Contrast",
            defaultValue: AppColors.colorful.rawValue,
            description: "Color contrast setting"
        )
        
        static let useImageColorsTheming = Preference<Bool>(
            key: "UseImageColorsTheming",
            defaultValue: true,
            description: "Extract colors from images for UI theming"
        )
    }
    
    // MARK: - Filters
    enum Filters {
        static let favorites = Preference<String>(
            key: "FavoritesFilter",
            defaultValue: FavoritesFilter.all.rawValue,
            description: "Selected favorites filter"
        )
        
        static let nearby = Preference<String>(
            key: "NearbyFilter",
            defaultValue: NearbyFilter.all.rawValue,
            description: "Selected nearby filter"
        )
    }
    
    // MARK: - Search
    enum Search {
        static let selectedDayOnly = Preference<Bool>(
            key: "kBRCSearchSelectedDayOnlyKey",
            defaultValue: false,
            description: "Search shows results for selected day only"
        )
    }
}

// MARK: - Migration Helpers

extension Preferences {
    /// Helper to migrate from UserDefaults.isLocationHistoryDisabled
    static func migrateLocationHistoryDisabled() -> Bool {
        return PreferenceServiceFactory.shared.getValue(Location.historyDisabled)
    }
    
    /// Helper to migrate from UserDefaults.isNavigationModeDisabled
    static func migrateNavigationModeDisabled() -> Bool {
        return PreferenceServiceFactory.shared.getValue(Location.navigationModeDisabled)
    }
    
    /// Helper to migrate from UserDefaults.areDownloadsDisabled
    static func migrateDownloadsDisabled() -> Bool {
        // Special handling for event over state
        if YearSettings.isEventOver {
            print("Event is over, disabling remote data updates")
            return true
        }
        return PreferenceServiceFactory.shared.getValue(Data.downloadsDisabled)
    }
    
    /// Helper to migrate from UserDefaults.lastUpdateCheck
    static func migrateLastUpdateCheck() -> Date? {
        return PreferenceServiceFactory.shared.getValue(Data.lastUpdateCheck)
    }
    
    /// Helper to migrate from UserSettings.theme
    static func migrateTheme() -> AppTheme {
        let rawValue = PreferenceServiceFactory.shared.getValue(Appearance.theme)
        return AppTheme(rawValue: rawValue) ?? .system
    }
    
    /// Helper to migrate from UserSettings.useImageColorsTheming
    static func migrateUseImageColorsTheming() -> Bool {
        return PreferenceServiceFactory.shared.getValue(Appearance.useImageColorsTheming)
    }
}