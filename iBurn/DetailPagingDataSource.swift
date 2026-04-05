import UIKit
import PlayaDB

/// Data source for swiping between detail views in a UIPageViewController.
///
/// Holds a snapshot of `DetailSubject` items captured at the moment
/// the user taps a list row. The snapshot approach avoids the crashes
/// that the legacy `PageViewManager` encountered when filters changed
/// while the user was mid-swipe.
@MainActor
final class DetailPagingDataSource: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let subjects: [DetailSubject]
    private let playaDB: PlayaDB

    init(subjects: [DetailSubject], playaDB: PlayaDB) {
        self.subjects = subjects
        self.playaDB = playaDB
        super.init()
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
        guard let index = currentIndex(of: viewController), index < subjects.count - 1 else { return nil }
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
        let controller = DetailViewControllerFactory.create(with: subjects[index], playaDB: playaDB)
        controller.indexPath = IndexPath(row: index, section: 0)
        return controller
    }

    private func currentIndex(of viewController: UIViewController) -> Int? {
        (viewController as? DetailHostingController)?.indexPath?.row
    }
}
