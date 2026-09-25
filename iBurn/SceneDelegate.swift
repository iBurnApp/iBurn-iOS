//
//  SceneDelegate.swift
//  iBurn
//
//  Created by Claude Code on 9/24/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import CocoaLumberjack
import UIKit

/// Owns the app's window and everything scene-scoped: the root view controller (onboarding
/// or the tab controller), foreground activation, and incoming URLs / universal links.
///
/// Apps built against the iOS 27 SDK must adopt the UIScene lifecycle, so this took over the
/// window half of `BRCAppDelegate`. App-wide work — Firebase, notifications, background
/// tasks, the shared location manager, data updates — stays in the app delegate.
///
/// Registered in `iBurn-Info.plist` under `UIApplicationSceneManifest`. The explicit ObjC
/// name keeps that plist entry independent of the Swift module name.
@objc(SceneDelegate)
final class SceneDelegate: UIResponder, UIWindowSceneDelegate, UINavigationControllerDelegate {

    var window: UIWindow?

    /// The root tab controller, once onboarding is done (or was already done at launch).
    private(set) var tabController: TabController?
    private(set) var mapViewController: MainMapViewController?

    /// The same delay the app delegate used for launch URLs: lets the root view controller
    /// finish appearing before the router pushes or presents on it.
    private static let coldLaunchLinkDelay: TimeInterval = 0.5

    private var appDelegate: BRCAppDelegate { BRCAppDelegate.shared }

    /// App Store review prompt (was Appirater in the app delegate).
    private let reviewPolicy = ReviewPromptFactory.makePolicy()
    private let reviewRequester = ReviewPromptFactory.makeRequester()

    /// Lets launch finish (and any launch alert appear) before a review prompt is considered.
    private static let reviewPromptDelay: TimeInterval = 2

    // MARK: - Connection

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        self.window = window

        // Show onboarding.. or not
        if UserDefaults.standard.hasViewedOnboarding() {
            setupNormalRootViewController()
        } else {
            window.rootViewController = BRCOnboardingViewController { [weak self] in
                guard let self, let window = self.window else { return }
                UIView.transition(
                    with: window,
                    duration: 1.0,
                    options: .transitionCrossDissolve,
                    animations: { self.handleOnboardingCompletion() }
                )
            }
        }

        window.makeKeyAndVisible()

        // One scene per launch (UIApplicationSupportsMultipleScenes is off), so this counts
        // launches the way Appirater's `appLaunched:` did.
        reviewPolicy.recordUse(now: Date())

