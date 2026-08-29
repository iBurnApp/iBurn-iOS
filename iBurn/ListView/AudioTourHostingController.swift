//
//  AudioTourHostingController.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import UIKit
import PlayaDB

/// UIKit hosting controller that wraps the SwiftUI `AudioTourView`.
///
/// PlayaDB-backed replacement for the Yap-backed `AudioTourViewController`
/// (kept as the `useSwiftUILists` kill-switch fallback). Bridges the two bits of
/// navigation the SwiftUI screen can't do itself: pushing the paged detail screen
/// and presenting the SoundCloud web view.
@MainActor
class AudioTourHostingController: UIHostingController<AudioTourView> {
    private let playaDB: PlayaDB
    private let viewModel: AudioTourViewModel
    private var pagingDataSource: DetailPagingDataSource?

    init(dependencies: DependencyContainer) {
        self.playaDB = dependencies.playaDB
        self.viewModel = AudioTourViewModel(
            artProvider: dependencies.artDataProvider,
            locationProvider: dependencies.locationProvider
        )
        super.init(rootView: AudioTourView(viewModel: viewModel))
        self.rootView = makeRootView()
        self.title = "Audio Tour"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeRootView() -> AudioTourView {
        AudioTourView(
            viewModel: viewModel,
            onSelect: { [weak self] art in
                self?.showDetail(for: art)
            },
            onOpenSoundCloud: { [weak self] in
                self?.showSoundCloud()
            }
        )
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Playback can start/stop from the detail screen, the lock screen or another
        // list while this screen is off-screen; the notification observer covers the
        // live case, this covers anything missed.
        viewModel.refreshPlaybackState()
    }

    // MARK: - Navigation

    private func showDetail(for art: ArtObject) {
        let items = viewModel.items
        let pageItems = items.map { item in
            DetailPageItem(
                subject: .art(item.art),
                metadata: item.row.metadata,
                thumbnailColors: item.row.thumbnailColors
            )
        }
        guard let index = items.firstIndex(where: { $0.art.uid == art.uid }) else { return }
        let dataSource = DetailPagingDataSource(items: pageItems, playaDB: playaDB)
        self.pagingDataSource = dataSource
        let pageVC = dataSource.makePageViewController(initialIndex: index)
        navigationController?.pushViewController(pageVC, animated: true)
    }

    /// Same destination and presentation as the legacy screen's SoundCloud button.
    private func showSoundCloud() {
        guard let url = AudioTourViewModel.soundCloudURL else { return }
        WebViewHelper.presentWebView(url: url, from: self)
    }
}
