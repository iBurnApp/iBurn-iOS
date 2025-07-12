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
}