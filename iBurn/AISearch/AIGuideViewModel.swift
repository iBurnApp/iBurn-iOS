//
//  AIGuideViewModel.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Step Progress Model

struct WorkflowStepProgress: Identifiable {
    let id = UUID()
    let message: String
    var state: StepState

    enum StepState {
        case pending
        case running
        case completed
        case failed
    }
}

// MARK: - Workflow Execution State

enum WorkflowExecutionState {
    case idle
    case running
    case completed
    case failed(String)
}

// MARK: - Workflow Result

enum WorkflowResultContent {
    case discovery(intro: String, items: [ObjectCard])
    case schedule(ScheduleResult)
    case adventure(AdventureResult)
    case empty(String)
}

// MARK: - Per-Workflow Cached State

struct WorkflowState {
    var steps: [WorkflowStepProgress] = []
    var executionState: WorkflowExecutionState = .idle
    var result: WorkflowResultContent?
}

// MARK: - View Model

@available(iOS 26, *)
@MainActor
final class AIGuideViewModel: ObservableObject {

    // MARK: - Published State (for current workflow)

    @Published var steps: [WorkflowStepProgress] = []
    @Published var executionState: WorkflowExecutionState = .idle
    @Published var result: WorkflowResultContent?
    @Published var resolvedObjects: [String: AIAssistantViewModel.ResolvedObject] = [:]
    @Published var favoriteIDs: Set<String> = []

    // MARK: - Per-Workflow State Cache

    private var workflowStates: [WorkflowID: WorkflowState] = [:]
    private(set) var activeWorkflowID: WorkflowID?

    // MARK: - Dependencies

    let playaDB: PlayaDB
    let orchestrator: AgentOrchestrator
    private var currentTask: Task<Void, Never>?
    private static let maxRetries = 2

    init(playaDB: PlayaDB, orchestrator: AgentOrchestrator) {
        self.playaDB = playaDB
        self.orchestrator = orchestrator
    }

    // MARK: - Workflow Lifecycle

    /// Load cached state for a workflow (called when entering a workflow detail view)
    func loadWorkflow(_ id: WorkflowID) {
        // Save current workflow state
        saveCurrentWorkflowState()

        activeWorkflowID = id
        let state = workflowStates[id] ?? WorkflowState()
        steps = state.steps
        executionState = state.executionState
        result = state.result
    }

    /// Save current workflow state to cache (preserves results across navigation)
    private func saveCurrentWorkflowState() {
        guard let id = activeWorkflowID else { return }
        workflowStates[id] = WorkflowState(
            steps: steps,
            executionState: executionState,
            result: result
        )
    }

    /// Check if a workflow has been run before
    func hasRun(_ id: WorkflowID) -> Bool {
        if let state = workflowStates[id] {
            switch state.executionState {
            case .completed, .running: return true
            default: return false
            }
        }
        return false
    }

    // MARK: - Run Workflow

    func run(
        _ workflowID: WorkflowID,
        theme: String? = nil,
        hoursBack: Int? = nil
    ) {
        currentTask?.cancel()
        steps = []
        result = nil
        executionState = .running

        currentTask = Task { [weak self] in
            guard let self else { return }
            await self.executeWithRetry(workflowID, theme: theme, hoursBack: hoursBack, attempt: 0)
        }
    }

    /// Execute with automatic retry on recoverable errors
    private func executeWithRetry(
        _ workflowID: WorkflowID,
        theme: String?,
        hoursBack: Int?,
        attempt: Int
    ) async {
        do {
            try await executeWorkflow(workflowID, theme: theme, hoursBack: hoursBack, isSafeRetry: attempt > 0)
            executionState = .completed
            saveCurrentWorkflowState()
        } catch is CancellationError {
            // Ignored
        } catch {
            guard !Task.isCancelled else { return }

            if isRetryableError(error), attempt < Self.maxRetries {
                // Recoverable error — retry with a different approach
                markCurrentStepFailed()
                addStep(retryMessage(for: error, attempt: attempt))
                await executeWithRetry(workflowID, theme: theme, hoursBack: hoursBack, attempt: attempt + 1)
            } else {
                markCurrentStepFailed()
                executionState = .failed(userFacingMessage(for: error))
                saveCurrentWorkflowState()
                print("Workflow error: \(error)")
            }
        }
    }

