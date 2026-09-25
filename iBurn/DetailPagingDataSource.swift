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
///
/// Controllers are cached (weakly) by index, so repeated before/after
/// requests for the same neighbour return the same instance. UIKit can ask
/// for a neighbour again during a relayout mid-scroll; handing it a fresh
/// controller at that point leaves the scroll view with a visible page whose
/// controller the page view controller no longer manages, which raises
/// "No view controller managing visible view".
@MainActor
final class DetailPagingDataSource: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let items: [DetailPageItem]
    private let playaDB: PlayaDB

    /// index -> controller. Weak values: the page view controller owns
    /// the controllers it is showing or scrolling to; the rest can go.
    private let controllersByIndex = NSMapTable<NSNumber, UIViewController>.strongToWeakObjects()
    /// controller -> index, so lookups don't depend on the controller type.
    private let indexesByController = NSMapTable<UIViewController, NSNumber>.weakToStrongObjects()

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

        pageVC.dataSource = self
        pageVC.delegate = self
        if let detailVC = controller(at: initialIndex, for: pageVC) {
            pageVC.setViewControllers([detailVC], direction: .forward, animated: false, completion: nil)
        }
        return pageVC
    }

    /// Returns the cached controller for `index`, creating it if needed.
    /// `nil` when `index` is out of range.
    func controller(at index: Int, for pageViewController: UIPageViewController? = nil) -> UIViewController? {
        guard items.indices.contains(index) else { return nil }
        let key = NSNumber(value: index)
        let controller: UIViewController
        if let cached = controllersByIndex.object(forKey: key) {
            controller = cached
        } else {
            controller = makeDetailController(at: index)
            controllersByIndex.setObject(controller, forKey: key)
            indexesByController.setObject(key, forKey: controller)
        }
        // Every page gets the container as its event handler, not just the
        // one placed with setViewControllers.
        if let handler = pageViewController as? DynamicViewControllerEventHandler,
           let dynamic = controller as? DynamicViewController {
            dynamic.eventHandler = handler
        }
        return controller
    }

    /// The snapshot index of a controller vended by this data source.
    func index(of viewController: UIViewController) -> Int? {
        if let index = indexesByController.object(forKey: viewController) {
            return index.intValue
        }
        return (viewController as? DetailHostingController)?.indexPath?.row
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let index = index(of: viewController) else { return nil }
        return controller(at: index - 1, for: pageViewController)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let index = index(of: viewController) else { return nil }
        return controller(at: index + 1, for: pageViewController)
    }

    // MARK: - UIPageViewControllerDelegate

    func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]
    ) {
        (pageViewController as? DetailPageViewController)?.pageTransitionWillBegin()
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        if let detailPageVC = pageViewController as? DetailPageViewController {
            // Defers the nav-bar update until the scroll has fully settled
            // (and the app is in the foreground).
            detailPageVC.pageTransitionDidEnd(completed: completed)
        } else if completed, let current = pageViewController.viewControllers?.first {
            pageViewController.copyParameters(from: current)
        }
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
}
