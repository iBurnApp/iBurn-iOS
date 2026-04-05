//
//  AISearchService.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import CoreLocation
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

/// Extended protocol for AI assistant features (recommendations, day planner, nearby)
protocol AIAssistantService: AISearchService {
    /// Recommend items based on user's favorites
    func recommend() async throws -> [AIRecommendation]

    /// Generate a day plan for a specific date
    func planDay(date: Date, location: CLLocation?) async throws -> AIDayPlan

    /// Find interesting things happening nearby right now
    func whatsNearby(location: CLLocation) async throws -> [AINearbyHighlight]
}

#if canImport(FoundationModels)
import FoundationModels

/// AI search and assistant implementation using Apple Foundation Models (iOS 26+)
@available(iOS 26, *)
final class FoundationModelSearchService: AIAssistantService {
    private let playaDB: PlayaDB

    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    init(playaDB: PlayaDB) {
        self.playaDB = playaDB
    }

    // MARK: - Search

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

    // MARK: - Recommendations

    func recommend() async throws -> [AIRecommendation] {
        guard isAvailable else { return [] }

        let tools: [any Tool] = [
            GetFavoritesTool(playaDB: playaDB),
            SearchByKeywordTool(playaDB: playaDB),
            FetchArtTool(playaDB: playaDB),
            FetchCampsTool(playaDB: playaDB),
            FetchMutantVehiclesTool(playaDB: playaDB),
        ]

        let session = LanguageModelSession(
            tools: tools,
            instructions: """
                You are a recommendation engine for a Burning Man festival guide. \
                First call getFavorites to see what the user likes. Analyze the themes, \
                types, and keywords in their favorites. Then search for similar items \
                they haven't favorited yet. Return diverse recommendations across types.
                """
        )

        let response = try await session.respond(
            to: Prompt("What should I check out based on my favorites?"),
            generating: GenerableRecommendationResponse.self
        )

        return response.content.recommendations.map {
            AIRecommendation(uid: $0.uid, reason: $0.reason)
        }
    }

    // MARK: - Day Planner

    func planDay(date: Date, location: CLLocation?) async throws -> AIDayPlan {
        guard isAvailable else { return AIDayPlan(schedule: [], summary: "") }

        var tools: [any Tool] = [
            GetFavoritesTool(playaDB: playaDB),
            FetchUpcomingEventsTool(playaDB: playaDB),
        ]
        if location != nil {
            tools.append(FetchNearbyObjectsTool(playaDB: playaDB))
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let dayString = formatter.string(from: date)

        var prompt = "Plan my day for \(dayString) at Burning Man."
        if let loc = location {
            prompt += " I'm currently at GPS \(loc.coordinate.latitude), \(loc.coordinate.longitude)."
        }

        let session = LanguageModelSession(
            tools: tools,
            instructions: """
                You are a day planner for Burning Man. Check the user's favorites to \
                understand their interests. Find upcoming events that match. Create a \
                schedule ordered by time. Mix familiar interests with new discoveries. \
                Consider walk time between locations (~10 min across playa).
                """
        )

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: GenerableDayPlanResponse.self
        )

        let schedule = response.content.schedule.map {
            AIScheduleItem(uid: $0.uid, startTime: $0.startTime, reason: $0.reason)
        }
        return AIDayPlan(schedule: schedule, summary: response.content.summary)
    }

    // MARK: - What's Nearby

    func whatsNearby(location: CLLocation) async throws -> [AINearbyHighlight] {
        guard isAvailable else { return [] }

        let tools: [any Tool] = [
            GetFavoritesTool(playaDB: playaDB),
            FetchUpcomingEventsTool(playaDB: playaDB),
            FetchNearbyObjectsTool(playaDB: playaDB),
        ]

        let session = LanguageModelSession(
            tools: tools,
            instructions: """
                You are a Burning Man guide. Find the most interesting things near \
                the user right now. Check their favorites to understand preferences. \
                Prioritize: events starting soon, art matching their taste, and camps \
                they'd enjoy. Highlight why each item is worth visiting right now.
                """
        )

        let prompt = """
            What's interesting near me? I'm at GPS \
            \(location.coordinate.latitude), \(location.coordinate.longitude).
            """

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: GenerableNearbyResponse.self
        )

        return response.content.highlights.map {
            AINearbyHighlight(uid: $0.uid, reason: $0.reason)
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

/// Factory for creating the appropriate AI service
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

    @MainActor
    static func createAssistant(playaDB: PlayaDB) -> AIAssistantService? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let service = FoundationModelSearchService(playaDB: playaDB)
            return service.isAvailable ? service : nil
        }
        #endif
        return nil
    }
}
