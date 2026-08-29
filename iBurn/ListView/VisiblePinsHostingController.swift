//
//  VisiblePinsHostingController.swift
//  iBurn
//
//  Hosts VisiblePinsView for the map's nav-bar list button.
//

import MapLibre
import PlayaDB
import SwiftUI
import UIKit

@MainActor
final class VisiblePinsHostingController: UIHostingController<VisiblePinsView> {
    private let playaDB: PlayaDB

    /// - Parameters:
    ///   - annotations: snapshot of the annotations currently on the map (already
    ///     restricted to the visible bounds by the caller).
    ///   - onSelectUserPin: invoked when a user map pin row is tapped; the map screen
    ///     pops back and selects the pin.
    init(
        annotations: [MLNAnnotation],
        dependencies: DependencyContainer,
        onSelectUserPin: @escaping (BRCUserMapPoint) -> Void = { _ in }
    ) {
        self.playaDB = dependencies.playaDB
        let viewModel = VisiblePinsViewModel(
            annotations: annotations,
            playaDB: dependencies.playaDB,
            locationProvider: dependencies.locationProvider
        )
        super.init(rootView: VisiblePinsView(viewModel: viewModel))
        self.rootView = VisiblePinsView(
            viewModel: viewModel,
            onSelect: { [weak self] subject in
                self?.showDetail(subject)
            },
            onSelectUserPin: onSelectUserPin
        )
        self.title = "Visible Pins"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(_ subject: DetailSubject) {
        let detailVC = DetailViewControllerFactory.create(with: subject, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
