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
    ///   - actionsHandler: Closure to handle navigation actions
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject,
        actionsHandler: @escaping (DetailAction) -> Void
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
            actionsHandler: actionsHandler
        )
    }
    
    /// Creates a detail view controller with custom services (useful for testing)
    /// - Parameters:
    ///   - dataObject: The data object to display
    ///   - dataService: Custom data service implementation
    ///   - audioService: Custom audio service implementation
    ///   - locationService: Custom location service implementation
    ///   - actionsHandler: Closure to handle navigation actions
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol,
        actionsHandler: @escaping (DetailAction) -> Void
    ) -> DetailHostingController {
        
        return DetailHostingController(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            actionsHandler: actionsHandler
        )
    }
}