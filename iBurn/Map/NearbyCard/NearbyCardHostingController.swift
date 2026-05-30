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
        self.rootView = NearbyCardView(
            viewModel: vm,
            onSelect: { [weak self] subject in
                self?.showDetail(subject)
            }
        )
        // The hosting view should only occupy (and intercept touches over) the card/FAB,
        // leaving the rest of the map interactive. Clear background + intrinsic sizing.
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) {
            sizingOptions = [.intrinsicContentSize]
        }
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
}
