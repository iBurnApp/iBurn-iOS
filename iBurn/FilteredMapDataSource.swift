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
        
        // Visit status data sources - always created for reference
        // We'll use these to check visit status regardless of filter settings
        visitedDataSource = YapViewAnnotationDataSource(
            viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.visitedObjectsViewName)
        )
        wantToVisitDataSource = YapViewAnnotationDataSource(
            viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.wantToVisitObjectsViewName)
        )
        unvisitedDataSource = YapViewAnnotationDataSource(
            viewHandler: YapViewHandler(viewName: BRCDatabaseManager.shared.unvisitedObjectsViewName)
        )
        
        super.init()
    }
    
    public func allAnnotations() -> [MLNAnnotation] {
        // Dictionary handles all de-duplication
        var annotationsByID: [String: MLNAnnotation] = [:]
        
        // Helper to add annotations with type-prefixed keys
        func addToDict(_ annotations: [MLNAnnotation]) {
            for annotation in annotations {
                let key: String
                
                if let dataAnnotation = annotation as? DataObjectAnnotation {
                    // Use the class name of the underlying object
                    let className = String(describing: type(of: dataAnnotation.object))
                    key = "\(className):\(dataAnnotation.object.uniqueID)"
                } else if let mapPoint = annotation as? BRCMapPoint {
                    // Use the class name (BRCMapPoint or BRCUserMapPoint)
                    let className = String(describing: type(of: mapPoint))
                    key = "\(className):\(mapPoint.yapKey)"
                } else {
                    // Fallback for any other annotation types
                    key = "Unknown:\(UUID().uuidString)"
                }
                
                annotationsByID[key] = annotation
            }
        }
        
        // User pins (always shown)
        addToDict(userDataSource.allAnnotations())
        
        // Get selected event types for filtering
        let selectedEventTypes = UserSettings.selectedEventTypesForMap
        
        // Favorites (if enabled)
        if UserSettings.showFavoritesOnMap {
            var favoriteAnnotations = favoritesDataSource.allAnnotations()
            
            // Only filter for "today's favorites" if that setting is on
            if UserSettings.showTodaysFavoritesOnlyOnMap {
                favoriteAnnotations = favoriteAnnotations.filter { annotation in
                    guard let dataAnnotation = annotation as? DataObjectAnnotation,
                          let event = dataAnnotation.object as? BRCEventObject else {
                        return true // Non-events always pass
                    }
                    let calendar = Calendar.current
                    let today = Date.present
                    let eventDate = event.startDate
                    return calendar.isDate(eventDate, inSameDayAs: today)
                }
            }
            
            // Also filter by visit status
            let visitFiltered = filterByVisitStatus(favoriteAnnotations)
            addToDict(visitFiltered)
        }
        
        // Art (if enabled)
        if UserSettings.showArtOnMap, let artDataSource = artDataSource {
            let artAnnotations = artDataSource.allAnnotations()
            // Filter by visit status
            let filteredArt = filterByVisitStatus(artAnnotations)
            addToDict(filteredArt)
        }
        
        // Camps (if enabled)
        if UserSettings.showCampsOnMap, let campsDataSource = campsDataSource {
            let campAnnotations = campsDataSource.allAnnotations()
            // Filter by visit status
            let filteredCamps = filterByVisitStatus(campAnnotations)
            addToDict(filteredCamps)
        }
        
        // Events (if enabled)
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
            
            // Filter by visit status
            let visitFiltered = filterByVisitStatus(filteredEvents)
            addToDict(visitFiltered)
        }
        
        return Array(annotationsByID.values)
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