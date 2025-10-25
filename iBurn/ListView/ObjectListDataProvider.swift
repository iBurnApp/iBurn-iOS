//
//  ObjectListDataProvider.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
import PlayaDB

/// Protocol for providing data operations for object list views
/// Extracts common logic shared between Art and Camp data providers
///
/// This protocol uses associatedtype to ensure type safety while allowing
/// concrete implementations to work with specific object and filter types.
///
/// Note: The Object type should conform to PlayaDB's DataObject protocol, not the legacy
/// iBurn DataObject class. This is enforced through the concrete implementations.
protocol ObjectListDataProvider<Object, Filter> {
    /// The type of object this provider manages (ArtObject, CampObject, etc.)
    /// This should be a type conforming to PlayaDB.DataObject protocol
    associatedtype Object

    /// The type of filter used to query objects (ArtFilter, CampFilter, etc.)
    associatedtype Filter

    /// Observe objects matching the filter, emitting updates via AsyncStream
    ///
    /// The stream will emit:
    /// - Initial set of objects matching the filter
    /// - Updates whenever the underlying data changes (favorites, new imports, etc.)
    ///
    /// The stream completes when cancelled or when the provider is deallocated.
    ///
    /// - Parameter filter: The filter criteria to apply
    /// - Returns: AsyncStream that yields arrays of matching objects
    func observeObjects(filter: Filter) -> AsyncStream<[Object]>

    /// Toggle the favorite status of an object
    ///
    /// This operation persists to the database and triggers observation updates.
    ///
    /// - Parameter object: The object to toggle favorite status for
    /// - Throws: Database errors
    func toggleFavorite(_ object: Object) async throws

    /// Check if an object is marked as a favorite
    ///
    /// - Parameter object: The object to check
    /// - Returns: True if the object is favorited
    /// - Throws: Database errors
    func isFavorite(_ object: Object) async throws -> Bool

    /// Get a human-readable distance string from a location to an object
    ///
    /// Returns nil if either location is unavailable or if the object has no location.
    ///
    /// - Parameters:
    ///   - location: The starting location (typically user location)
    ///   - object: The object to measure distance to
    /// - Returns: Formatted distance string (e.g., "0.5 mi") or nil
    func distanceString(from location: CLLocation?, to object: Object) -> String?
}
