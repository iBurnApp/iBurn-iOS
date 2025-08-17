//
//  DetailDataService.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import YapDatabase

/// Concrete implementation of DetailDataServiceProtocol
class DetailDataService: DetailDataServiceProtocol {
    
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }
        
        let newMetadata = metadata.metadataCopy()
        newMetadata.isFavorite = isFavorite
        
        return await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
                
                // Handle calendar integration for events (existing behavior)
                if let event = object as? BRCEventObject {
                    event.refreshCalendarEntry(transaction)
                }
            } completionBlock: {
                continuation.resume()
            }
        }
    }
    
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }
        
        let newMetadata = metadata.metadataCopy()
        newMetadata.userNotes = notes
        
        return await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
            } completionBlock: {
                continuation.resume()
            }
        }
    }
    
    func updateVisitStatus(for object: BRCDataObject, visitStatus: BRCVisitStatus) async throws {
        guard let metadata = getMetadata(for: object) else {
            throw DetailError.invalidData
        }
        
        let newMetadata = metadata.metadataCopy()
        newMetadata.visitStatus = visitStatus.rawValue
        
        return await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
            } completionBlock: {
                // Refresh the visit status grouped view to trigger real-time updates
                BRCDatabaseManager.shared.refreshVisitStatusGroupedView {
                    continuation.resume()
                }
            }
        }
    }
    
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata? {
        var metadata: BRCObjectMetadata?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            metadata = object.metadata(with: transaction)
        }
        
        return metadata
    }
    
    func canShowLocation(for object: BRCDataObject) -> Bool {
        return BRCEmbargo.canShowLocation(for: object)
    }
    
    func getCamp(withId id: String) -> BRCCampObject? {
        var camp: BRCCampObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            camp = transaction.object(forKey: id, inCollection: BRCCampObject.yapCollection) as? BRCCampObject
        }
        
        return camp
    }
    
    func getArt(withId id: String) -> BRCArtObject? {
        var art: BRCArtObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            art = transaction.object(forKey: id, inCollection: BRCArtObject.yapCollection) as? BRCArtObject
        }
        
        return art
    }
    
    func getEvents(for camp: BRCCampObject) -> [BRCEventObject]? {
        var events: [BRCEventObject] = []
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            events = camp.events(with: transaction)
        }
        
        return events.isEmpty ? nil : events
    }
    
    func getEvents(for art: BRCArtObject) -> [BRCEventObject]? {
        var events: [BRCEventObject] = []
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            events = art.events(with: transaction)
        }
        
        return events.isEmpty ? nil : events
    }
    
    func getNextEvent(forHostId hostId: String, after currentEvent: BRCEventObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            // Get all events for this host
            var allEvents: [BRCEventObject] = []
            
            // Try to get host as camp first
            if let camp = transaction.object(forKey: hostId, inCollection: BRCCampObject.yapCollection) as? BRCCampObject {
                allEvents = camp.events(with: transaction)
            }
            // If not found as camp, try as art
            else if let art = transaction.object(forKey: hostId, inCollection: BRCArtObject.yapCollection) as? BRCArtObject {
                allEvents = art.events(with: transaction)
            }
            
            // Filter out current event and get events that start after current event
            let currentStartDate = currentEvent.startDate
            let futureEvents = allEvents.filter { event in
                return event.uniqueID != currentEvent.uniqueID && 
                       event.startDate.compare(currentStartDate) == .orderedDescending
            }
            
            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }
        
        return nextEvent
    }
    
    func getOtherEventsCount(forHostId hostId: String, excluding currentEvent: BRCEventObject) -> Int {
        var count = 0
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            // Get all events for this host
            var allEvents: [BRCEventObject] = []
            
            // Try to get host as camp first
            if let camp = transaction.object(forKey: hostId, inCollection: BRCCampObject.yapCollection) as? BRCCampObject {
                allEvents = camp.events(with: transaction)
            }
            // If not found as camp, try as art
            else if let art = transaction.object(forKey: hostId, inCollection: BRCArtObject.yapCollection) as? BRCArtObject {
                allEvents = art.events(with: transaction)
            }
            
            // Count events excluding the current one
            count = allEvents.filter { $0.uniqueID != currentEvent.uniqueID }.count
        }
        
        return count
    }
    
    func getNextEvent(for camp: BRCCampObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            let allEvents = camp.events(with: transaction)
            let now = Date()
            
            // Get events that start after now
            let futureEvents = allEvents.filter { event in
                return event.startDate.compare(now) == .orderedDescending
            }
            
            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }
        
        return nextEvent
    }
    
    func getNextEvent(for art: BRCArtObject) -> BRCEventObject? {
        var nextEvent: BRCEventObject?
        
        BRCDatabaseManager.shared.uiConnection.read { transaction in
            let allEvents = art.events(with: transaction)
            let now = Date()
            
            // Get events that start after now
            let futureEvents = allEvents.filter { event in
                return event.startDate.compare(now) == .orderedDescending
            }
            
            // Sort by start date and get the next one
            nextEvent = futureEvents.sorted { $0.startDate.compare($1.startDate) == .orderedAscending }.first
        }
        
        return nextEvent
    }
}