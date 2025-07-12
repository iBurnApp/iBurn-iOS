//
//  AudioServiceProtocol.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation

/// Protocol for audio operations in the detail view
protocol AudioServiceProtocol {
    /// Plays an audio tour for art objects
    /// - Parameter artObjects: The art objects with audio to play
    func playAudio(artObjects: [BRCArtObject])
    
    /// Pauses the currently playing audio
    func pauseAudio()
    
    /// Checks if a specific art object's audio is currently playing
    /// - Parameter artObject: The art object to check
    /// - Returns: True if the art object's audio is playing
    func isPlaying(artObject: BRCArtObject) -> Bool
    
    /// Toggles play/pause for currently playing audio
    func togglePlayPause()
}

/// Protocol for location-related operations in the detail view
protocol LocationServiceProtocol {
    /// Gets the current user location
    /// - Returns: The current location, or nil if unavailable
    func getCurrentLocation() -> CLLocation?
    
    /// Calculates distance from current location to a data object
    /// - Parameter object: The data object to calculate distance to
    /// - Returns: The distance in meters, or nil if calculation fails
    func distanceToObject(_ object: BRCDataObject) -> CLLocationDistance?
    
    /// Starts monitoring location updates for distance calculations
    func startLocationUpdates()
    
    /// Stops monitoring location updates
    func stopLocationUpdates()
}