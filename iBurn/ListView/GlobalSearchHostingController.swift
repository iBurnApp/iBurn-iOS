import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller wrapping GlobalSearchView.
///
/// Designed to be used as `UISearchController.searchResultsController`.
/// Handles navigation to detail views when search results are tapped.
@MainActor
class GlobalSearchHostingController: UIHostingController<GlobalSearchView> {
    let viewModel: GlobalSearchViewModel
    private let playaDB: PlayaDB

    init(viewModel: GlobalSearchViewModel, playaDB: PlayaDB) {
        self.viewModel = viewModel
        self.playaDB = playaDB
        super.init(rootView: GlobalSearchView(viewModel: viewModel))
        self.rootView = GlobalSearchView(
            viewModel: viewModel,
            onSelectArt: { [weak self] art in
                self?.showDetail(for: art)
            },
            onSelectCamp: { [weak self] camp in
                self?.showDetail(for: camp)
            },
            onSelectEvent: { [weak self] event in
                self?.showDetail(for: event)
            },
            onSelectMV: { [weak self] mv in
                self?.showDetail(for: mv)
            }
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for art: ArtObject) {
        let detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
        presentingNavigationController?.pushViewController(detailVC, animated: true)
    }

    private func showDetail(for camp: CampObject) {
        let detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        presentingNavigationController?.pushViewController(detailVC, animated: true)
    }

    private func showDetail(for event: EventObject) {
        let detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        presentingNavigationController?.pushViewController(detailVC, animated: true)
    }

    private func showDetail(for mv: MutantVehicleObject) {
        let detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        presentingNavigationController?.pushViewController(detailVC, animated: true)
    }

    /// Find the navigation controller that presented the search.
    /// When used as searchResultsController, the presenting VC's nav controller is what we push onto.
    private var presentingNavigationController: UINavigationController? {
        // Walk up from the search results controller to find the presenting nav controller
        presentingViewController?.navigationController ??
        parent?.navigationController ??
        navigationController
    }
}