        handleColdLaunchLinks(connectionOptions)
    }

    // MARK: - Activation

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Was `applicationDidBecomeActive:`, which UIKit no longer calls once scenes are
        // adopted. `UIApplication.didBecomeActiveNotification` still posts (map, embargo
        // scheduler, event refresh observe it), so only the delegate callback moved.
        appDelegate.startLocationUpdatesIfAuthorized()

        if let windowScene = scene as? UIWindowScene {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.reviewPromptDelay) { [weak self, weak windowScene] in
                guard let self, let windowScene else { return }
                self.requestReviewIfAppropriate(in: windowScene)
            }
        }
    }

    // MARK: - Review prompt

    /// Asks StoreKit for a review once the policy allows it, but only on the main tabs with
    /// nothing presented over them: never during onboarding or on top of an alert.
    private func requestReviewIfAppropriate(in windowScene: UIWindowScene) {
        guard windowScene.activationState == .foregroundActive,
              UserDefaults.standard.hasViewedOnboarding(),
              let tabController,
              window?.rootViewController === tabController,
              tabController.presentedViewController == nil else {
            return
        }
        let now = Date()
        guard reviewPolicy.shouldRequestReview(now: now) else { return }
        reviewPolicy.recordReviewRequested(now: now)
        reviewRequester.requestReview(in: windowScene)
    }

    // MARK: - Deep links

    /// Was `application:openURL:options:` — custom-scheme (`iburn://`) links while running.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handle(url: context.url)
        }
    }

    /// Was `application:continueUserActivity:restorationHandler:` — universal links
    /// (`https://iburnapp.com/...`) while running.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = Self.webpageURL(from: userActivity) else { return }
        handle(url: url)
    }

    /// Under scenes, a link that launches the app arrives in the connection options instead
    /// of `launchOptions` / the app delegate callbacks.
    private func handleColdLaunchLinks(_ connectionOptions: UIScene.ConnectionOptions) {
        let urls = connectionOptions.urlContexts.map(\.url)
            + connectionOptions.userActivities.compactMap(Self.webpageURL(from:))
        guard !urls.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.coldLaunchLinkDelay) { [weak self] in
            urls.forEach { self?.handle(url: $0) }
        }
    }

    private func handle(url: URL) {
        if !BRCDeepLinkRouter.shared.handleURL(url) {
            DDLogWarn("Failed to handle URL: \(url)")
        }
    }

    private static func webpageURL(from userActivity: NSUserActivity) -> URL? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else { return nil }
        return userActivity.webpageURL
    }

    // MARK: - Root view controller

    private func setupDefaultTabBarController() -> TabController {
        let mapViewController = MainMapViewController()
        self.mapViewController = mapViewController
        let mapNavController = NavigationController(rootViewController: mapViewController)
        mapNavController.tabBarItem.image = UIImage(named: "BRCMapIcon")

        let nearbyNav = NavigationController(rootViewController: appDelegate.createNearbyViewController())
        nearbyNav.tabBarItem.image = UIImage(named: "BRCCompassIcon")

        let favoritesNavController = NavigationController(rootViewController: appDelegate.createFavoritesViewController())
        favoritesNavController.tabBarItem.image = UIImage(named: "BRCHeartIcon")
        favoritesNavController.tabBarItem.selectedImage = UIImage(named: "BRCHeartFilledIcon")

        let eventsVC = appDelegate.createEventsViewController()
        eventsVC.title = "Events"
        let eventsNavController = NavigationController(rootViewController: eventsVC)
        eventsNavController.tabBarItem.image = UIImage(named: "BRCEventIcon")

        let moreViewController = MoreViewController()
        moreViewController.title = "More"
        let moreNavController = NavigationController(rootViewController: moreViewController)
        moreNavController.tabBarItem.image = UIImage(named: "BRCMoreIcon")

        let tabController = TabController()
        tabController.configure(withRootViewControllers: [
            mapNavController, nearbyNav, favoritesNavController, eventsNavController, moreNavController,
        ])
        tabController.moreNavigationController.delegate = self
        return tabController
    }

    private func setupNormalRootViewController() {
        let tabController = setupDefaultTabBarController()
        self.tabController = tabController
        window?.rootViewController = tabController

        // Configure deep link router
        BRCDeepLinkRouter.shared.configure(withTabController: tabController)

        // do it again just in case
        BRCAppDelegate.registerForRemoteNotifications()
        appDelegate.requestLocationPermission()

        // Show informational alert about embargo if needed
        if !BRCEmbargo.allowEmbargoedData() {
            let alert = UIAlertController(
                title: "Locations Are Hidden",
                message: "Camp location data is restricted until one week before gates open, and art location data is restricted until the event starts. This is due to an embargo imposed by the Burning Man organization.\n\nThe app unlocks itself once you're on playa and those dates have passed. Until you arrive, locations stay hidden unless you enter the embargo passcode.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Ok cool whatever", style: .default))
            tabController.present(alert, animated: true)
        }
    }

    private func handleOnboardingCompletion() {
        UserDefaults.standard.setHasViewedOnboarding(true)
        setupNormalRootViewController()
    }

    // MARK: - UINavigationControllerDelegate

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // Remove "Edit" from More tab
        navigationController.navigationBar.topItem?.rightBarButtonItem = nil
    }
}
