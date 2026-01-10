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
    private let legacyDataStore: LegacyDataStore

    init(dependencies: DependencyContainer) {
        self.legacyDataStore = LegacyDataStore()
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
        guard let dataObject = legacyDataStore.dataObject(for: camp.uid, type: .camp) else {
            showMissingObjectAlert(name: camp.name)
            return
        }

        let detailVC = DetailViewControllerFactory.createDetailViewController(for: dataObject)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func showMap(for camps: [CampObject]) {
        let annotations = legacyDataStore.annotations(for: camps)
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
            title: "No Mappable Camps",
            message: "None of the selected camps have map coordinates.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
