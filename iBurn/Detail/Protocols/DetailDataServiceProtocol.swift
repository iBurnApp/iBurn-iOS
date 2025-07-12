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
}