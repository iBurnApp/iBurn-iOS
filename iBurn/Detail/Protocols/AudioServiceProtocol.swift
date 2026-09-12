//
//  LocationServiceProtocol.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

/// Protocol for location-related operations in the detail view
protocol LocationServiceProtocol {
    /// Gets the current user location
    /// - Returns: The current location, or nil if unavailable
    func getCurrentLocation() -> CLLocation?
    
    /// Starts monitoring location updates for distance calculations
    func startLocationUpdates()
    
    /// Stops monitoring location updates
    func stopLocationUpdates()
}