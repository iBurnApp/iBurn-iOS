//
//  DetailDataServiceProtocol.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Protocol for data operations in the detail view
protocol DetailDataServiceProtocol {
    /// Updates the favorite status for a data object
    /// - Parameters:
    ///   - object: The data object to update
    ///   - isFavorite: Whether the object should be favorited
    func updateFavoriteStatus(for object: BRCDataObject, isFavorite: Bool) async throws
    
    /// Updates the user notes for a data object
    /// - Parameters:
    ///   - object: The data object to update
    ///   - notes: The new notes text
    func updateUserNotes(for object: BRCDataObject, notes: String) async throws
    
    /// Gets the metadata for a data object
    /// - Parameter object: The data object
    /// - Returns: The metadata or nil if not found
    func getMetadata(for object: BRCDataObject) -> BRCObjectMetadata?
    
    /// Checks if location data can be shown for an object (embargo handling)
    /// - Parameter object: The data object
    /// - Returns: True if location can be shown
    func canShowLocation(for object: BRCDataObject) -> Bool
    
    /// Gets a camp object by its unique ID
    /// - Parameter id: The camp's unique ID
    /// - Returns: The camp object or nil if not found
    func getCamp(withId id: String) -> BRCCampObject?
    
    /// Gets an art object by its unique ID
    /// - Parameter id: The art's unique ID
    /// - Returns: The art object or nil if not found
    func getArt(withId id: String) -> BRCArtObject?
    
    /// Gets events hosted by a camp
    /// - Parameter camp: The camp object
    /// - Returns: Array of events hosted by the camp
    func getEvents(for camp: BRCCampObject) -> [BRCEventObject]?
    
    /// Gets events hosted by an art installation
    /// - Parameter art: The art object
    /// - Returns: Array of events hosted by the art
    func getEvents(for art: BRCArtObject) -> [BRCEventObject]?
}