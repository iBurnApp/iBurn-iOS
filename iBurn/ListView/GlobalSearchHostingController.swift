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
    private var pagingDataSource: DetailPagingDataSource?

    init(viewModel: GlobalSearchViewModel, playaDB: PlayaDB) {
        self.viewModel = viewModel
        self.playaDB = playaDB
        super.init(rootView: GlobalSearchView(viewModel: viewModel))
        self.rootView = GlobalSearchView(
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
            }
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for item: SearchResultItem) {
        let allItems = viewModel.sections.flatMap(\.items)
        let subjects = allItems.map(\.detailSubject)
        if let index = allItems.firstIndex(where: { $0.uid == item.uid }) {
            let dataSource = DetailPagingDataSource(subjects: subjects, playaDB: playaDB)
            self.pagingDataSource = dataSource
            let pageVC = dataSource.makePageViewController(initialIndex: index)
            presentingNavigationController?.pushViewController(pageVC, animated: true)
        } else {
            let detailVC = DetailViewControllerFactory.create(with: item.detailSubject, playaDB: playaDB)
            presentingNavigationController?.pushViewController(detailVC, animated: true)
        }
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
