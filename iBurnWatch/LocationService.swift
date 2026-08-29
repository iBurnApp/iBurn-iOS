//
//  LocationService.swift
//  iBurnWatch
//
//  Created by Claude Code on 7/3/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CoreLocation
import Foundation

/// Wraps CLLocationManager for the watch: continuous location + compass heading.
/// watchOS has no API to summon the system calibration UI
/// (`locationManagerShouldDisplayHeadingCalibration` is iOS-only), so consumers
/// watch `needsCalibration` and show a hint instead.
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var headingDegrees: Double?
    @Published private(set) var headingAccuracy: Double?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    var headingAvailable: Bool {
        CLLocationManager.headingAvailable()
    }

    /// Negative accuracy means the compass is uncalibrated; large values mean
    /// heavy magnetic interference.
    var needsCalibration: Bool {
        guard headingAvailable, let accuracy = headingAccuracy else { return false }
        return accuracy < 0 || accuracy > 45
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            // Before publishing: a fix on the playa latches the region half of
            // the embargo rule, and every location-driven surface re-renders off
            // the assignment below, so it sees the new state on this fix.
            WatchEmbargo.noteLocationFix(latest)
            self.location = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.headingDegrees = heading
            self.headingAccuracy = accuracy
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient CoreLocation errors (e.g. kCLErrorLocationUnknown) are expected; keep last fix.
    }
}
