//
//  LocationProvider.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation

/// Protocol for providing location updates
///
/// Abstracts location services for dependency injection and testing.
protocol LocationProvider {
    /// AsyncStream of location updates
    ///
    /// Emits the current location periodically or when location changes.
    /// The stream continues until cancelled or the provider is deallocated.
    var locationStream: AsyncStream<CLLocation?> { get }

    /// Current location (synchronous accessor)
    ///
    /// Returns the most recent location from the location manager.
    var currentLocation: CLLocation? { get }
}

/// Concrete implementation of LocationProvider that wraps CLLocationManager
///
/// This implementation polls the location manager periodically to emit updates.
/// In the future, this could be enhanced to listen to location delegate callbacks
/// or use NotificationCenter if location updates are broadcast.
@MainActor
class CoreLocationProvider: LocationProvider {
    private let locationManager: CLLocationManager
    let locationStream: AsyncStream<CLLocation?>

    var currentLocation: CLLocation? {
        locationManager.location
    }

    /// Initialize the location provider
    ///
    /// - Parameter locationManager: The location manager to wrap
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager

        // Create stream that polls location periodically
        self.locationStream = AsyncStream { continuation in
            let task = Task {
                // Emit initial location
                continuation.yield(locationManager.location)

                // Poll every 5 seconds for location updates
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    continuation.yield(locationManager.location)
                }

                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}

/// Mock implementation for testing
@MainActor
class MockLocationProvider: LocationProvider {
    var mockLocation: CLLocation?

    var currentLocation: CLLocation? {
        mockLocation
    }

    var locationStream: AsyncStream<CLLocation?> {
        AsyncStream { continuation in
            continuation.yield(mockLocation)
            continuation.finish()
        }
    }

    init(mockLocation: CLLocation? = nil) {
        self.mockLocation = mockLocation
    }
}
