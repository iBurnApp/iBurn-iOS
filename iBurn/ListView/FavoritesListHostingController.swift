import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI FavoritesView.
///
/// Bridges UIKit navigation (detail, map) with the new SwiftUI favorites list.
/// Initialized with dependencies from the DependencyContainer.
@MainActor
class FavoritesListHostingController: UIHostingController<FavoritesView> {
    private let playaDB: PlayaDB

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let viewModel = dependencies.makeFavoritesViewModel()
        super.init(rootView: FavoritesView(viewModel: viewModel))
        self.rootView = FavoritesView(
            viewModel: viewModel,
            onSelectArt: { [weak self] art in
                self?.showDetail(for: .art(art))
            },
            onSelectCamp: { [weak self] camp in
                self?.showDetail(for: .camp(camp))
            },
            onSelectEvent: { [weak self] event in
                self?.showDetail(for: .event(event))
            },
            onSelectMV: { [weak self] mv in
                self?.showDetail(for: .mutantVehicle(mv))
            },
            onShowMap: { [weak self] annotations in
                self?.showMap(annotations: annotations)
            }
        )
        self.title = "Favorites"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for item: FavoriteItem) {
        let detailVC: UIViewController
        switch item {
        case .art(let art):
            detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
        case .camp(let camp):
            detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        case .event(let event):
            detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        case .mutantVehicle(let mv):
            detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        }
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func showMap(annotations: [PlayaObjectAnnotation]) {
        guard BRCEmbargo.allowEmbargoedData() else {
            showMissingMapAlert()
            return
        }

        guard !annotations.isEmpty else {
            showMissingMapAlert()
            return
        }

        let dataSource = StaticAnnotationDataSource(annotations: annotations)
        let mapVC = MapListViewController(dataSource: dataSource)
        mapVC.mapViewAdapter.onPlayaInfoTapped = { [weak self] anyID in
            self?.handleMapAnnotationTap(anyID)
        }
        navigationController?.pushViewController(mapVC, animated: true)
    }

    private func handleMapAnnotationTap(_ anyID: AnyDataObjectID) {
        Task {
            switch anyID {
            case .art(let id):
                if let art = try? await playaDB.fetchArt(uid: id.value) {
                    showDetail(for: .art(art))
                }
            case .camp(let id):
                if let camp = try? await playaDB.fetchCamp(uid: id.value) {
                    showDetail(for: .camp(camp))
                }
            case .event(let id):
                if let event = try? await playaDB.fetchEvent(uid: id.value) {
                    let detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
                    navigationController?.pushViewController(detailVC, animated: true)
                }
            case .mutantVehicle(let id):
                if let mv = try? await playaDB.fetchMutantVehicle(uid: id.value) {
                    showDetail(for: .mutantVehicle(mv))
                }
            }
        }
    }

    private func showMissingMapAlert() {
        let alert = UIAlertController(
            title: "No Mappable Favorites",
            message: BRCEmbargo.allowEmbargoedData()
                ? "None of the selected favorites have map coordinates."
                : "Location data is currently restricted.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
