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
    private let playaDB: PlayaDB
    private let viewModel: ArtListViewModel
    private var pagingDataSource: DetailPagingDataSource?

    /// Initialize the hosting controller with dependencies
    /// - Parameter dependencies: The dependency container providing PlayaDB and other services
    /// - Throws: Errors from creating the view model
    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = dependencies.makeArtListViewModel()
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
        let pageItems = viewModel.filteredItems.map { row in
            DetailPageItem(subject: .art(row.object), metadata: row.metadata, thumbnailColors: row.thumbnailColors)
        }
        guard let index = viewModel.filteredItems.firstIndex(where: { $0.object.uid == art.uid }) else { return }
        let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
        self.pagingDataSource = dataSource
        let pageVC = dataSource.makePageViewController(initialIndex: index)
        navigationController?.pushViewController(pageVC, animated: true)
    }

    private func showMap(for arts: [ArtObject]) {
        guard BRCEmbargo.allowEmbargoedData() else {
            showMissingMapAlert()
            return
        }

        let annotations = arts.compactMap { PlayaObjectAnnotation(art: $0) }
        guard !annotations.isEmpty else {
            showMissingMapAlert()
            return
        }

        let lookup = Dictionary(uniqueKeysWithValues: arts.map { ($0.anyID, $0) })
        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        mapVC.mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            guard let art = lookup[anyID] else { return }
            self?.showDetail(for: art)
        }
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func showMissingMapAlert() {
        let alert = UIAlertController(
            title: "No Mappable Art",
            message: BRCEmbargo.allowEmbargoedData()
                ? "None of the selected art items have map coordinates."
                : "Location data is currently restricted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
