//
//  GeneralChatWorkflow.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableChatItem {
    @Guide(description: "Object uid from tool results")
    var uid: String
    @Guide(description: "Brief pitch for why this is relevant, under 12 words")
    var pitch: String
}

@available(iOS 26, *)
@Generable
struct GenerableChatResponse {
    @Guide(description: "Natural language response to the user")
    var response: String
    @Guide(description: "Relevant objects found, if any", .count(0...8))
    var items: [GenerableChatItem]
}

// MARK: - General Chat Workflow

@available(iOS 26, *)
struct GeneralChatWorkflow: Workflow {
    enum Mode { case search, nearby, general }

    let query: String
    let mode: Mode
    let name = "General Chat"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> DiscoveryResult {
        onProgress(.stepStarted(name: "search", description: "Searching the playa..."))

        var tools: [any Tool] = [
            SearchByKeywordTool(playaDB: context.playaDB, detailLevel: .normal),
            FetchArtTool(playaDB: context.playaDB, detailLevel: .normal),
            FetchCampsTool(playaDB: context.playaDB, detailLevel: .normal),
            FetchMutantVehiclesTool(playaDB: context.playaDB, detailLevel: .normal),
            FetchUpcomingEventsTool(playaDB: context.playaDB, detailLevel: .normal),
            GetFavoritesTool(playaDB: context.playaDB, detailLevel: .brief),
        ]

        if mode == .nearby, context.location != nil {
            tools.append(FetchNearbyObjectsTool(playaDB: context.playaDB, detailLevel: .normal))
        }

        var instructions = """
            You are an AI guide for the Burning Man festival. \
            Use the provided tools to find relevant art, camps, events, and vehicles. \
            Answer the user's question naturally and include relevant items.
            """

        if !context.conversationHistory.isEmpty {
            instructions += "\nConversation context: \(context.conversationHistory.joined(separator: "; "))"
        }

        var prompt = query
        if mode == .nearby, let loc = context.location {
            prompt += " (I'm at GPS \(loc.coordinate.latitude), \(loc.coordinate.longitude))"
        }

        let session = LanguageModelSession(tools: tools, instructions: instructions)
        let response = try await session.respond(to: Prompt(prompt), generating: GenerableChatResponse.self)

        onProgress(.stepCompleted(name: "search"))

        // Resolve items to get their names and types
        let items = await resolveDiscoveryItems(
            picks: response.content.items.map { (uid: $0.uid, pitch: $0.pitch) },
            playaDB: context.playaDB
        )

        return DiscoveryResult(
            items: items,
            intro: response.content.response
        )
    }
}

#endif
