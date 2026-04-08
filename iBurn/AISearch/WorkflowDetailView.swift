//
//  WorkflowDetailView.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import SwiftUI
import PlayaDB
import UIKit

@available(iOS 26, *)
struct WorkflowDetailView: View {
    let workflowInfo: WorkflowInfo
    @ObservedObject var viewModel: AIGuideViewModel
    let onNavigateToDetail: (UIViewController) -> Void
    @Environment(\.themeColors) var themeColors

    // MARK: - Workflow-specific configuration
    @State private var themeText: String = ""
    @State private var hoursBack: Double = 24
    @State private var startDate: Date = YearSettings.dayWithinFestival(Date())

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Configuration knobs (workflow-specific)
                configSection

                // Generate button
                generateButton

                // Progress steps (the sausage being made)
                if !viewModel.steps.isEmpty {
                    progressSection
                }

                // Error state
                if case .failed(let message) = viewModel.executionState {
                    errorView(message)
                }

                // Results
                if let result = viewModel.result {
                    resultSection(result)
                }
            }
            .padding()
        }
        .onTapGesture { isTextFieldFocused = false }
        .scrollDismissesKeyboard(.interactively)
        .task {
            // Load cached state for this workflow
            viewModel.loadWorkflow(workflowInfo.id)
            // Auto-start if never run
            if !viewModel.hasRun(workflowInfo.id), !needsUserInput {
                runWorkflow()
            }
        }
    }

    /// Whether this workflow needs user input before running
    private var needsUserInput: Bool {
        switch workflowInfo.id {
        case .adventure, .campCrawl, .dayPlanner:
            return true
        default:
            return false
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: workflowInfo.icon)
                .font(.system(size: 28))
                .foregroundColor(themeColors.detailColor)
            Text(workflowInfo.subtitle)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
        }
    }

    // MARK: - Configuration Knobs

    @ViewBuilder
    private var configSection: some View {
        switch workflowInfo.id {
        case .adventure:
            VStack(alignment: .leading, spacing: 8) {
                Text("Adventure Theme")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.secondaryColor)
                TextField("e.g. fire art, interactive, deep playa...", text: $themeText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit { runWorkflow() }
            }

        case .campCrawl:
            VStack(alignment: .leading, spacing: 8) {
                Text("Crawl Theme")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.secondaryColor)
                TextField("e.g. coffee, music, workshops...", text: $themeText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit { runWorkflow() }
            }

        case .dayPlanner:
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.secondaryColor)
                DatePicker(
                    "Start",
                    selection: $startDate,
                    in: YearSettings.eventStart...YearSettings.eventEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            }

        case .whatDidIMiss:
            VStack(alignment: .leading, spacing: 8) {
                Text("Look back \(Int(hoursBack)) hours")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeColors.secondaryColor)
                Slider(value: $hoursBack, in: 6...48, step: 6) {
                    Text("Hours")
                }
                HStack {
                    Text("6h").font(.caption2).foregroundColor(.gray)
                    Spacer()
                    Text("48h").font(.caption2).foregroundColor(.gray)
                }
            }

        default:
            EmptyView()
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            runWorkflow()
        } label: {
            HStack {
                if case .running = viewModel.executionState {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                    Text("Working...")
                } else {
                    Image(systemName: "wand.and.stars")
                    Text(buttonLabel)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isRunning ? Color.gray : themeColors.detailColor)
            )
        }
        .disabled(isRunning)
    }

    private var isRunning: Bool {
        if case .running = viewModel.executionState { return true }
        return false
    }

    private var buttonLabel: String {
        switch viewModel.executionState {
        case .completed: return "Run Again"
        case .failed: return "Try Again"
        default: return "Generate"
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What's happening")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColors.secondaryColor)
                .padding(.bottom, 8)

            ForEach(viewModel.steps) { step in
                WorkflowStepRow(step: step, themeColors: themeColors)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Results

    @ViewBuilder
    private func resultSection(_ content: WorkflowResultContent) -> some View {
        switch content {
        case .discovery(let intro, let items):
            discoveryResultView(intro: intro, items: items)
        case .schedule(let schedule):
            scheduleResultView(schedule)
        case .adventure(let adventure):
            adventureResultView(adventure)
        case .empty(let message):
            emptyResultView(message)
        }
    }

    // MARK: - Discovery Results (using native cells)

    private func discoveryResultView(intro: String, items: [ObjectCard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !intro.isEmpty {
                Text(intro)
                    .font(.subheadline)
                    .foregroundColor(themeColors.primaryColor)
                    .italic()
                    .padding(.bottom, 4)
            }

            ForEach(items) { card in
                resolvedObjectRow(uid: card.uid, reason: card.reason)
            }
        }
    }

    // MARK: - Schedule Results

    private func scheduleResultView(_ schedule: ScheduleResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !schedule.summary.isEmpty {
                Text(schedule.summary)
                    .font(.subheadline)
                    .foregroundColor(themeColors.primaryColor)
                    .italic()
            }

            if schedule.conflictsResolved > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(schedule.conflictsResolved) conflict\(schedule.conflictsResolved == 1 ? "" : "s") resolved")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }

            ForEach(schedule.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    if let walk = entry.walkMinutesFromPrevious, walk > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.caption2)
                            Text("~\(walk) min walk")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 2) {
                            Text(entry.startTime)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(themeColors.detailColor)
                            Text(entry.endTime)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            resolvedObjectRow(uid: entry.uid, reason: entry.reason)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Adventure Results

    private func adventureResultView(_ adventure: AdventureResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(adventure.narrative)
                .font(.subheadline)
                .foregroundColor(themeColors.primaryColor)
                .italic()

            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                Text("Total: ~\(adventure.totalWalkMinutes) min walking")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(themeColors.secondaryColor)

            ForEach(Array(adventure.stops.enumerated()), id: \.element.id) { index, stop in
                VStack(alignment: .leading, spacing: 4) {
                    if let walk = stop.walkMinutesFromPrevious, walk > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.walk")
                                .font(.caption2)
                            Text("~\(walk) min walk")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                    }

                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(themeColors.detailColor))

                        VStack(alignment: .leading, spacing: 4) {
                            resolvedObjectRow(uid: stop.uid, reason: stop.tip)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty Result

    private func emptyResultView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wind")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text(message)
                .font(.subheadline)
                .foregroundColor(themeColors.secondaryColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Resolved Object Row (uses native cells)

    @ViewBuilder
    private func resolvedObjectRow(uid: String, reason: String) -> some View {
        if let resolved = viewModel.resolvedObjects[uid] {
            Button { navigateToDetail(uid: uid) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    nativeRow(uid: uid, resolved: resolved)
                    if !reason.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(themeColors.secondaryColor)
                                .lineLimit(2)
                        }
                        .padding(.leading, 4)
                    }
                }
            }
            .buttonStyle(.plain)
            .id(uid)
        } else {
            Text(uid)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    @ViewBuilder
    private func nativeRow(uid: String, resolved: AIAssistantViewModel.ResolvedObject) -> some View {
        let isFavorite = viewModel.favoriteIDs.contains(uid)
        let onFavoriteTap: () -> Void = { Task { await viewModel.toggleFavorite(uid) } }

        switch resolved {
        case .art(let art):
            MediaObjectRowView(
                object: art,
                subtitle: nil,
                rightSubtitle: art.artist,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .camp(let camp):
            MediaObjectRowView(
                object: camp,
                subtitle: nil,
                rightSubtitle: camp.hometown,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .event(let event):
            MediaObjectRowView(
                object: event,
                subtitle: nil,
                rightSubtitle: event.eventTypeLabel,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        case .mutantVehicle(let mv):
            MediaObjectRowView(
                object: mv,
                subtitle: nil,
                rightSubtitle: mv.artist,
                isFavorite: isFavorite,
                onFavoriteTap: onFavoriteTap
            ) { _ in EmptyView() }
        }
    }

    // MARK: - Navigation

    private func runWorkflow() {
        isTextFieldFocused = false
        viewModel.run(
            workflowInfo.id,
            theme: themeText.isEmpty ? nil : themeText,
            hoursBack: Int(hoursBack),
            startDate: startDate
        )
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
        onNavigateToDetail(detailVC)
    }
}

// MARK: - Step Progress Row

@available(iOS 26, *)
struct WorkflowStepRow: View {
    let step: WorkflowStepProgress
    let themeColors: ImageColors

    var body: some View {
        HStack(spacing: 10) {
            stepIcon
                .frame(width: 20)

            Text(step.message)
                .font(.caption)
                .foregroundColor(textColor)
                .italic(step.state == .running)

            Spacer()
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.3), value: step.state)
    }

    @ViewBuilder
    private var stepIcon: some View {
        switch step.state {
        case .pending:
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .frame(width: 14, height: 14)
        case .running:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
    }

    private var textColor: Color {
        switch step.state {
        case .pending: return .gray
        case .running: return themeColors.primaryColor
        case .completed: return themeColors.secondaryColor
        case .failed: return .red
        }
    }
}

#endif
