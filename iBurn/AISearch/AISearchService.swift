//
//  AISearchService.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
@preconcurrency import PlayaDB

/// Result from AI-powered semantic search
struct AISearchResult: Sendable {
    let uid: String
    let reason: String
}

/// Protocol for AI-powered semantic search
protocol AISearchService: Sendable {
    /// Whether AI search is available on this device
    var isAvailable: Bool { get }

    /// Perform semantic search using on-device language model
    func search(_ query: String) async throws -> [AISearchResult]
}

#if canImport(FoundationModels)
import FoundationModels

/// AI search implementation using Apple Foundation Models (iOS 26+)
@available(iOS 26, *)
final class FoundationModelSearchService: AISearchService {
    private let playaDB: PlayaDB

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    func search(_ query: String) async throws -> [AISearchResult] {
        guard isAvailable else { return [] }

        let tools: [any Tool] = [
            SearchByKeywordTool(playaDB: playaDB),
            FetchArtTool(playaDB: playaDB),
            FetchCampsTool(playaDB: playaDB),
            FetchMutantVehiclesTool(playaDB: playaDB),
        ]

        let session = LanguageModelSession(
            tools: tools,
            instructions: """
                You are a search assistant for the Burning Man festival guide app. \
                Use the provided tools to find art installations, theme camps, events, \
                and mutant vehicles matching the user's query. Return the most relevant \
                results as a JSON array of objects with "uid" and "reason" fields. \
                Keep reasons brief (under 10 words).
                """
        )

        let response = try await session.respond(
            to: Prompt(query),
            generating: AISearchResponse.self
        )

        return response.content.results.map {
            AISearchResult(uid: $0.uid, reason: $0.reason)
        }
    }
}

@available(iOS 26, *)
@Generable
struct AISearchResultItem {
    @Guide(description: "Object uid")
    var uid: String
    @Guide(description: "Brief reason this matches")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct AISearchResponse {
    @Guide(description: "Matching results", .count(1...10))
    var results: [AISearchResultItem]
}

#endif

/// Factory for creating the appropriate AI search service
enum AISearchServiceFactory {
    @MainActor
    static func create(playaDB: PlayaDB) -> AISearchService? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let service = FoundationModelSearchService(playaDB: playaDB)
            return service.isAvailable ? service : nil
        }
        #endif
        return nil
    }
}
