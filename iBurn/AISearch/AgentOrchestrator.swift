//
//  AgentOrchestrator.swift
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

/// Orchestrates multi-step AI workflows using Apple Foundation Models.
///
/// Each workflow step gets its own `LanguageModelSession` with only the tools
/// needed for that step. This keeps each step well within the ~4K token budget.
@available(iOS 26, *)
final class AgentOrchestrator: @unchecked Sendable {
    let playaDB: PlayaDB
    let locationProvider: LocationProvider

    init(playaDB: PlayaDB, locationProvider: LocationProvider) {
        self.playaDB = playaDB
        self.locationProvider = locationProvider
    }

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    // MARK: - Step Execution

    /// Execute a single LLM step with focused tools and instructions
    func executeStep<T: Generable>(
        prompt: String,
        instructions: String,
        tools: [any Tool] = [],
        generating type: T.Type
    ) async throws -> T {
        let session = LanguageModelSession(
            tools: tools,
            instructions: instructions
        )
        let response = try await session.respond(to: Prompt(prompt), generating: type)
        return response.content
    }

    /// Execute a single LLM step that returns plain text
    func executeTextStep(
        prompt: String,
        instructions: String,
        tools: [any Tool] = []
    ) async throws -> String {
        let session = LanguageModelSession(
            tools: tools,
            instructions: instructions
        )
        let response = try await session.respond(to: Prompt(prompt))
        return response.content
    }

    // MARK: - Workflow Execution

    /// Execute a complete workflow with progress streaming
    func execute<W: Workflow>(
        _ workflow: W,
        conversationHistory: [String] = [],
        onProgress: @escaping (WorkflowProgress) -> Void
    ) async throws -> W.Result {
        let context = WorkflowContext(
            playaDB: playaDB,
            location: locationProvider.currentLocation,
            date: Date(),
            conversationHistory: conversationHistory
        )
        return try await workflow.execute(context: context, onProgress: onProgress)
    }

    // MARK: - Tool Factory

    /// Create search tools at a specific detail level
    func makeSearchTools(detailLevel: ToolDetailLevel = .normal) -> [any Tool] {
        [
            SearchByKeywordTool(playaDB: playaDB, detailLevel: detailLevel),
            FetchArtTool(playaDB: playaDB, detailLevel: detailLevel),
            FetchCampsTool(playaDB: playaDB, detailLevel: detailLevel),
            FetchMutantVehiclesTool(playaDB: playaDB, detailLevel: detailLevel),
        ]
    }

    func makeEventTools(detailLevel: ToolDetailLevel = .normal) -> [any Tool] {
        [
            FetchUpcomingEventsTool(playaDB: playaDB, detailLevel: detailLevel),
            FetchEventsByTypeTool(playaDB: playaDB, detailLevel: detailLevel),
            FetchEventsByCampTool(playaDB: playaDB, detailLevel: detailLevel),
        ]
    }

    func makeDiscoveryTools(detailLevel: ToolDetailLevel = .normal) -> [any Tool] {
        var tools: [any Tool] = [
            GetFavoritesTool(playaDB: playaDB, detailLevel: detailLevel),
            GetViewHistoryTool(playaDB: playaDB, detailLevel: detailLevel),
        ]
        tools.append(FetchObjectDetailsTool(playaDB: playaDB))
        return tools
    }
}

#endif
