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

    /// Where the card is actually drawing inside `bounds` — the whole box when expanded,
    /// just the centered pin when collapsed, nothing when there's nothing nearby. Drives
    /// `NearbyCardTouchContainer`; see that file for why UIKit has to decide this.
    func interactiveRect(in bounds: CGRect) -> CGRect {
        guard !viewModel.items.isEmpty else { return .zero }
        guard viewModel.isMinimized else { return bounds }

        let diameter = NearbyCardView.fabDiameter
        return CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
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
