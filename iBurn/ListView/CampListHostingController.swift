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

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let viewModel = dependencies.makeCampListViewModel()
        super.init(rootView: CampListView(viewModel: viewModel))
        self.rootView = CampListView(
            viewModel: viewModel,
            onSelect: { [weak self] camp in
                self?.showDetail(for: camp)
            },
            onShowMap: { [weak self] camps in
                self?.showMap(for: camps)
            }
        )
        self.title = "Camps"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showDetail(for camp: CampObject) {
        let detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func showMap(for camps: [CampObject]) {
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
