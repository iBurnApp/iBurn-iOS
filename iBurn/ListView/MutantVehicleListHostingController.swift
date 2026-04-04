import SwiftUI
import UIKit
import PlayaDB

@MainActor
class MutantVehicleListHostingController: UIHostingController<MutantVehicleListView> {
    private let playaDB: PlayaDB

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let viewModel = dependencies.makeMutantVehicleListViewModel()
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
        let detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
