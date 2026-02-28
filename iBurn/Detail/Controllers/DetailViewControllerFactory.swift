//
//  DetailViewControllerFactory.swift
//  iBurn
//
//  Created by Claude Code on 7/12/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit
import PlayaDB

/// Factory for creating detail view controllers
@MainActor
class DetailViewControllerFactory {
    
    /// Creates a detail view controller using the preference system to determine implementation
    /// - Parameters:
    ///   - dataObject: The data object to display
    /// - Returns: Either the new SwiftUI or legacy UIKit implementation based on preference
    static func createDetailViewController(for dataObject: BRCDataObject) -> UIViewController {
        // Check user interface preference
        let service = PreferenceServiceFactory.shared
        if service.getValue(Preferences.UserInterface.useSwiftUIDetailView) {
            // Use new SwiftUI implementation
            return create(with: dataObject)
        }
        
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
        
        // Create controller with all dependencies
        let controller = DetailHostingController(
            viewModel: viewModel,
            coordinator: coordinator,
            title: dataObject.title
        )
        
        // Update coordinator with the real presenter
        coordinator.updatePresenter(controller)
        
        return controller
    }

    static func create(with art: ArtObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .art(art), playaDB: playaDB)
    }

    static func create(with camp: CampObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .camp(camp), playaDB: playaDB)
    }

    static func create(with event: EventObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .event(event), playaDB: playaDB)
    }

    static func create(with occurrence: EventObjectOccurrence, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .eventOccurrence(occurrence), playaDB: playaDB)
    }

    static func create(with subject: DetailSubject, playaDB: PlayaDB) -> DetailHostingController {
        let coordinator = DetailActionCoordinatorFactory.makeCoordinator()
        let locationService = LocationService()

        let viewModel = DetailViewModel(
            subject: subject,
            playaDB: playaDB,
            locationService: locationService,
            coordinator: coordinator
        )

        let controller = DetailHostingController(
            viewModel: viewModel,
            coordinator: coordinator,
            title: viewModel.title
        )

        coordinator.updatePresenter(controller)
        return controller
    }
}
