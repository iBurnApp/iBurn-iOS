import SwiftUI
import UIKit
import PlayaDB

@MainActor
class RecentlyViewedHostingController: UIHostingController<RecentlyViewedView> {
    private let playaDB: PlayaDB
    private let viewModel: RecentlyViewedViewModel
    private var pagingDataSource: DetailPagingDataSource?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = RecentlyViewedViewModel(
            playaDB: dependencies.playaDB,
            locationProvider: dependencies.locationProvider
        )
        super.init(rootView: RecentlyViewedView(viewModel: viewModel))
        self.rootView = RecentlyViewedView(
            viewModel: viewModel,
            onSelectArt: { [weak self] art in
                self?.showDetail(for: .art(art, ViewDates(firstViewed: nil, lastViewed: Date())))
            },
            onSelectCamp: { [weak self] camp in
                self?.showDetail(for: .camp(camp, ViewDates(firstViewed: nil, lastViewed: Date())))
            },
            onSelectEvent: { [weak self] event in
                let detailVC = DetailViewControllerFactory.create(with: event, playaDB: dependencies.playaDB)
                self?.navigationController?.pushViewController(detailVC, animated: true)
            },
            onSelectMV: { [weak self] mv in
                self?.showDetail(for: .mutantVehicle(mv, ViewDates(firstViewed: nil, lastViewed: Date())))
            },
            onShowMap: { [weak self] annotations in
                self?.showMap(annotations: annotations)
            }
        )
        self.title = "Recently Viewed"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Navigation

    private func showDetail(for item: RecentlyViewedItem) {
        let allItems = viewModel.allItems
        let subjects = allItems.map { $0.detailSubject }
        guard let index = allItems.firstIndex(where: { $0.uid == item.uid }) else { return }
        let dataSource = DetailPagingDataSource(subjects: subjects, playaDB: playaDB)
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
            showAlert(title: "No Mappable Items", message: "None of the recently viewed items have map coordinates.")
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
