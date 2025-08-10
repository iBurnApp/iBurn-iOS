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
            viewHandler: YapViewHandler(viewName: favoritesViewName)
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
        
        // Add favorites if enabled
        if UserSettings.showFavoritesOnMap {
            let favoriteAnnotations = favoritesDataSource.allAnnotations()
            
            if UserSettings.showTodaysFavoritesOnlyOnMap {
                // Filter to only show today's favorited events
                let todaysAnnotations = favoriteAnnotations.filter { annotation in
                    guard let dataAnnotation = annotation as? DataObjectAnnotation,
                          let event = dataAnnotation.object as? BRCEventObject else {
                        // Not an event, include it (art/camps)
                        return true
                    }
                    // Check if event is happening today
                    let calendar = Calendar.current
                    let today = Date.present
                    let eventDate = event.startDate
                    return calendar.isDate(eventDate, inSameDayAs: today)
                }
                allAnnotations.append(contentsOf: todaysAnnotations)
            } else {
                allAnnotations.append(contentsOf: favoriteAnnotations)
            }
        }
        
        // Add non-favorited art if enabled
        if UserSettings.showArtOnMap, let artDataSource = artDataSource {
            let artAnnotations = artDataSource.allAnnotations()
            // Filter out already included favorites
            let nonFavoriteArt = filterOutFavorites(artAnnotations)
            allAnnotations.append(contentsOf: nonFavoriteArt)
        }
        
        // Add non-favorited camps if enabled
        if UserSettings.showCampsOnMap, let campsDataSource = campsDataSource {
            let campAnnotations = campsDataSource.allAnnotations()
            // Filter out already included favorites
            let nonFavoriteCamps = filterOutFavorites(campAnnotations)
            allAnnotations.append(contentsOf: nonFavoriteCamps)
        }
        
        // Add active events if enabled
        if UserSettings.showActiveEventsOnMap, let eventsDataSource = eventsDataSource {
            let eventAnnotations = eventsDataSource.allAnnotations()
            // Filter out already included favorites
            let nonFavoriteEvents = filterOutFavorites(eventAnnotations)
            allAnnotations.append(contentsOf: nonFavoriteEvents)
        }
        
        return allAnnotations
    }
    
    private func filterOutFavorites(_ annotations: [MLNAnnotation]) -> [MLNAnnotation] {
        // If favorites are not shown, return all annotations
        guard UserSettings.showFavoritesOnMap else {
            return annotations
        }
        
        // Filter out annotations that are already shown as favorites
        return annotations.filter { annotation in
            guard let dataAnnotation = annotation as? DataObjectAnnotation else {
                return true
            }
            return !dataAnnotation.metadata.isFavorite
        }
    }
    
    /// Reload data sources when settings change
    func reloadDataSources() {
        // This will be called when filter settings change
        // The MainMapViewController will need to create a new instance
        // and reload annotations
    }
}