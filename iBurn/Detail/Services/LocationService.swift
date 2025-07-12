//
//  LocationService.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

/// Concrete implementation of LocationServiceProtocol that wraps existing location services
class LocationService: LocationServiceProtocol {
    private let locationManager = CLLocationManager()
    
    func getCurrentLocation() -> CLLocation? {
        // Get location from the location manager
        return locationManager.location
    }
    
    func distanceToObject(_ object: BRCDataObject) -> CLLocationDistance? {
        guard let currentLocation = getCurrentLocation(),
              let objectLocation = object.location else {
            return nil
        }
        
        return currentLocation.distance(from: objectLocation)
    }
    
    func startLocationUpdates() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}