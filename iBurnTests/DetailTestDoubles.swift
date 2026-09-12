//
//  DetailTestDoubles.swift
//  iBurnTests
//
//  Test doubles for the SwiftUI detail screen. These used to live in the app target
//  (`iBurn/Detail/Services/MockServices.swift`), alongside Mantle-backed fixtures; they
//  moved here when the legacy `BRCDataObject` detail path was deleted.
//

import CoreLocation
import Foundation
@testable import iBurn

final class MockLocationService: LocationServiceProtocol {
    var mockLocation: CLLocation?
    var startLocationUpdatesCalled = false
    var stopLocationUpdatesCalled = false

    init(mockLocation: CLLocation? = nil) {
        // Default to a location in Black Rock City
        self.mockLocation = mockLocation ?? CLLocation(latitude: 40.7864, longitude: -119.2065)
    }

    func getCurrentLocation() -> CLLocation? { mockLocation }

    func startLocationUpdates() { startLocationUpdatesCalled = true }

    func stopLocationUpdates() { stopLocationUpdatesCalled = true }
}

final class MockTestDetailActionCoordinator: DetailActionCoordinator {
    private(set) var handledActions: [DetailAction] = []

    func updateNavigator(_ navigator: (any Navigable)?) {}

    func updatePresenter(_ presenter: (any Presentable)?) {}

    func handle(_ action: DetailAction) {
        handledActions.append(action)
    }
}
