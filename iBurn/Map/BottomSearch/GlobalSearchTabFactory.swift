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
//  render inline in the hosting controller rather than in a separate results
//  controller, so the list is visible the whole time the field is focused.
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
        host.title = NSLocalizedString("Search", comment: "title for the search tab")

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

        host.navigationItem.searchController = searchController
        host.navigationItem.hidesSearchBarWhenScrolling = false

        return NavigationController(rootViewController: host)
    }
}
