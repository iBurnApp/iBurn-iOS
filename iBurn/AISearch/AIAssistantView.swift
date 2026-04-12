//
//  AIAssistantView.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB
import UIKit

struct AIAssistantView: View {
    @ObservedObject var viewModel: AIAssistantViewModel
    @Environment(\.themeColors) var themeColors

    var body: some View {
        VStack(spacing: 0) {
            // Feature picker
            Picker("Feature", selection: $viewModel.selectedFeature) {
                ForEach(AIAssistantViewModel.Feature.allCases) { feature in
                    Text(feature.rawValue).tag(feature)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: viewModel.selectedFeature) { _ in
                viewModel.loadCurrentFeature()
            }

            // Content
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("AI is exploring the playa...")
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                }
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(themeColors.secondaryColor)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        viewModel.loadCurrentFeature()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                Spacer()
            } else {
                featureContent
            }
        }
    }

    @ViewBuilder
    private var featureContent: some View {
        switch viewModel.selectedFeature {
        case .forYou:
            recommendationsList
        case .dayPlan:
            dayPlanView
        case .nearby:
            nearbyList
        }
    }

    // MARK: - For You

    private var recommendationsList: some View {
        Group {
            if viewModel.recommendations.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "Personalized Recommendations",
                    subtitle: "Favorite some art, camps, or events first, then AI will suggest similar things you might enjoy."
                )
            } else {
                List(viewModel.recommendations) { rec in
                    objectRow(uid: rec.uid, reason: rec.reason)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Day Plan

    private var dayPlanView: some View {
        Group {
            if let plan = viewModel.dayPlan, !plan.schedule.isEmpty {
                List {
                    if !plan.summary.isEmpty {
                        Section {
                            Text(plan.summary)
                                .font(.subheadline)
                                .foregroundColor(themeColors.secondaryColor)
                        }
                    }
                    Section(header: Text("Schedule")) {
                        ForEach(plan.schedule) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.startTime)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeColors.detailColor)
                                objectRow(uid: item.uid, reason: item.reason)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                emptyState(
                    icon: "calendar.badge.clock",
                    title: "AI Day Planner",
                    subtitle: "Get a personalized schedule based on your interests and what's happening today."
                )
            }
        }
    }

    // MARK: - Nearby

    private var nearbyList: some View {
        Group {
            if viewModel.nearbyHighlights.isEmpty {
                emptyState(
                    icon: "location.circle",
                    title: "What's Nearby",
                    subtitle: "Discover interesting art, camps, and events near your current location."
                )
            } else {
                List(viewModel.nearbyHighlights) { highlight in
                    objectRow(uid: highlight.uid, reason: highlight.reason)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func objectRow(uid: String, reason: String) -> some View {
        if let resolved = viewModel.resolvedObjects[uid] {
            Button {
                navigateToDetail(uid: uid)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    resolvedRow(uid: uid, resolved: resolved)
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text(reason)
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryColor)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(uid)
                    .font(.headline)
                    .foregroundColor(themeColors.primaryColor)
                Text(reason)
                    .font(.caption)
                    .foregroundColor(themeColors.secondaryColor)
            }
        }
    }

    @ViewBuilder
    private func resolvedRow(uid: String, resolved: AIAssistantViewModel.ResolvedObject) -> some View {
        let isFavorite = viewModel.favoriteIDs.contains(uid)
        let onFavoriteTap: () -> Void = { Task { await viewModel.toggleFavorite(uid) } }
        switch resolved {
        case .art(let art):
            ObjectRowView(
                object: art,
                subtitle: nil,
                rightSubtitle: art.artist,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .camp(let camp):
            ObjectRowView(
                object: camp,
                subtitle: nil,
                rightSubtitle: camp.hometown,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .event(let event):
            ObjectRowView(
                object: event,
                subtitle: nil,
                rightSubtitle: event.eventTypeLabel,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .mutantVehicle(let mv):
            ObjectRowView(
                object: mv,
                subtitle: nil,
                rightSubtitle: mv.artist,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        }
    }

    private func navigateToDetail(uid: String) {
        guard let resolved = viewModel.resolvedObjects[uid] else { return }
        let playaDB = viewModel.playaDB
        let detailVC: UIViewController
        switch resolved {
        case .art(let art):
            detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
        case .camp(let camp):
            detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        case .event(let event):
            detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        case .mutantVehicle(let mv):
            detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let navController = window.rootViewController?.findNavigationController() else {
            return
        }
        navController.pushViewController(detailVC, animated: true)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(themeColors.detailColor)
            Text(title)
                .font(.headline)
                .foregroundColor(themeColors.primaryColor)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
                .multilineTextAlignment(.center)
            Button("Generate") {
                viewModel.loadCurrentFeature()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

}
