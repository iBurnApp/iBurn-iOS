//
//  SearchTabRootViewController.swift
//  iBurn
//
//  Created by Claude Code on 8/7/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Root of the `UISearchTab`. Two jobs:
//
//  1. Own the `UISearchController` on its navigation item — that's the one UIKit morphs
//     the tab bar into when the search tab is selected.
//  2. Paint the map behind the results, so search reads as a layer over the map instead of
//     a separate white screen. See `MapBackdropStore` for why that's a still image.
//

import UIKit

@MainActor
final class SearchTabRootViewController: UIViewController {

    private let backdrop = UIImageView()
    private let content: GlobalSearchHostingController

    init(content: GlobalSearchHostingController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Search", comment: "title for the search tab")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        backdrop.contentMode = .scaleAspectFill
        backdrop.clipsToBounds = true
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        addChild(content)
        let contentView = content.view!
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            // Ignores the safe area on purpose: the captured frame covers the whole
            // screen, so anything less would show a seam under the status bar.
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        content.didMove(toParent: self)
    }

    // Refreshed in both callbacks because the order of the outgoing tab's
    // `viewWillDisappear` against this one's `viewWillAppear` isn't guaranteed — whichever
    // lands second gets the fresh capture, and the other keeps the previous frame rather
    // than flashing empty.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshBackdrop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshBackdrop()
    }

    private func refreshBackdrop() {
        backdrop.image = MapBackdropStore.shared.image
    }
}
