//
//  FilteredMapDataSource.swift
//  iBurn
//
//  Created by Claude on 2025-08-10.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase
import CoreLocation

/// Data source that filters map annotations based on user preferences
public class FilteredMapDataSource: NSObject, AnnotationDataSource {
    
    private let artDataSource: YapViewAnnotationDataSource?
    private let campsDataSource: YapViewAnnotationDataSource?
    private let eventsDataSource: YapViewAnnotationDataSource?
    private let favoritesDataSource: YapViewAnnotationDataSource
    private let userDataSource: YapCollectionAnnotationDataSource
    
    override init() {
        // User pins are always shown
        userDataSource = YapCollectionAnnotationDataSource(collection: BRCUserMapPoint.yapCollection)
        userDataSource.allowedClass = BRCUserMapPoint.self
        
        // Favorites data source - can be filtered for today only
        let favoritesViewName = UserSettings.showExpiredEventsInFavorites ?
            BRCDatabaseManager.shared.everythingFilteredByFavorite :
            BRCDatabaseManager.shared.everythingFilteredByFavoriteAndExpiration
        favoritesDataSource = YapViewAnnotationDataSource(
            viewHandler: YapViewHandler(viewName: favoritesViewName),
            showAllEvents: true  // Show all favorited events, not just currently happening
        )
        
        // Art data source - only created if needed
        if UserSettings.showArtOnMap {
            artDataSource = YapViewAnnotationDataSource(
                viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.artViewName)
            )
        } else {
            artDataSource = nil
        }
        
        // Camps data source - only created if needed
        if UserSettings.showCampsOnMap {
            campsDataSource = YapViewAnnotationDataSource(
                viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.campsViewName)
            )
        } else {
            campsDataSource = nil
        }
        
        // Events data source - only created if needed
        if UserSettings.showActiveEventsOnMap {
            // Use events filtered by day and expiration to only show active events
            eventsDataSource = YapViewAnnotationDataSource(
                viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.eventsFilteredByDayExpirationAndTypeViewName),
                showAllEvents: false // Only show currently happening events
            )
        } else {
            eventsDataSource = nil
        }
        
        super.init()
    }
    
    public func allAnnotations() -> [MLNAnnotation] {
        var allAnnotations: [MLNAnnotation] = []
        
        // Always include user pins
        allAnnotations.append(contentsOf: userDataSource.allAnnotations())
        
        // Get selected event types for filtering
        let selectedEventTypes = UserSettings.selectedEventTypesForMap
        
        // Add favorites if enabled
        if UserSettings.showFavoritesOnMap {
            let favoriteAnnotations = favoritesDataSource.allAnnotations()
            
            let filteredFavorites = favoriteAnnotations.filter { annotation in
                guard let dataAnnotation = annotation as? DataObjectAnnotation else {
                    return true
                }
                
                // Filter events by today's setting only (not by type for favorites)
                if let event = dataAnnotation.object as? BRCEventObject {
                    // Check if we're filtering to today only
                    if UserSettings.showTodaysFavoritesOnlyOnMap {
                        let calendar = Calendar.current
                        let today = Date.present
                        let eventDate = event.startDate
                        return calendar.isDate(eventDate, inSameDayAs: today)
                    }
                }
                
                // Not an event or passes all filters
                return true
            }
            
            allAnnotations.append(contentsOf: filteredFavorites)
        }
        
        // Add art if enabled (MapViewAdapter will handle de-duplication)
        if UserSettings.showArtOnMap, let artDataSource = artDataSource {
            let artAnnotations = artDataSource.allAnnotations()
            allAnnotations.append(contentsOf: artAnnotations)
        }
        
        // Add camps if enabled (MapViewAdapter will handle de-duplication)
        if UserSettings.showCampsOnMap, let campsDataSource = campsDataSource {
            let campAnnotations = campsDataSource.allAnnotations()
            allAnnotations.append(contentsOf: campAnnotations)
        }
        
        // Add active events if enabled
        if UserSettings.showActiveEventsOnMap, let eventsDataSource = eventsDataSource {
            let eventAnnotations = eventsDataSource.allAnnotations()
            // Filter by event type
            let filteredEvents = eventAnnotations.filter { annotation in
                guard let dataAnnotation = annotation as? DataObjectAnnotation,
                      let event = dataAnnotation.object as? BRCEventObject else {
                    return true
                }
                return selectedEventTypes.contains(event.eventType)
            }
            allAnnotations.append(contentsOf: filteredEvents)
        }
        
        return allAnnotations
    }
    
    /// Reload data sources when settings change
    func reloadDataSources() {
        // This will be called when filter settings change
        // The MainMapViewController will need to create a new instance
        // and reload annotations
    }
}