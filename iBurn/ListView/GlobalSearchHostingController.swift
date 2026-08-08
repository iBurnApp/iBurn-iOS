import Combine
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

    /// Presents search as a transparent layer over whatever opened it rather than as an
    /// opaque screen. Clears this controller's own background too — a clear SwiftUI view
    /// still sits on the hosting view's fill otherwise.
    var isOverlay: Bool = false {
        didSet {
            guard oldValue != isOverlay else { return }
            updateRootView()
            applyBackground()
        }
    }

    /// Whether the scope bar carries the filter button. `installFilterBarButtonItem()`
    /// clears it, so a host with a navigation bar shows the filter control there instead.
    private var showsInlineFilterButton = true {
        didSet {
            guard oldValue != showsInlineFilterButton else { return }
            updateRootView()
        }
    }

    private var filterIconSubscription: AnyCancellable?

    init(viewModel: GlobalSearchViewModel, playaDB: PlayaDB) {
        self.viewModel = viewModel
        self.playaDB = playaDB
        super.init(rootView: GlobalSearchView(viewModel: viewModel))
        updateRootView()
    }

    private func updateRootView() {
        rootView = GlobalSearchView(
            viewModel: viewModel,
            isOverlay: isOverlay,
            showsInlineFilterButton: showsInlineFilterButton,
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

    private func applyBackground() {
        guard isViewLoaded else { return }
        view.backgroundColor = isOverlay ? .clear : nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBackground()
    }

    // MARK: - Filter affordance

    /// Moves the deeper-filter control onto the navigation bar, where every other list
    /// screen in the app keeps its filter button, and takes the inline copy out of the
    /// scope bar so there's only one of them. Only worth calling from a host that actually
    /// has a navigation item — the map overlay and the search-results-controller layout
    /// have none, and keep the inline button.
    func installFilterBarButtonItem() {
        showsInlineFilterButton = false

        let item = UIBarButtonItem(
            image: Self.filterIcon(isDefault: viewModel.filter.isDefault),
            primaryAction: UIAction { [weak self] _ in
                self?.viewModel.isShowingFilters = true
            }
        )
        item.accessibilityLabel = NSLocalizedString("Search Filters", comment: "search filter button")
        navigationItem.rightBarButtonItem = item

        // Filled while anything is narrowing the results, matching the inline button.
        filterIconSubscription = viewModel.$filter
            .receive(on: DispatchQueue.main)
            .sink { [weak item] filter in
                item?.image = Self.filterIcon(isDefault: filter.isDefault)
            }
    }

    private static func filterIcon(isDefault: Bool) -> UIImage? {
        UIImage(systemName: isDefault
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill")
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