    private func executeWorkflow(
        _ workflowID: WorkflowID,
        theme: String?,
        hoursBack: Int?,
        isSafeRetry: Bool
    ) async throws {
        switch workflowID {
        case .forYou:
            try await runRecommendations(safe: isSafeRetry)
        case .surpriseMe:
            try await runSerendipity(safe: isSafeRetry)
        case .whatDidIMiss:
            try await runWhatDidIMiss(hoursBack: hoursBack ?? 24)
        case .dayPlanner:
            try await runDayPlan(safe: isSafeRetry)
        case .adventure:
            try await runAdventure(theme: theme ?? "best of the playa", safe: isSafeRetry)
        case .campCrawl:
            try await runCampCrawl(theme: theme ?? "eclectic experience", safe: isSafeRetry)
        case .goldenHour:
            try await runGoldenHour()
        case .scheduleOptimizer:
            try await runScheduleOptimizer()
        }
    }

    // MARK: - Error Classification & Retry

    private func isRetryableError(_ error: Error) -> Bool {
        let desc = String(describing: error)
        return desc.contains("guardrailViolation")
            || desc.contains("unsupportedLanguage")
            || desc.contains("unsupportedLocale")
            || desc.contains("fts5: syntax error")
            || desc.contains("resourceExhausted")
    }

