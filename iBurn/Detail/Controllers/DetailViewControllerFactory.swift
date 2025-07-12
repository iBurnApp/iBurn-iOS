//
//  DetailViewControllerFactory.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

/// Factory for creating detail view controllers
class DetailViewControllerFactory {
    
    /// Creates a detail view controller for the given data object
    /// - Parameters:
    ///   - dataObject: The data object to display
    ///   - coordinator: Coordinator to handle actions
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject,
        coordinator: DetailActionCoordinator
    ) -> DetailHostingController {
        
        // Create concrete service instances
        let dataService = DetailDataService()
        let audioService = AudioService()
        let locationService = LocationService()
        
        return DetailHostingController(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: coordinator
        )
    }
    
    /// Creates a detail view controller with custom services (useful for testing)
    /// - Parameters:
    ///   - dataObject: The data object to display
    ///   - dataService: Custom data service implementation
    ///   - audioService: Custom audio service implementation
    ///   - locationService: Custom location service implementation
    ///   - coordinator: Coordinator to handle actions
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        coordinator: DetailActionCoordinator
    ) -> DetailHostingController {
        
        return DetailHostingController(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: coordinator
        )
    }
}