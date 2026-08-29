//
//  GlobalSearchTabFactory.swift
//  iBurn
//
//  Created by Claude Code on 8/6/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Builds the root view controller for the `UISearchTab` prototype. A `UISearchTab`
//  expects its view controller to own a `UISearchController` on its navigation item —
//  that's what UIKit morphs the tab bar into when the search tab is selected. Results
//  render inline (`searchResultsController: nil`) rather than in a separate results
//  controller, so the list is visible the whole time the field is focused.
//
//  This is an ordinary opaque screen, not an overlay. It once painted a still of the map
//  behind a transparent results view, which looked right arriving from the Map tab and
//  plainly wrong arriving from anywhere else — you'd tap Search from Events and get a
//  frozen map. `GlobalSearchView`'s empty states carry the screen instead.
//

import UIKit

@MainActor
enum GlobalSearchTabFactory {

    /// Retains the search-results updater for the lifetime of the returned controller;
    /// `UISearchController.searchResultsUpdater` is a weak reference.
    ///
    /// It doubles as the search controller's delegate, because activation is the only
    /// event that says "the tab bar has become a search field": selecting the search tab
    /// re-lays out nothing on the tab bar controller, so its own layout callbacks never
    /// see the change.
    private final class Updater: NSObject, UISearchResultsUpdating, UISearchControllerDelegate {
        private weak var host: GlobalSearchHostingController?
        private let activationDidChange: (Bool) -> Void

        init(host: GlobalSearchHostingController, activationDidChange: @escaping (Bool) -> Void) {
            self.host = host
            self.activationDidChange = activationDidChange
        }

        func updateSearchResults(for searchController: UISearchController) {
            host?.viewModel.searchText = searchController.searchBar.text ?? ""
        }

        func willPresentSearchController(_ searchController: UISearchController) {
            activationDidChange(true)
        }

        func willDismissSearchController(_ searchController: UISearchController) {
            activationDidChange(false)
        }
    }

    private static var updaterKey: UInt8 = 0

    /// - Parameter searchActivationDidChange: Called as the search field takes over the
    ///   tab bar and hands it back, so chrome anchored to the bar can get out of the way.
    static func makeSearchTabRoot(
        dependencies: DependencyContainer,
        searchActivationDidChange: @escaping (Bool) -> Void = { _ in }
    ) -> UIViewController {
        let host = dependencies.makeGlobalSearchHostingController()
        host.title = NSLocalizedString("Search", comment: "title for the search tab")

        let updater = Updater(host: host, activationDidChange: searchActivationDidChange)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = updater
        searchController.delegate = updater
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString(
            "Search art, camps, and events",
            comment: "placeholder for the global search field"
        )
        // `UISearchTab.automaticallyActivatesSearch` makes this screen arrive with search
        // already active, and an active search controller hides the navigation bar by
        // default — which took the title and the filter button with it and left a tall
        // empty band where the bar had been. The field is docked at the bottom in this
        // layout, so there's nothing for the navigation bar to collide with.
        searchController.hidesNavigationBarDuringPresentation = false

        // searchResultsUpdater is weak, so pin the updater's lifetime to the host.
        objc_setAssociatedObject(host, &updaterKey, updater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        host.navigationItem.searchController = searchController
        host.navigationItem.hidesSearchBarWhenScrolling = false
        host.navigationItem.largeTitleDisplayMode = .never
        // This is the one layout with a navigation bar of its own, so the filter control
        // goes there — same place Art, Camps and Events keep theirs — and out of the
        // scope bar, which keeps the segmented control full width.
        host.installFilterBarButtonItem()

        return NavigationController(rootViewController: host)
    }
}