    private func retryMessage(for error: Error, attempt: Int) -> String {
        let desc = String(describing: error)
        if desc.contains("guardrailViolation") {
            return "Taking a more family-friendly approach..."
        } else if desc.contains("unsupportedLanguage") || desc.contains("unsupportedLocale") {
            return "Adjusting language settings and trying again..."
        } else if desc.contains("fts5") {
            return "Simplifying the search query..."
        } else {
            return "Dusting off and trying a different path..."
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        let desc = String(describing: error)
        if desc.contains("guardrailViolation") {
            return "The AI couldn't process this request safely. Try a different theme?"
        } else if desc.contains("unsupportedLanguage") || desc.contains("unsupportedLocale") {
            return "AI features require English language settings on this device."
        } else if desc.contains("resourceExhausted") || desc.contains("systemState") {
            return "The AI is temporarily busy. Try again in a moment."
        } else {
            return "Something went wrong. Tap Generate to try again."
        }
    }

    // MARK: - Step Management

    private func addStep(_ message: String) {
        steps.append(WorkflowStepProgress(message: message, state: .running))
    }

    private func completeCurrentStep() {
        guard let idx = steps.lastIndex(where: { $0.state == .running }) else { return }
        steps[idx].state = .completed
    }

    private func markCurrentStepFailed() {
        guard let idx = steps.lastIndex(where: { $0.state == .running }) else { return }
        steps[idx].state = .failed
    }

    // MARK: - Progress Handler

    private func handleProgress(_ progress: WorkflowProgress) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch progress {
            case .stepStarted(_, let description):
                self.addStep(description)
            case .stepCompleted:
                self.completeCurrentStep()
            case .intermediateResult:
                break
            }
        }
    }

    // MARK: - Workflow Runners

    private func runRecommendations(safe: Bool = false) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.tasteProfiling))
        let workflow = SerendipityWorkflow(deliberateRandom: false)
        let discoveryResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        await resolveUIDs(discoveryResult.items.map(\.uid))
        result = .discovery(
            intro: discoveryResult.intro,
            items: discoveryResult.items.map { item in
                ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
            }
        )
    }

    private func runSerendipity(safe: Bool = false) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.serendipity))
        let workflow = SerendipityWorkflow(deliberateRandom: true)
        let discoveryResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        await resolveUIDs(discoveryResult.items.map(\.uid))
        result = .discovery(
            intro: discoveryResult.intro,
            items: discoveryResult.items.map { item in
                ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
            }
        )
    }

    private func runWhatDidIMiss(hoursBack: Int) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.analyzingTracks))
        let workflow = WhatDidIMissWorkflow()
        let discoveryResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if discoveryResult.items.isEmpty {
            result = .empty(discoveryResult.intro)
        } else {
            await resolveUIDs(discoveryResult.items.map(\.uid))
            result = .discovery(
                intro: discoveryResult.intro,
                items: discoveryResult.items.map { item in
                    ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
                }
            )
        }
    }

    private func runDayPlan(safe: Bool = false) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.tasteProfiling))
        let workflow = DayPlanWorkflow()
        let planResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if planResult.items.isEmpty {
            result = .empty(planResult.summary)
        } else {
            await resolveUIDs(planResult.items.map(\.uid))
            result = .schedule(ScheduleResult(
                entries: planResult.items.map { entry in
                    ScheduleResultEntry(uid: entry.uid, name: entry.name, startTime: entry.startTime, endTime: entry.endTime, reason: entry.reason, walkMinutesFromPrevious: entry.walkMinutesFromPrevious)
                },
                summary: planResult.summary,
                conflictsResolved: 0
            ))
        }
    }

    private func runAdventure(theme: String, safe: Bool = false) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.searching))
        let workflow = AdventureWorkflow(theme: safe ? "interesting art and camps" : theme)
        let routeResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if routeResult.stops.isEmpty {
            result = .empty(routeResult.narrative)
        } else {
            await resolveUIDs(routeResult.stops.map(\.id))
            result = .adventure(AdventureResult(
                narrative: routeResult.narrative,
                stops: routeResult.stops.map { stop in
                    AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
                },
                totalWalkMinutes: routeResult.totalWalkMinutes
            ))
        }
    }

    private func runCampCrawl(theme: String, safe: Bool = false) async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.searchingCamps))
        let workflow = CampCrawlWorkflow(theme: safe ? "diverse experiences" : theme)
        let routeResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if routeResult.stops.isEmpty {
            result = .empty(routeResult.narrative)
        } else {
            await resolveUIDs(routeResult.stops.map(\.id))
            result = .adventure(AdventureResult(
                narrative: routeResult.narrative,
                stops: routeResult.stops.map { stop in
                    AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
                },
                totalWalkMinutes: routeResult.totalWalkMinutes
            ))
        }
    }

    private func runGoldenHour() async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.goldenHour))
        let workflow = GoldenHourWorkflow()
        let routeResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if routeResult.stops.isEmpty {
            result = .empty(routeResult.narrative)
        } else {
            await resolveUIDs(routeResult.stops.map(\.id))
            result = .adventure(AdventureResult(
                narrative: routeResult.narrative,
                stops: routeResult.stops.map { stop in
                    AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
                },
                totalWalkMinutes: routeResult.totalWalkMinutes
            ))
        }
    }

    private func runScheduleOptimizer() async throws {
        addStep(PlayaProgressMessages.random(from: PlayaProgressMessages.conflictDetection))
        let workflow = ScheduleOptimizerWorkflow()
        let optimizerResult = try await orchestrator.execute(workflow) { [weak self] progress in
            self?.handleProgress(progress)
        }
        completeCurrentStep()
        if optimizerResult.items.isEmpty {
            result = .empty(optimizerResult.summary)
        } else {
            await resolveUIDs(optimizerResult.items.map(\.uid))
            result = .schedule(ScheduleResult(
                entries: optimizerResult.items.map { entry in
                    ScheduleResultEntry(uid: entry.uid, name: entry.name, startTime: entry.startTime, endTime: entry.endTime, reason: entry.reason, walkMinutesFromPrevious: entry.walkMinutesFromPrevious)
                },
                summary: optimizerResult.summary,
                conflictsResolved: optimizerResult.conflictsResolved
            ))
        }
    }

    // MARK: - Object Resolution

    func resolveUIDs(_ uids: [String]) async {
        let unresolvedUIDs = uids.filter { resolvedObjects[$0] == nil }
        guard !unresolvedUIDs.isEmpty else { return }

        guard let objects = try? await playaDB.fetchObjects(byUIDs: unresolvedUIDs) else { return }
        for obj in objects {
            if let art = obj as? ArtObject {
                resolvedObjects[art.uid] = .art(art)
            } else if let camp = obj as? CampObject {
                resolvedObjects[camp.uid] = .camp(camp)
            } else if let event = obj as? EventObject {
                resolvedObjects[event.uid] = .event(event)
            } else if let mv = obj as? MutantVehicleObject {
                resolvedObjects[mv.uid] = .mutantVehicle(mv)
            }
        }

        // Batch check favorites
        let favorites = (try? await playaDB.getFavorites()) ?? []
        let favUIDs = Set(favorites.map(\.uid))
        for uid in unresolvedUIDs where favUIDs.contains(uid) {
            favoriteIDs.insert(uid)
        }
    }

    func toggleFavorite(_ uid: String) async {
        guard let resolved = resolvedObjects[uid] else { return }
        do {
            switch resolved {
            case .art(let art):
                try await playaDB.toggleFavorite(art)
                let isFav = try await playaDB.isFavorite(art)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .camp(let camp):
                try await playaDB.toggleFavorite(camp)
                let isFav = try await playaDB.isFavorite(camp)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .event(let event):
                try await playaDB.toggleFavorite(event)
                let isFav = try await playaDB.isFavorite(event)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            case .mutantVehicle(let mv):
                try await playaDB.toggleFavorite(mv)
                let isFav = try await playaDB.isFavorite(mv)
                if isFav { favoriteIDs.insert(uid) } else { favoriteIDs.remove(uid) }
            }
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }
}

#endif
