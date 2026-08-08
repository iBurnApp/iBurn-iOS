//
//  NearbyCardHostingController.swift
//  iBurn
//
//  Created by Claude Code on 5/30/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  Hosts `NearbyCardView` so it can be embedded as a child view controller of the
//  main map (added via addChild/didMove, not by extracting the inner UIView). Owns
//  the view model and pushes detail views on tap through the map's navigation stack.
//

import SwiftUI
import UIKit
import PlayaDB

@MainActor
final class NearbyCardHostingController: UIHostingController<NearbyCardView> {
    private let playaDB: PlayaDB
    let viewModel: NearbyCardViewModel

    /// Shows the card's link into the full Nearby list. Set when the search tab has taken
    /// Nearby's slot in the tab bar, which makes the card its only entry point.
    var showsNearbyListLink: Bool = false {
        didSet {
            guard oldValue != showsNearbyListLink else { return }
            updateRootView()
        }
    }

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        let vm = dependencies.makeNearbyCardViewModel()
        self.viewModel = vm
        super.init(rootView: NearbyCardView(viewModel: vm))
        updateRootView()
        // The hosting view should only occupy (and intercept touches over) the card/FAB,
        // leaving the rest of the map interactive. Clear background + intrinsic sizing.
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) {
            sizingOptions = [.intrinsicContentSize]
        }
    }

    private func updateRootView() {
        rootView = NearbyCardView(
            viewModel: viewModel,
            showsNearbyListLink: showsNearbyListLink,
            onSelect: { [weak self] subject in
                self?.showDetail(subject)
            },
            onShowNearbyList: { [weak self] in
                self?.showNearbyList()
            }
        )
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    private func showDetail(_ subject: DetailSubject) {
        let detailVC = DetailViewControllerFactory.create(with: subject, playaDB: playaDB)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    /// Pushes the same Nearby screen the tab used to host, built through the app's own
    /// factory so it still honors the SwiftUI-lists feature flag.
    private func showNearbyList() {
        let nearbyVC = BRCAppDelegate.shared.createNearbyViewController()
        navigationController?.pushViewController(nearbyVC, animated: true)
    }
}
