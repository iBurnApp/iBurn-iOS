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
    
    /// Creates a detail view controller using the preference system to determine implementation
    /// - Parameters:
    ///   - dataObject: The data object to display
    /// - Returns: Either the new SwiftUI or legacy UIKit implementation based on preference
    static func createDetailViewController(for dataObject: BRCDataObject) -> UIViewController {
        #if DEBUG
        // Check feature flag preference
        let service = PreferenceServiceFactory.shared
        if service.getValue(Preferences.FeatureFlags.useSwiftUIDetailView) {
            // Use new SwiftUI implementation
            return create(with: dataObject)
        }
        #endif
        
        // Use legacy UIKit implementation
        return BRCDetailViewController(dataObject: dataObject)
    }
    
    /// Creates a detail view controller for the given data object
    /// - Parameters:
    ///   - dataObject: The data object to display
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject
    ) -> DetailHostingController {
        
        // Create concrete service instances
        let dataService = DetailDataService()
        let audioService = AudioService()
        let locationService = LocationService()
        
        return create(
            with: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService
        )
    }
    
    /// Creates a detail view controller with custom services (useful for testing)
    /// - Parameters:
    ///   - dataObject: The data object to display
    ///   - dataService: Custom data service implementation
    ///   - audioService: Custom audio service implementation
    ///   - locationService: Custom location service implementation
    /// - Returns: A UIViewController ready for presentation
    static func create(
        with dataObject: BRCDataObject,
        dataService: DetailDataServiceProtocol,
        audioService: AudioServiceProtocol,
        locationService: LocationServiceProtocol
    ) -> DetailHostingController {
        
        // Create coordinator without presenter initially
        let coordinator = DetailActionCoordinatorFactory.makeCoordinator()
        
        // Create viewModel with all dependencies
        let viewModel = DetailViewModel(
            dataObject: dataObject,
            dataService: dataService,
            audioService: audioService,
            locationService: locationService,
            coordinator: coordinator
        )
        
        // Determine colors based on data object type
        let colors = BRCImageColors.colors(for: dataObject, fallback: Appearance.currentColors)
        
        // Create controller with all dependencies
        let controller = DetailHostingController(
            viewModel: viewModel,
            coordinator: coordinator,
            colors: colors,
            dataObject: dataObject
        )
        
        // Update coordinator with the real presenter
        coordinator.updatePresenter(controller)
        
        return controller
    }
}
