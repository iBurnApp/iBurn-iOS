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
//  The pieces are assembled here; `SearchTabRootViewController` is the view controller
//  that actually shows up in the tab.
//

import UIKit

@MainActor
enum GlobalSearchTabFactory {

    /// Retains the search-results updater for the lifetime of the returned controller;
    /// `UISearchController.searchResultsUpdater` is a weak reference.
    private final class Updater: NSObject, UISearchResultsUpdating {
        private weak var host: GlobalSearchHostingController?

        init(host: GlobalSearchHostingController) {
            self.host = host
        }

        func updateSearchResults(for searchController: UISearchController) {
            host?.viewModel.searchText = searchController.searchBar.text ?? ""
        }
    }

    private static var updaterKey: UInt8 = 0

    static func makeSearchTabRoot(dependencies: DependencyContainer) -> UIViewController {
        let host = dependencies.makeGlobalSearchHostingController()
        host.isOverlay = true
        let root = SearchTabRootViewController(content: host)

        let updater = Updater(host: host)
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = updater
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = NSLocalizedString(
            "Search art, camps, and events",
            comment: "placeholder for the global search field"
        )

        // searchResultsUpdater is weak, so pin the updater's lifetime to the host.
        objc_setAssociatedObject(host, &updaterKey, updater, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // The search controller hangs off the root, not the hosting controller, because
        // that's the view controller UIKit reads the navigation item from.
        root.navigationItem.searchController = searchController
        root.navigationItem.hidesSearchBarWhenScrolling = false

        let nav = NavigationController(rootViewController: root)
        // The overlay only reads as an overlay if every layer above the backdrop is
        // clear — the nav controller paints its own fill otherwise.
        nav.view.backgroundColor = .clear
        return nav
    }
}
