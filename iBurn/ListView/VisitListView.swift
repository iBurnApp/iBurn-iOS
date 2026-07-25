//
//  VisitListView.swift
//  iBurn
//
//  Created by Claude Code on 7/25/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import UIKit
import PlayaDB

/// SwiftUI view for the Visit List (More → Visit List): everything the user has
/// marked "Want to Visit" or "Visited", across art, camps and events.
struct VisitListView: View {
    @StateObject private var viewModel: VisitListViewModel
    @Environment(\.themeColors) var themeColors

    let onSelectItem: (VisitListItem) -> Void
    let onShowMap: ([PlayaObjectAnnotation]) -> Void

    init(
        viewModel: VisitListViewModel,
        onSelectItem: @escaping (VisitListItem) -> Void = { _ in },
        onShowMap: @escaping ([PlayaObjectAnnotation]) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectItem = onSelectItem
        self.onShowMap = onShowMap
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Picker("Visit Status", selection: $viewModel.selectedFilter) {
                    ForEach(VisitListFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.items) { item in
                                visitRow(for: item)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .searchable(
                    text: $viewModel.searchText,
                    prompt: "Search visit list"
                )
            }
            .navigationTitle("Visit List")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { onShowMap(viewModel.allAnnotations) }) {
                        Image(systemName: "map")
                            .foregroundColor(themeColors.primaryColor)
                    }
                }
            }

            // Loading
            if viewModel.isLoading && viewModel.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading visit list...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
            }

            // Empty state
            if !viewModel.isLoading && viewModel.sections.isEmpty {
                emptyState
            }
        }
        // Visit status has no observation API. A watch sync can apply status changes
        // while the app is backgrounded, so re-fetch when it comes back to the front
        // (the hosting controller covers the appear/detail-screen path).
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh()
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(themeColors.detailColor)

            if !viewModel.searchText.isEmpty {
                Text("No results for \"\(viewModel.searchText)\"")
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)

                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
            } else {
                Text(emptyTitle)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)

                Text("Mark places as \"Want to Visit\" or \"Visited\" from their detail screen and they'll show up here.")
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var emptyTitle: String {
        switch viewModel.selectedFilter {
        case .all: "Nothing on your visit list yet"
        case .wantToVisit: "Nothing marked \"Want to Visit\""
        case .visited: "Nothing marked \"Visited\""
        }
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func visitRow(for item: VisitListItem) -> some View {
        let isFav = viewModel.isFavorite(item)
        let favAction: () -> Void = { Task { await viewModel.toggleFavorite(item) } }
        let distance = viewModel.distanceAttributedString(for: item)

        switch item {
        case .art(let art, _):
            ObjectRowView(
                object: art,
                subtitle: distance,
                rightSubtitle: art.artist,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectItem(item) }

        case .camp(let camp, _):
            ObjectRowView(
                object: camp,
                subtitle: distance,
                rightSubtitle: camp.hometown,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectItem(item) }

        case .event(let event, _):
            ObjectRowView(
                object: event,
                subtitle: distance,
                rightSubtitle: event.timeDescription(now: viewModel.now),
                hostName: event.hostName,
                hostAddress: BRCEmbargo.allowEmbargoedData() ? event.hostAddress : nil,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in
                Text(EventTypeInfo.emoji(for: event.eventTypeCode))
                    .font(.subheadline)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectItem(item) }

        case .mutantVehicle(let mv, _):
            ObjectRowView(
                object: mv,
                subtitle: nil,
                rightSubtitle: mv.artist,
                isFavorite: isFav,
                onFavoriteTap: favAction
            ) { _ in EmptyView() }
            .contentShape(Rectangle())
            .onTapGesture { onSelectItem(item) }
        }
    }
}
