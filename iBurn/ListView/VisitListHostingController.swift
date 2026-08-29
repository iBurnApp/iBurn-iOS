//
//  VisitListHostingController.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI `VisitListView`.
///
/// Bridges UIKit navigation (paged detail, map) with the PlayaDB visit list.
/// Visit status has no reactive observation API, so the list is reloaded whenever
/// this screen appears (status changes happen on the detail screen) and whenever the
/// app returns to the foreground (a watch sync can apply status changes in the
/// background — see `DependencyContainer`'s `FavoritesSyncManager` hook).
@MainActor
class VisitListHostingController: UIHostingController<VisitListView> {
    private let playaDB: PlayaDB
    private let viewModel: VisitListViewModel
    private var pagingDataSource: DetailPagingDataSource?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = VisitListViewModel(
            playaDB: dependencies.playaDB,
            artProvider: dependencies.artDataProvider,
            campProvider: dependencies.campDataProvider,
            eventProvider: dependencies.eventDataProvider,
            mvProvider: dependencies.mutantVehicleDataProvider,
            locationProvider: dependencies.locationProvider
        )
        super.init(rootView: VisitListView(viewModel: viewModel))
        self.rootView = VisitListView(
            viewModel: viewModel,
            onSelectItem: { [weak self] item in
                self?.showDetail(for: item)
            },
            onShowMap: { [weak self] annotations in
                self?.showMap(annotations: annotations)
            }
        )
        self.title = "Visit List"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Visit status can change on the detail screen (or arrive from the watch),
        // and there is no observation API for it: re-fetch on every appearance.
        viewModel.refresh()
    }

    // MARK: - Navigation

    private func showDetail(for item: VisitListItem) {
        let allItems = viewModel.allItems
        let pageItems = allItems.map(\.detailPageItem)
        guard let index = allItems.firstIndex(where: { $0.uid == item.uid }) else { return }
        let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
        self.pagingDataSource = dataSource
        let pageVC = dataSource.makePageViewController(initialIndex: index)
        navigationController?.pushViewController(pageVC, animated: true)
    }

    private func showMap(annotations: [PlayaObjectAnnotation]) {
        guard BRCEmbargo.allowEmbargoedData() else {
            showAlert(title: "Map Unavailable", message: "Location data is currently restricted.")
            return
        }

        guard !annotations.isEmpty else {
            showAlert(title: "No Mappable Items", message: "None of the items on your visit list have map coordinates.")
            return
        }

        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
