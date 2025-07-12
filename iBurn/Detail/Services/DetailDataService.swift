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
        
        let newMetadata = metadata.copy() as! BRCObjectMetadata
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
        
        let newMetadata = metadata.copy() as! BRCObjectMetadata
        newMetadata.userNotes = notes
        
        return await withCheckedContinuation { continuation in
            BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                object.replace(newMetadata, transaction: transaction)
            } completionBlock: {
                continuation.resume()
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
}