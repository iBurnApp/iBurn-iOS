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
    private let visitedDataSource: YapViewAnnotationDataSource?
    private let wantToVisitDataSource: YapViewAnnotationDataSource?
    private let unvisitedDataSource: YapViewAnnotationDataSource?
    
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
        
        // Visit status data sources - only created if filtering is active
        if !UserSettings.showVisitedOnMap || !UserSettings.showWantToVisitOnMap || !UserSettings.showUnvisitedOnMap {
            // Only create data sources if we're actually filtering (not showing all)
            if UserSettings.showVisitedOnMap {
                visitedDataSource = YapViewAnnotationDataSource(
                    viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.visitedObjectsViewName)
                )
            } else {
                visitedDataSource = nil
            }
            
            if UserSettings.showWantToVisitOnMap {
                wantToVisitDataSource = YapViewAnnotationDataSource(
                    viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.wantToVisitObjectsViewName)
                )
            } else {
                wantToVisitDataSource = nil
            }
            
            if UserSettings.showUnvisitedOnMap {
                unvisitedDataSource = YapViewAnnotationDataSource(
                    viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.unvisitedObjectsViewName)
                )
            } else {
                unvisitedDataSource = nil
            }
        } else {
            // All visit statuses are shown, so don't filter
            visitedDataSource = nil
            wantToVisitDataSource = nil
            unvisitedDataSource = nil
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
            
            // Also filter by visit status
            let visitFiltered = filterByVisitStatus(filteredFavorites)
            allAnnotations.append(contentsOf: visitFiltered)
        }
        
        // Add non-favorited art if enabled
        if UserSettings.showArtOnMap, let artDataSource = artDataSource {
            let artAnnotations = artDataSource.allAnnotations()
            // Filter out already included favorites
            let nonFavoriteArt = filterOutFavorites(artAnnotations)
            // Filter by visit status
            let filteredArt = filterByVisitStatus(nonFavoriteArt)
            allAnnotations.append(contentsOf: filteredArt)
        }
        
        // Add non-favorited camps if enabled
        if UserSettings.showCampsOnMap, let campsDataSource = campsDataSource {
            let campAnnotations = campsDataSource.allAnnotations()
            // Filter out already included favorites
            let nonFavoriteCamps = filterOutFavorites(campAnnotations)
            // Filter by visit status
            let filteredCamps = filterByVisitStatus(nonFavoriteCamps)
            allAnnotations.append(contentsOf: filteredCamps)
        }
        
        // Add active events if enabled
        if UserSettings.showActiveEventsOnMap, let eventsDataSource = eventsDataSource {
            let eventAnnotations = eventsDataSource.allAnnotations()
            // Filter out already included favorites and filter by event type
            let filteredEvents = eventAnnotations.filter { annotation in
                guard let dataAnnotation = annotation as? DataObjectAnnotation,
                      let event = dataAnnotation.object as? BRCEventObject else {
                    return true
                }
                
                // Filter by event type
                if !selectedEventTypes.contains(event.eventType) {
                    return false
                }
                
                // Filter out favorites
                return !dataAnnotation.metadata.isFavorite
            }
            // Filter by visit status
            let visitFiltered = filterByVisitStatus(filteredEvents)
            allAnnotations.append(contentsOf: visitFiltered)
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
    
    /// Filter annotations by visit status based on user settings
    private func filterByVisitStatus(_ annotations: [MLNAnnotation]) -> [MLNAnnotation] {
        // If all visit statuses are shown, don't filter
        if UserSettings.showVisitedOnMap && UserSettings.showWantToVisitOnMap && UserSettings.showUnvisitedOnMap {
            return annotations
        }
        
        // Filter based on visit status settings
        return annotations.filter { annotation in
            guard let dataAnnotation = annotation as? DataObjectAnnotation else {
                return true // Always show non-data annotations
            }
            
            let visitStatus = BRCVisitStatus(rawValue: dataAnnotation.metadata.visitStatus) ?? .unvisited
            
            switch visitStatus {
            case .visited:
                return UserSettings.showVisitedOnMap
            case .wantToVisit:
                return UserSettings.showWantToVisitOnMap
            case .unvisited:
                return UserSettings.showUnvisitedOnMap
            }
        }
    }
    
    /// Reload data sources when settings change
    func reloadDataSources() {
        // This will be called when filter settings change
        // The MainMapViewController will need to create a new instance
        // and reload annotations
    }
}