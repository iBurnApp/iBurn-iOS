//
//  AudioTourView.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

/// SwiftUI view for the Audio Tour (More → Audio Tour): every art installation
/// with a recorded audio tour, playable individually or as one queue.
///
/// Layout mirrors the legacy `AudioTourViewController`: a header with the
/// introduction and SoundCloud buttons, a Play All / Pause / Resume item in the
/// navigation bar, and per-row play buttons.
struct AudioTourView: View {
    @StateObject private var viewModel: AudioTourViewModel
    @Environment(\.themeColors) var themeColors

    private let audioPlayer: any AudioPlayerProtocol
    private let onSelect: (ArtObject) -> Void
    private let onOpenSoundCloud: () -> Void

    init(
        viewModel: AudioTourViewModel,
        audioPlayer: any AudioPlayerProtocol = BRCAudioPlayer.sharedInstance,
        onSelect: @escaping (ArtObject) -> Void = { _ in },
        onOpenSoundCloud: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.audioPlayer = audioPlayer
        self.onSelect = onSelect
        self.onOpenSoundCloud = onOpenSoundCloud
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView

                List {
                    ForEach(viewModel.items) { item in
                        row(for: item)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Audio Tour")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(viewModel.playAllTitle) {
                        viewModel.playAll()
                    }
                    .foregroundColor(themeColors.primaryColor)
                    .disabled(viewModel.isEmpty)
                }
            }

            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading audio tour...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            if !viewModel.isLoading && viewModel.isEmpty {
                emptyState
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 8) {
            if viewModel.introTrack != nil {
                Button(viewModel.introTitle) {
                    viewModel.playIntro()
                }
                .font(.body)
                .foregroundColor(themeColors.primaryColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Button("Open in SoundCloud") {
                onOpenSoundCloud()
            }
            .font(.body)
            .foregroundColor(themeColors.primaryColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding(.horizontal)
        .padding(.top, 8)

        Divider()
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 64))
                .foregroundColor(themeColors.detailColor)

            Text("No audio tour yet")
                .font(.headline)
                .foregroundColor(themeColors.primaryColor)

            Text("Audio tour content arrives later in the season. Check back after a data update — the recordings show up here automatically.")
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: AudioTourItem) -> some View {
        ObjectRowView(
            object: item.art,
            subtitle: viewModel.distanceAttributedString(for: item),
            rightSubtitle: item.art.artist,
            isFavorite: item.isFavorite,
            thumbnailColors: item.row.thumbnailColors,
            onFavoriteTap: {
                Task { await viewModel.toggleFavorite(item) }
            }
        ) { _ in
            // The track comes from the view model rather than the row's local asset
            // loader, so art whose audio lives at a remote URL still gets a button.
            AudioTourButton(track: item.track, audioPlayer: audioPlayer)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(item.art)
        }
    }
}
