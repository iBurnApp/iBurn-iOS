//
//  DetailPageViewController.swift
//  iBurn
//
//  Created by Claude Code on 7/13/25.
//  Copyright (c) 2025 Burning Man Earth. All rights reserved.
//

import UIKit

/// Custom UIPageViewController that forwards navigation items from its
/// `DetailHostingController` children to its own navigation item.
///
/// Navigation-item forwarding (`copyParameters`) changes the title and bar
/// items and adds a CATransition to the navigation bar, which relayouts the
/// bar and this controller. Doing that while a swipe is still settling, or
/// while the app is in the background, can leave UIPageViewController's scroll
/// view with a visible page it no longer manages ("No view controller managing
/// visible view"). So updates are deferred while a page transition is in
/// flight or the scene is backgrounded, and applied once it's safe.
class DetailPageViewController: UIPageViewController {

    // MARK: - Properties

    /// A navigation-item update is pending.
    private(set) var needsNavigationUpdate = false

    /// A user-driven page transition is in flight (between the delegate's
    /// `willTransitionTo` and `didFinishAnimating`).
    private(set) var isPageTransitionInProgress = false

    // MARK: - Lifecycle

    override init(
        transitionStyle style: UIPageViewController.TransitionStyle,
        navigationOrientation: UIPageViewController.NavigationOrientation,
        options: [UIPageViewController.OptionsKey: Any]? = nil
    ) {
        super.init(transitionStyle: style, navigationOrientation: navigationOrientation, options: options)
        observeForeground()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observeForeground()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupEventHandlerForCurrentChild()
        setNeedsNavigationUpdate()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyNavigationUpdateIfPossible()
    }

    override func setViewControllers(_ viewControllers: [UIViewController]?, direction: UIPageViewController.NavigationDirection, animated: Bool, completion: ((Bool) -> Void)?) {
        super.setViewControllers(viewControllers, direction: direction, animated: animated) { [weak self] completed in
            if completed, let self {
                self.isPageTransitionInProgress = false
                self.setupEventHandlerForCurrentChild()
                self.setNeedsNavigationUpdate()
                self.scheduleNavigationUpdateIfNeeded()
            }
            completion?(completed)
        }
    }

    // MARK: - Page transitions (driven by the delegate)

    /// Call from `pageViewController(_:willTransitionTo:)`.
    func pageTransitionWillBegin() {
        isPageTransitionInProgress = true
    }

    /// Call from `pageViewController(_:didFinishAnimating:previousViewControllers:transitionCompleted:)`.
    func pageTransitionDidEnd(completed: Bool) {
        isPageTransitionInProgress = false
        if completed {
            setupEventHandlerForCurrentChild()
            setNeedsNavigationUpdate()
        }
        // Apply on the next run loop turn, after UIKit has finished
        // settling the scroll view.
        scheduleNavigationUpdateIfNeeded()
    }

    // MARK: - Navigation updates

    private func observeForeground() {
        // Selector-based observers are removed automatically on dealloc.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func sceneWillEnterForeground() {
        scheduleNavigationUpdateIfNeeded()
    }

    /// Whether it's safe to mutate the navigation bar right now.
    var canUpdateNavigation: Bool {
        guard !isPageTransitionInProgress else { return false }
        if let scene = view.window?.windowScene {
            return scene.activationState != .background
        }
        return UIApplication.shared.applicationState != .background
    }

    private func setNeedsNavigationUpdate() {
        needsNavigationUpdate = true
    }

    private func scheduleNavigationUpdateIfNeeded() {
        guard needsNavigationUpdate else { return }
        DispatchQueue.main.async { [weak self] in
            self?.applyNavigationUpdateIfPossible()
        }
    }

    private func applyNavigationUpdateIfPossible() {
        guard needsNavigationUpdate, canUpdateNavigation,
              let currentChild = viewControllers?.first else { return }
        needsNavigationUpdate = false
        // Generic navigation item forwarding - works with any UIViewController
        copyParameters(from: currentChild)
    }

    private func setupEventHandlerForCurrentChild() {
        guard let dynamicVC = viewControllers?.first as? DynamicViewController else { return }
        dynamicVC.eventHandler = self
    }
}

// MARK: - DynamicViewControllerEventHandler

extension DetailPageViewController: DynamicViewControllerEventHandler {
    func viewControllerDidTriggerEvent(_ event: ViewControllerEvent, sender: UIViewController) {
        // Neighbouring pages lay out too; only the visible page drives the bar.
        guard sender === viewControllers?.first else { return }

        switch event {
        case .viewWillLayoutSubviews, .navigationItemDidChange, .toolbarDidChange:
            // Applied on the next layout pass (or once the transition ends).
            setNeedsNavigationUpdate()

        case .viewDidAppear:
            setNeedsNavigationUpdate()
            applyNavigationUpdateIfPossible()

        case .viewWillDisappear:
            break
        }
    }
}
