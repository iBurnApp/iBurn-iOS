//
//  ChatViewModel.swift
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

/// Central coordinator for the AI chat experience.
/// Receives user input, classifies intent, routes to workflows,
/// and streams progress + results to the UI.
@available(iOS 26, *)
@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isProcessing: Bool = false
    @Published var resolvedObjects: [String: AIAssistantViewModel.ResolvedObject] = [:]
    @Published var favoriteIDs: Set<String> = []

    // MARK: - Dependencies

    let playaDB: PlayaDB
    private let orchestrator: AgentOrchestrator
    private let conversationManager = ConversationManager()
    private var currentTask: Task<Void, Never>?

    init(playaDB: PlayaDB, orchestrator: AgentOrchestrator) {
        self.playaDB = playaDB
        self.orchestrator = orchestrator
    }

    // MARK: - Send Message

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        // Add user message
        messages.append(ChatMessage(role: .user, content: .text(text)))

        currentTask?.cancel()
        isProcessing = true

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                // Classify intent
                let intent = try await IntentClassifier.classify(text)
                guard !Task.isCancelled else { return }

                // Route to workflow
                try await self.routeIntent(intent, originalMessage: text)
            } catch is CancellationError {
                // Ignored
            } catch {
                guard !Task.isCancelled else { return }
                self.replaceLoadingWith(.error("Something went wrong. Try again."))
                print("Chat error: \(error)")
            }
            self.isProcessing = false
        }
    }

    /// Execute a quick action directly (bypasses intent classification)
    func executeQuickAction(_ action: QuickAction) {
        inputText = action.prompt
        send()
    }

    // MARK: - Intent Routing

    private func routeIntent(_ intent: ChatIntent, originalMessage: String) async throws {
        switch intent {
        case .search(let query):
            try await handleSearch(query.isEmpty ? originalMessage : query)

        case .recommend:
            try await handleRecommendations()

        case .dayPlan:
            try await handleDayPlan()

        case .nearby:
            try await handleNearby()

        case .adventure(let theme):
            try await handleAdventure(theme: theme ?? originalMessage)

        case .scheduleOptimize:
            try await handleScheduleOptimize()

        case .serendipity:
            try await handleSerendipity()

        case .campCrawl(let theme):
            try await handleCampCrawl(theme: theme ?? originalMessage)

        case .whatDidIMiss:
            try await handleWhatDidIMiss()

        case .goldenHour:
            try await handleGoldenHour()

        case .general(let query):
            try await handleGeneral(query.isEmpty ? originalMessage : query)
        }
    }

    // MARK: - Workflow Handlers

    private func handleSearch(_ query: String) async throws {
        addLoadingMessage("Searching the playa...")
        let workflow = GeneralChatWorkflow(query: query, mode: .search)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        conversationManager.recordDiscussedUIDs(result.items.map(\.uid))
        replaceLoadingWith(.objectCards(result.items.map { item in
            ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
        }))
        if !result.intro.isEmpty {
            messages.insert(ChatMessage(role: .assistant, content: .text(result.intro)), at: messages.count - 1)
        }
        addFollowUpActions(["Search more", "Tell me more about these", "Something different"])
    }

    private func handleRecommendations() async throws {
        addLoadingMessage("Analyzing your taste...")
        let workflow = SerendipityWorkflow(deliberateRandom: false)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        conversationManager.recordDiscussedUIDs(result.items.map(\.uid))
        replaceLoadingWith(.text(result.intro))
        messages.append(ChatMessage(role: .assistant, content: .objectCards(result.items.map { item in
            ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
        })))
        addFollowUpActions(["More like these", "Something completely different", "Surprise me"])
    }

    private func handleDayPlan() async throws {
        addLoadingMessage("Planning your day...")
        let workflow = DayPlanWorkflow()
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        replaceLoadingWith(.schedule(ScheduleResult(
            entries: result.items.map { ScheduleResultEntry(uid: $0.uid, name: $0.name, startTime: $0.startTime, endTime: $0.endTime, reason: $0.reason, walkMinutesFromPrevious: $0.walkMinutesFromPrevious) },
            summary: result.summary,
            conflictsResolved: 0
        )))
        addFollowUpActions(["Optimize my schedule", "Add more events", "Plan tomorrow"])
    }

    private func handleNearby() async throws {
        guard orchestrator.locationProvider.currentLocation != nil else {
            replaceLoadingWith(.error("Location not available. Enable location services."))
            return
        }
        addLoadingMessage("Looking around you...")
        let workflow = GeneralChatWorkflow(query: "What's interesting near me right now?", mode: .nearby)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        replaceLoadingWith(.objectCards(result.items.map { item in
            ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
        }))
        addFollowUpActions(["What else is nearby?", "Plan a route", "Events starting soon"])
    }

    private func handleAdventure(theme: String) async throws {
        addLoadingMessage("Crafting your adventure...")
        let workflow = AdventureWorkflow(theme: theme)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.stops.map(\.id))
        replaceLoadingWith(.adventure(AdventureResult(
            narrative: result.narrative,
            stops: result.stops.map { stop in
                AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
            },
            totalWalkMinutes: result.totalWalkMinutes
        )))
        addFollowUpActions(["Different theme", "Add more stops", "Show on map"])
    }

    private func handleScheduleOptimize() async throws {
        addLoadingMessage("Analyzing your favorites for conflicts...")
        let workflow = ScheduleOptimizerWorkflow()
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        replaceLoadingWith(.schedule(ScheduleResult(
            entries: result.items.map { ScheduleResultEntry(uid: $0.uid, name: $0.name, startTime: $0.startTime, endTime: $0.endTime, reason: $0.reason, walkMinutesFromPrevious: $0.walkMinutesFromPrevious) },
            summary: result.summary,
            conflictsResolved: result.conflictsResolved
        )))
        addFollowUpActions(["Find alternatives", "Add more events", "Plan full day"])
    }

    private func handleSerendipity() async throws {
        addLoadingMessage("Rolling the dice...")
        let workflow = SerendipityWorkflow(deliberateRandom: true)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        replaceLoadingWith(.text(result.intro))
        messages.append(ChatMessage(role: .assistant, content: .objectCards(result.items.map { item in
            ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
        })))
        addFollowUpActions(["Surprise me again", "More like the first one", "Tell me more"])
    }

    private func handleCampCrawl(theme: String) async throws {
        addLoadingMessage("Planning your camp crawl...")
        let workflow = CampCrawlWorkflow(theme: theme)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.stops.map(\.id))
        replaceLoadingWith(.adventure(AdventureResult(
            narrative: result.narrative,
            stops: result.stops.map { stop in
                AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
            },
            totalWalkMinutes: result.totalWalkMinutes
        )))
        addFollowUpActions(["Different theme", "Add events along the way", "Coffee trail"])
    }

    private func handleWhatDidIMiss() async throws {
        addLoadingMessage("Checking your tracks...")
        let workflow = WhatDidIMissWorkflow()
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.items.map(\.uid))
        replaceLoadingWith(.text(result.intro))
        messages.append(ChatMessage(role: .assistant, content: .objectCards(result.items.map { item in
            ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
        })))
        addFollowUpActions(["Check last 48 hours", "Plan a route to these", "What's nearby now?"])
    }

    private func handleGoldenHour() async throws {
        addLoadingMessage("Finding golden hour art...")
        let workflow = GoldenHourWorkflow()
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        await resolveUIDs(result.stops.map(\.id))
        replaceLoadingWith(.adventure(AdventureResult(
            narrative: result.narrative,
            stops: result.stops.map { stop in
                AdventureStop(uid: stop.id, name: stop.name, type: stop.type, tip: stop.reason, walkMinutesFromPrevious: stop.walkMinutesFromPrevious)
            },
            totalWalkMinutes: result.totalWalkMinutes
        )))
        addFollowUpActions(["Sunrise instead", "Deep playa only", "Add music events"])
    }

    private func handleGeneral(_ query: String) async throws {
        addLoadingMessage("Thinking...")
        let workflow = GeneralChatWorkflow(query: query, mode: .general)
        let result = try await orchestrator.execute(workflow, conversationHistory: conversationManager.conversationSummary) { [weak self] progress in
            Task { @MainActor in self?.handleProgress(progress) }
        }
        conversationManager.updateTopic(query)
        if result.items.isEmpty {
            replaceLoadingWith(.text(result.intro))
        } else {
            await resolveUIDs(result.items.map(\.uid))
            conversationManager.recordDiscussedUIDs(result.items.map(\.uid))
            replaceLoadingWith(.text(result.intro))
            messages.append(ChatMessage(role: .assistant, content: .objectCards(result.items.map { item in
                ObjectCard(uid: item.uid, name: item.name, type: item.type, reason: item.pitch, distance: nil, timeInfo: nil)
            })))
        }
    }

    // MARK: - Helpers

    private func addLoadingMessage(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: .loading(text)))
    }

    private func replaceLoadingWith(_ content: ChatMessage.MessageContent) {
        // Replace the last loading message
        if let idx = messages.lastIndex(where: {
            if case .loading = $0.content { return true }
            return false
        }) {
            messages[idx] = ChatMessage(role: .assistant, content: content)
        } else {
            messages.append(ChatMessage(role: .assistant, content: content))
        }
    }

    private func handleProgress(_ progress: WorkflowProgress) {
        switch progress {
        case .stepStarted(_, let description):
            // Update the loading message
            if let idx = messages.lastIndex(where: {
                if case .loading = $0.content { return true }
                return false
            }) {
                messages[idx] = ChatMessage(role: .assistant, content: .loading(description))
            }
        case .stepCompleted:
            break
        case .intermediateResult(let text):
            messages.append(ChatMessage(role: .assistant, content: .text(text)))
        }
    }

    private func addFollowUpActions(_ labels: [String]) {
        let actions = labels.map { QuickAction(label: $0, prompt: $0, icon: "arrow.right.circle") }
        messages.append(ChatMessage(role: .assistant, content: .quickActions(actions)))
    }

    // MARK: - Object Resolution (shared with AIAssistantViewModel)

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
