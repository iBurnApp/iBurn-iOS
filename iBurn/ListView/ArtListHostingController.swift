//
//  ArtListHostingController.swift
//  iBurn
//
//  Created by Claude Code on 10/25/25.
//  Copyright © 2025 Burning Man Earth. All rights reserved.
//

import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI ArtListView
///
/// This controller acts as a bridge between the legacy UIKit-based navigation
/// and the new SwiftUI list implementation. It's initialized with dependencies
/// from the DependencyContainer and presents the ArtListView.
///
/// Usage:
/// ```swift
/// let controller = try ArtListHostingController(dependencies: appDelegate.dependencies)
/// navigationController.pushViewController(controller, animated: true)
/// ```
@MainActor
class ArtListHostingController: UIHostingController<ArtListView> {
    private let legacyDataStore: LegacyDataStore

    /// Initialize the hosting controller with dependencies
    /// - Parameter dependencies: The dependency container providing PlayaDB and other services
    /// - Throws: Errors from creating the view model
    init(dependencies: DependencyContainer) {
        self.legacyDataStore = LegacyDataStore()
        let viewModel = dependencies.makeArtListViewModel()
        super.init(rootView: ArtListView(viewModel: viewModel))
        self.rootView = ArtListView(
            viewModel: viewModel,
            onSelect: { [weak self] art in
                self?.showDetail(for: art)
            },
            onShowMap: { [weak self] arts in
                self?.showMap(for: arts)
            }
        )
        self.title = "Art"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for art: ArtObject) {
        guard let dataObject = legacyDataStore.dataObject(for: art.uid, type: .art) else {
            showMissingObjectAlert(name: art.name)
            return
        }

        let detailVC = DetailViewControllerFactory.createDetailViewController(for: dataObject)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func showMap(for arts: [ArtObject]) {
        let annotations = legacyDataStore.annotations(for: arts)
        guard !annotations.isEmpty else {
            showMissingMapAlert()
            return
        }

        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func showMissingObjectAlert(name: String) {
        let alert = UIAlertController(
            title: "Unable to Load Detail",
            message: "Could not find details for \(name).",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showMissingMapAlert() {
        let alert = UIAlertController(
            title: "No Mappable Art",
            message: "None of the selected art items have map coordinates.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
