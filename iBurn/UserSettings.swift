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
        static let selectedEventTypes = "kBRCSelectedEventsTypesKey"
        static let showExpiredEvents = "kBRCShowExpiredEventsKey"
        static let showAllDayEvents = "kBRCShowAllDayEventsKey"
        static let showExpiredEventsInFavorites = "kBRCShowExpiredEventsInFavoritesKey"
        static let showTodayOnlyInFavorites = "kBRCShowTodayOnlyInFavoritesKey"
        static let showOnlyArtWithEvents = "kBRCShowOnlyArtWithEventsKey"
        static let showOnlyArtHostedEvents = "kBRCShowOnlyArtHostedEventsKey"
        // Map filter keys
        static let showArtOnMap = "kBRCShowArtOnMapKey"
        static let showCampsOnMap = "kBRCShowCampsOnMapKey"
        static let showActiveEventsOnMap = "kBRCShowActiveEventsOnMapKey"
        static let showFavoritesOnMap = "kBRCShowFavoritesOnMapKey"
        static let showTodaysFavoritesOnlyOnMap = "kBRCShowTodaysFavoritesOnlyOnMapKey"
        static let selectedEventTypesForMap = "kBRCSelectedEventTypesForMapKey"
        // Zoom-based visibility keys
        static let showArtOnlyZoomedIn = "kBRCShowArtOnlyZoomedInKey"
        static let showCampsOnlyZoomedIn = "kBRCShowCampsOnlyZoomedInKey"
        // Visit status keys
        static let showVisitedOnMap = "kBRCShowVisitedOnMapKey"
        static let showWantToVisitOnMap = "kBRCShowWantToVisitOnMapKey"
        static let showUnvisitedOnMap = "kBRCShowUnvisitedOnMapKey"
        static let visitStatusFilterForLists = "kBRCVisitStatusFilterForListsKey"
        // Camp layer keys
        static let showCampBoundaries = "kBRCShowCampBoundariesKey"
        static let showBigCampNames = "kBRCShowBigCampNamesKey"
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
    
    /// Selected event types for filtering
    public static var selectedEventTypes: [BRCEventType] {
        set {
            let numbers = newValue.map { NSNumber(value: $0.rawValue) }
            UserDefaults.standard.set(numbers, forKey: Keys.selectedEventTypes)
        }
        get {
            guard let numbers = UserDefaults.standard.array(forKey: Keys.selectedEventTypes) as? [NSNumber] else { return [] }
            return numbers.compactMap { BRCEventType(rawValue: $0.uintValue) }
        }
    }
    
    /// Show expired events
    @objc public static var showExpiredEvents: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showExpiredEvents)
        }
        get {
            return UserDefaults.standard.bool(forKey: Keys.showExpiredEvents)
        }
    }
    
    /// Show all day events
    @objc public static var showAllDayEvents: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showAllDayEvents)
        }
        get {
            return UserDefaults.standard.bool(forKey: Keys.showAllDayEvents)
        }
    }
    
    /// Show expired events in favorites list
    @objc public static var showExpiredEventsInFavorites: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showExpiredEventsInFavorites)
        }
        get {
            // Default to true to maintain current behavior
            if UserDefaults.standard.object(forKey: Keys.showExpiredEventsInFavorites) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showExpiredEventsInFavorites)
        }
    }
    
    /// Show only today's events in favorites list
    @objc public static var showTodayOnlyInFavorites: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showTodayOnlyInFavorites)
        }
        get {
            // Default to false to maintain current behavior
            return UserDefaults.standard.bool(forKey: Keys.showTodayOnlyInFavorites)
        }
    }
    
    /// Show only art with events in art list
    @objc public static var showOnlyArtWithEvents: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showOnlyArtWithEvents)
        }
        get {
            // Default to false to show all art
            return UserDefaults.standard.bool(forKey: Keys.showOnlyArtWithEvents)
        }
    }
    
    /// Show only events hosted at art
    @objc public static var showOnlyArtHostedEvents: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showOnlyArtHostedEvents)
        }
        get {
            // Default to false to show all events
            return UserDefaults.standard.bool(forKey: Keys.showOnlyArtHostedEvents)
        }
    }
    
    // MARK: - Map Filter Settings
    
    /// Show art on map
    @objc public static var showArtOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showArtOnMap)
        }
        get {
            // Default to false to reduce initial map clutter
            if UserDefaults.standard.object(forKey: Keys.showArtOnMap) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: Keys.showArtOnMap)
        }
    }
    
    /// Show camps on map
    @objc public static var showCampsOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showCampsOnMap)
        }
        get {
            // Default to false to reduce initial map clutter
            if UserDefaults.standard.object(forKey: Keys.showCampsOnMap) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: Keys.showCampsOnMap)
        }
    }
    
    // Default to showing only when zoomed in
    static var showArtOnlyZoomedIn: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.showArtOnlyZoomedIn) == nil {
                return true // Default value
            }
            return UserDefaults.standard.bool(forKey: Keys.showArtOnlyZoomedIn)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showArtOnlyZoomedIn)
        }
    }
    
    static var showCampsOnlyZoomedIn: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.showCampsOnlyZoomedIn) == nil {
                return true // Default value
            }
            return UserDefaults.standard.bool(forKey: Keys.showCampsOnlyZoomedIn)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showCampsOnlyZoomedIn)
        }
    }
    
    /// Show active events on map
    @objc public static var showActiveEventsOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showActiveEventsOnMap)
        }
        get {
            // Default to false to reduce initial map clutter
            if UserDefaults.standard.object(forKey: Keys.showActiveEventsOnMap) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: Keys.showActiveEventsOnMap)
        }
    }
    
    /// Show favorites on map
    @objc public static var showFavoritesOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showFavoritesOnMap)
        }
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: Keys.showFavoritesOnMap) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showFavoritesOnMap)
        }
    }
    
    /// Show only today's favorites on map
    @objc public static var showTodaysFavoritesOnlyOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showTodaysFavoritesOnlyOnMap)
        }
        get {
            // Default to true to show only today's favorites
            if UserDefaults.standard.object(forKey: Keys.showTodaysFavoritesOnlyOnMap) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showTodaysFavoritesOnlyOnMap)
        }
    }
    
    /// Selected event types for map filtering
    public static var selectedEventTypesForMap: [BRCEventType] {
        set {
            let numbers = newValue.map { NSNumber(value: $0.rawValue) }
            UserDefaults.standard.set(numbers, forKey: Keys.selectedEventTypesForMap)
        }
        get {
            guard let numbers = UserDefaults.standard.array(forKey: Keys.selectedEventTypesForMap) as? [NSNumber] else { 
                // Default to all event types if not set
                return BRCEventObject.allVisibleEventTypes.compactMap { BRCEventType(rawValue: $0.uintValue) }
            }
            return numbers.compactMap { BRCEventType(rawValue: $0.uintValue) }
        }
    }
    
    /// Show camp boundaries on map
    @objc public static var showCampBoundaries: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showCampBoundaries)
        }
        get {
            // Default to true
            if UserDefaults.standard.object(forKey: Keys.showCampBoundaries) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showCampBoundaries)
        }
    }
    
    /// Show big camp names on map
    @objc public static var showBigCampNames: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showBigCampNames)
        }
        get {
            // Default to true
            if UserDefaults.standard.object(forKey: Keys.showBigCampNames) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showBigCampNames)
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
    
    // MARK: - Visit Status Filtering
    
    /// Show visited objects on map
    @objc public static var showVisitedOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showVisitedOnMap)
        }
        get {
            // Default to true to show all statuses
            if UserDefaults.standard.object(forKey: Keys.showVisitedOnMap) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showVisitedOnMap)
        }
    }
    
    /// Show want to visit objects on map
    @objc public static var showWantToVisitOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showWantToVisitOnMap)
        }
        get {
            // Default to true to show all statuses
            if UserDefaults.standard.object(forKey: Keys.showWantToVisitOnMap) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showWantToVisitOnMap)
        }
    }
    
    /// Show unvisited objects on map
    @objc public static var showUnvisitedOnMap: Bool {
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.showUnvisitedOnMap)
        }
        get {
            // Default to true to show all statuses
            if UserDefaults.standard.object(forKey: Keys.showUnvisitedOnMap) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Keys.showUnvisitedOnMap)
        }
    }
    
    /// Visit status filter for list views
    public static var visitStatusFilterForLists: Set<BRCVisitStatus> {
        set {
            let numbers = newValue.map { NSNumber(value: $0.rawValue) }
            UserDefaults.standard.set(numbers, forKey: Keys.visitStatusFilterForLists)
        }
        get {
            guard let numbers = UserDefaults.standard.array(forKey: Keys.visitStatusFilterForLists) as? [NSNumber] else { 
                // Default to show all statuses
                return Set(BRCVisitStatus.allCases)
            }
            let statuses = numbers.compactMap { BRCVisitStatus(rawValue: $0.intValue) }
            return Set(statuses)
        }
    }
}
