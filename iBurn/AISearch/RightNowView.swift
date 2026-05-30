//
//  RightNowView.swift
//  iBurn
//
//  The single AI Guide screen: ask what you're in the mood for (free text or a
//  suggestion chip), pick a time-of-day and place, and get "Now near you" + "Next."
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import SwiftUI
import PlayaDB
import UIKit

@available(iOS 26, *)
struct RightNowView: View {
    @ObservedObject var viewModel: RightNowViewModel
    let onNavigateToDetail: (UIViewController) -> Void
    @Environment(\.themeColors) var themeColors
    @FocusState private var isTextFieldFocused: Bool
    @State private var showAreaPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                askField
                chipRow
                filterBar
                goButton

                if viewModel.isRunning, !viewModel.steps.isEmpty {
                    progressSection
                }
                if case .failed(let message) = viewModel.executionState {
                    errorView(message)
                }
                if let result = viewModel.result {
                    resultSection(result)
                }
            }
            .padding()
        }
        .onTapGesture { isTextFieldFocused = false }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showAreaPicker) {
            AreaPickerView(
                onUseArea: { region in
                    viewModel.place = .area(region)
                    showAreaPicker = false
                },
                onCancel: { showAreaPicker = false }
            )
        }
    }

    // MARK: - Ask Field

    private var askField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What are you in the mood for?")
                .font(.headline)
                .foregroundColor(themeColors.primaryColor)
            TextField("coffee, fire art, live music…", text: $viewModel.queryText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    isTextFieldFocused = false
                    viewModel.go()
                }
        }
    }

    // MARK: - Suggestion Chips

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SuggestionChip.all) { chip in
                    Button {
                        isTextFieldFocused = false
                        viewModel.selectChip(chip)
                    } label: {
                        Label(chip.label, systemImage: chip.icon)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    viewModel.selectedChipID == chip.id
                                        ? themeColors.detailColor
                                        : Color(.systemGray5)
                                )
                            )
                            .foregroundColor(
                                viewModel.selectedChipID == chip.id ? .white : themeColors.primaryColor
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isRunning)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Filter Bar (time-of-day + place)

    private var filterBar: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(TimeOfDay.allCases) { option in
                    Button {
                        viewModel.timeOfDay = option
                    } label: {
                        Label(option.label, systemImage: option.icon)
                    }
                }
            } label: {
                filterChip(icon: viewModel.timeOfDay.icon, text: viewModel.timeOfDay.label)
            }

            Menu {
                Button {
                    viewModel.clearArea()
                } label: {
                    Label("Near me", systemImage: "location.fill")
                }
                Button {
                    showAreaPicker = true
                } label: {
                    Label("Pick area on map…", systemImage: "map")
                }
            } label: {
                filterChip(icon: placeIcon, text: placeLabel)
            }

            Spacer()
        }
    }

    private var placeIcon: String {
        if case .area = viewModel.place { return "map.fill" }
        return "location.fill"
    }

    private var placeLabel: String {
        if case .area = viewModel.place { return "Selected area" }
        return "Near me"
    }

    private func filterChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(.systemGray6)))
        .foregroundColor(themeColors.primaryColor)
    }

    // MARK: - Go Button

    private var goButton: some View {
        Button {
            isTextFieldFocused = false
            viewModel.go()
        } label: {
            HStack {
                if viewModel.isRunning {
                    ProgressView().tint(.white).padding(.trailing, 4)
                    Text("Looking…")
                } else {
                    Image(systemName: "sparkles")
                    Text("Show me")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.isRunning ? Color.gray : themeColors.detailColor)
            )
        }
        .disabled(viewModel.isRunning)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.steps) { step in
                HStack(spacing: 10) {
                    switch step.state {
                    case .running: ProgressView().scaleEffect(0.6).frame(width: 16)
                    case .completed: Image(systemName: "checkmark.circle.fill").foregroundColor(.green).frame(width: 16)
                    case .failed: Image(systemName: "xmark.circle.fill").foregroundColor(.red).frame(width: 16)
                    case .pending: Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1.5).frame(width: 12, height: 12)
                    }
                    Text(step.message)
                        .font(.caption)
                        .foregroundColor(themeColors.secondaryColor)
                    Spacer()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
            Text(message).font(.subheadline).foregroundColor(themeColors.secondaryColor)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
    }

    // MARK: - Results

    @ViewBuilder
    private func resultSection(_ result: RightNowResult) -> some View {
        if result.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "wind").font(.system(size: 36)).foregroundColor(.gray)
                Text(result.intro)
                    .font(.subheadline)
                    .foregroundColor(themeColors.secondaryColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if !result.intro.isEmpty {
                    Text(result.intro)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(themeColors.primaryColor)
                }
                if !result.now.isEmpty {
                    sectionHeader("NOW NEAR YOU")
                    ForEach(result.now) { itemRow($0) }
                }
                if !result.next.isEmpty {
                    sectionHeader("WHAT TO DO NEXT")
                    ForEach(result.next) { itemRow($0) }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(themeColors.secondaryColor)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private func itemRow(_ item: RightNowItem) -> some View {
        Button {
            navigateToDetail(uid: item.uid)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let resolved = viewModel.resolvedObjects[item.uid] {
                    nativeRow(uid: item.uid, resolved: resolved)
                } else {
                    Text(item.name).font(.body).foregroundColor(themeColors.primaryColor)
                }
                if !item.pitch.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.caption2).foregroundStyle(.purple)
                        Text(item.pitch)
                            .font(.caption)
                            .foregroundColor(themeColors.secondaryColor)
                            .lineLimit(2)
                    }
                    .padding(.leading, 4)
                }
                if let meta = metaLine(item) {
                    Text(meta).font(.caption2).foregroundColor(.gray).padding(.leading, 4)
                }
            }
        }
        .buttonStyle(.plain)
        .id(item.uid)
    }

    private func metaLine(_ item: RightNowItem) -> String? {
        var parts: [String] = []
        if let time = item.timeInfo { parts.append(time) }
        if let walk = item.walkMinutes, walk > 0 { parts.append("~\(walk) min walk") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func nativeRow(uid: String, resolved: AIResolvedObject) -> some View {
        let isFavorite = viewModel.favoriteIDs.contains(uid)
        let onFavoriteTap: () -> Void = { Task { await viewModel.toggleFavorite(uid) } }
        switch resolved {
        case .art(let art):
            ObjectRowView(object: art, subtitle: nil, rightSubtitle: art.artist,
                          isFavorite: isFavorite, onFavoriteTap: onFavoriteTap) { _ in EmptyView() }
        case .camp(let camp):
            ObjectRowView(object: camp, subtitle: nil, rightSubtitle: camp.hometown,
                          isFavorite: isFavorite, onFavoriteTap: onFavoriteTap) { _ in EmptyView() }
        case .event(let event):
            ObjectRowView(object: event, subtitle: nil, rightSubtitle: event.eventTypeLabel,
                          isFavorite: isFavorite, onFavoriteTap: onFavoriteTap) { _ in EmptyView() }
        case .mutantVehicle(let mv):
            ObjectRowView(object: mv, subtitle: nil, rightSubtitle: mv.artist,
                          isFavorite: isFavorite, onFavoriteTap: onFavoriteTap) { _ in EmptyView() }
        }
    }

    // MARK: - Navigation

    private func navigateToDetail(uid: String) {
        guard let resolved = viewModel.resolvedObjects[uid] else { return }
        let playaDB = viewModel.playaDB
        let detailVC: UIViewController
        switch resolved {
        case .art(let art): detailVC = DetailViewControllerFactory.create(with: art, playaDB: playaDB)
        case .camp(let camp): detailVC = DetailViewControllerFactory.create(with: camp, playaDB: playaDB)
        case .event(let event): detailVC = DetailViewControllerFactory.create(with: event, playaDB: playaDB)
        case .mutantVehicle(let mv): detailVC = DetailViewControllerFactory.create(with: mv, playaDB: playaDB)
        }
        onNavigateToDetail(detailVC)
    }
}

#endif
