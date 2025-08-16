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
    
    /// Updates the visit status for a data object
    /// - Parameters:
    ///   - object: The data object to update
    ///   - visitStatus: The new visit status
    func updateVisitStatus(for object: BRCDataObject, visitStatus: BRCVisitStatus) async throws
    
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
    
    /// Gets the next chronological event from the same host after the current event
    /// - Parameters:
    ///   - hostId: The unique ID of the host (camp or art)
    ///   - currentEvent: The current event to exclude and use as time reference
    /// - Returns: The next event from the same host, or nil if none found
    func getNextEvent(forHostId hostId: String, after currentEvent: BRCEventObject) -> BRCEventObject?
    
    /// Gets the count of other events from the same host, excluding the current event
    /// - Parameters:
    ///   - hostId: The unique ID of the host (camp or art)  
    ///   - currentEvent: The current event to exclude from count
    /// - Returns: Count of other events from the same host
    func getOtherEventsCount(forHostId hostId: String, excluding currentEvent: BRCEventObject) -> Int
    
    /// Gets the next chronological event for a camp
    /// - Parameter camp: The camp object
    /// - Returns: The next upcoming event for this camp, or nil if none found
    func getNextEvent(for camp: BRCCampObject) -> BRCEventObject?
    
    /// Gets the next chronological event for an art installation
    /// - Parameter art: The art object
    /// - Returns: The next upcoming event for this art, or nil if none found
    func getNextEvent(for art: BRCArtObject) -> BRCEventObject?
}