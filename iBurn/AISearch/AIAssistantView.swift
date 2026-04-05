//
//  AIAssistantView.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import SwiftUI
import PlayaDB

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
                    aiItemRow(uid: rec.uid, reason: rec.reason)
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
                            HStack(alignment: .top, spacing: 12) {
                                Text(item.startTime)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeColors.detailColor)
                                    .frame(width: 60, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let resolved = viewModel.resolvedObjects[item.uid] {
                                        Text(resolved.name)
                                            .font(.headline)
                                            .foregroundColor(themeColors.primaryColor)
                                    } else {
                                        Text(item.uid)
                                            .font(.headline)
                                            .foregroundColor(themeColors.primaryColor)
                                    }
                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundColor(themeColors.secondaryColor)
                                }
                            }
                            .padding(.vertical, 4)
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
                    aiItemRow(uid: highlight.uid, reason: highlight.reason)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Shared Components

    private func aiItemRow(uid: String, reason: String) -> some View {
        HStack(spacing: 12) {
            if let resolved = viewModel.resolvedObjects[uid] {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(typeEmoji(resolved.objectType))
                        Text(resolved.name)
                            .font(.headline)
                            .foregroundColor(themeColors.primaryColor)
                            .lineLimit(1)
                    }
                    if let subtitle = resolved.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(themeColors.detailColor)
                            .lineLimit(1)
                    }
                    Text(reason)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                        .lineLimit(2)
                }
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
            Spacer(minLength: 0)
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundStyle(.purple)
        }
        .padding(.vertical, 4)
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

    private func typeEmoji(_ type: DataObjectType) -> String {
        switch type {
        case .art: return "🎨"
        case .camp: return "⛺"
        case .event: return "📅"
        case .mutantVehicle: return "🚗"
        }
    }
}
