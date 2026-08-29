//
//  CampListHostingController.swift
//  iBurn
//
//  Created by Codex on 1/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import UIKit
import PlayaDB

@MainActor
class CampListHostingController: UIHostingController<CampListView> {
    private let playaDB: PlayaDB
    private let viewModel: CampListViewModel
    private var pagingDataSource: DetailPagingDataSource?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = dependencies.makeCampListViewModel()
        super.init(rootView: CampListView(viewModel: viewModel))
        self.rootView = makeRootView()
        self.title = "Camps"
        observeEmbargoDidClear()
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRootView() -> CampListView {
        CampListView(
            viewModel: viewModel,
            onSelect: { [weak self] camp in
                self?.showDetail(for: camp)
            },
            onShowMap: { [weak self] camps in
                self?.showMap(for: camps)
            }
        )
    }

    // MARK: - Embargo

    /// Rows read `BRCEmbargo.allowEmbargoedData()` while building their body, so an unlock
    /// while this screen is alive needs an explicit re-render to reveal playa addresses.
    private func observeEmbargoDidClear() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(embargoDidClear),
            name: .BRCEmbargoDidClear,
            object: nil
        )
    }

    @objc private func embargoDidClear() {
        rootView = makeRootView()
    }

    private func showDetail(for camp: CampObject) {
        let pageItems = viewModel.filteredItems.map { row in
            DetailPageItem(subject: .camp(row.object), metadata: row.metadata, thumbnailColors: row.thumbnailColors)
        }
        guard let index = viewModel.filteredItems.firstIndex(where: { $0.object.uid == camp.uid }) else { return }
        let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
        self.pagingDataSource = dataSource
        let pageVC = dataSource.makePageViewController(initialIndex: index)
        navigationController?.pushViewController(pageVC, animated: true)
    }

    private func showMap(for camps: [CampObject]) {
        // Gates tier on purpose, not an oversight: this pins the *whole camp list* at once,
        // which is bulk placement, and the week-early camp release only covers a camp's
        // address and the single camp a user opened. See `MapEmbargo`.
        guard BRCEmbargo.allowEmbargoedData() else {
            showMissingMapAlert()
            return
        }

        let annotations = camps.compactMap { PlayaObjectAnnotation(camp: $0) }
        guard !annotations.isEmpty else {
            showMissingMapAlert()
            return
        }

        let lookup = Dictionary(uniqueKeysWithValues: camps.map { ($0.anyID, $0) })
        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        mapVC.mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            guard let camp = lookup[anyID] else { return }
            self?.showDetail(for: camp)
        }
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func showMissingMapAlert() {
        let alert = UIAlertController(
            title: "No Mappable Camps",
            message: BRCEmbargo.allowEmbargoedData()
                ? "None of the selected camps have map coordinates."
                : "Location data is currently restricted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
