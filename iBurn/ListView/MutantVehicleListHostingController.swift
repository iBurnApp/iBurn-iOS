import SwiftUI
import UIKit
import PlayaDB

@MainActor
class MutantVehicleListHostingController: UIHostingController<MutantVehicleListView> {
    private let playaDB: PlayaDB
    private let viewModel: MutantVehicleListViewModel
    private var pagingDataSource: DetailPagingDataSource?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = dependencies.makeMutantVehicleListViewModel()
        super.init(rootView: MutantVehicleListView(viewModel: viewModel))
        self.rootView = MutantVehicleListView(
            viewModel: viewModel,
            onSelect: { [weak self] mv in
                self?.showDetail(for: mv)
            }
        )
        self.title = "Mutant Vehicles"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func showDetail(for mv: MutantVehicleObject) {
        let pageItems = viewModel.filteredItems.map { row in
            DetailPageItem(subject: .mutantVehicle(row.object), metadata: row.metadata, thumbnailColors: row.thumbnailColors)
        }
        guard let index = viewModel.filteredItems.firstIndex(where: { $0.object.uid == mv.uid }) else { return }
        let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
        self.pagingDataSource = dataSource
        let pageVC = dataSource.makePageViewController(initialIndex: index)
        navigationController?.pushViewController(pageVC, animated: true)
    }
}
