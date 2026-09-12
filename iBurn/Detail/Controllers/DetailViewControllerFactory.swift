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
    
    static func create(with art: ArtObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .art(art), playaDB: playaDB)
    }

    static func create(with camp: CampObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .camp(camp), playaDB: playaDB)
    }

    static func create(with event: EventObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .event(event), playaDB: playaDB)
    }

    static func create(with mv: MutantVehicleObject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .mutantVehicle(mv), playaDB: playaDB)
    }

    static func create(with occurrence: EventObjectOccurrence, playaDB: PlayaDB) -> DetailHostingController {
        create(with: .eventOccurrence(occurrence), playaDB: playaDB)
    }

    static func create(with subject: DetailSubject, playaDB: PlayaDB) -> DetailHostingController {
        create(with: subject, playaDB: playaDB, preloadedMetadata: nil, preloadedColors: nil)
    }

    static func create(
        with subject: DetailSubject,
        playaDB: PlayaDB,
        preloadedMetadata: ObjectMetadata?,
        preloadedColors: ThumbnailColors?
    ) -> DetailHostingController {
        let coordinator = DetailActionCoordinatorFactory.makeCoordinator()
        let locationService = LocationService()

        let viewModel = DetailViewModel(
            subject: subject,
            playaDB: playaDB,
            locationService: locationService,
            coordinator: coordinator,
            preloadedMetadata: preloadedMetadata,
            preloadedColors: preloadedColors
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
