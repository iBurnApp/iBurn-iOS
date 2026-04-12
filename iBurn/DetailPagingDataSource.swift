import UIKit
import PlayaDB

/// Pre-loaded data for a single detail page.
struct DetailPageItem {
    let subject: DetailSubject
    let metadata: ObjectMetadata?
    let thumbnailColors: ThumbnailColors?

    init(subject: DetailSubject, metadata: ObjectMetadata? = nil, thumbnailColors: ThumbnailColors? = nil) {
        self.subject = subject
        self.metadata = metadata
        self.thumbnailColors = thumbnailColors
    }
}

/// Data source for swiping between detail views in a UIPageViewController.
///
/// Holds a snapshot of `DetailPageItem`s captured at the moment
/// the user taps a list row. The snapshot approach avoids the crashes
/// that the legacy `PageViewManager` encountered when filters changed
/// while the user was mid-swipe.
@MainActor
final class DetailPagingDataSource: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let items: [DetailPageItem]
    private let playaDB: PlayaDB

    init(items: [DetailPageItem], playaDB: PlayaDB) {
        self.items = items
        self.playaDB = playaDB
        super.init()
    }

    /// Convenience initializer for callers that only have bare subjects (map, deep link).
    convenience init(subjects: [DetailSubject], playaDB: PlayaDB) {
        self.init(items: subjects.map { DetailPageItem(subject: $0) }, playaDB: playaDB)
    }

    /// Creates a `DetailPageViewController` showing the item at `initialIndex`,
    /// with swipe navigation to adjacent items.
    func makePageViewController(initialIndex: Int) -> UIViewController {
        let pageVC = DetailPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )

        let detailVC = makeDetailController(at: initialIndex)
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([detailVC], direction: .forward, animated: false, completion: nil)
        return pageVC
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = currentIndex(of: viewController), index > 0 else { return nil }
        return makeDetailController(at: index - 1)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = currentIndex(of: viewController), index < items.count - 1 else { return nil }
        return makeDetailController(at: index + 1)
    }

    // MARK: - UIPageViewControllerDelegate

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed, let current = pageViewController.viewControllers?.first else { return }
        pageViewController.copyParameters(from: current)
    }

    // MARK: - Private

    private func makeDetailController(at index: Int) -> UIViewController {
        let item = items[index]
        let controller = DetailViewControllerFactory.create(
            with: item.subject,
            playaDB: playaDB,
            preloadedMetadata: item.metadata,
            preloadedColors: item.thumbnailColors
        )
        controller.indexPath = IndexPath(row: index, section: 0)
        return controller
    }

    private func currentIndex(of viewController: UIViewController) -> Int? {
        (viewController as? DetailHostingController)?.indexPath?.row
    }
}
