//
//  AIAssistantModels.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

// MARK: - Public Result Types (always available)

/// A recommendation from the AI assistant
struct AIRecommendation: Sendable, Identifiable {
    let uid: String
    let reason: String
    var id: String { uid }
}

/// A scheduled item in an AI-generated day plan
struct AIScheduleItem: Sendable, Identifiable {
    let uid: String
    let startTime: String
    let reason: String
    var id: String { uid }
}

/// An AI-generated day plan
struct AIDayPlan: Sendable {
    let schedule: [AIScheduleItem]
    let summary: String
}

/// A nearby highlight from the AI assistant
struct AINearbyHighlight: Sendable, Identifiable {
    let uid: String
    let reason: String
    var id: String { uid }
}

// MARK: - Generable Types (iOS 26+ only)

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@Generable
struct GenerableRecommendation {
    @Guide(description: "Object uid")
    var uid: String
    @Guide(description: "Why this matches the user's taste, under 12 words")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableRecommendationResponse {
    @Guide(description: "Recommended items", .count(3...8))
    var recommendations: [GenerableRecommendation]
}

@available(iOS 26, *)
@Generable
struct GenerableScheduleItem {
    @Guide(description: "Event uid")
    var uid: String
    @Guide(description: "Start time like '2:00 PM'")
    var startTime: String
    @Guide(description: "Why this fits the plan, under 12 words")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableDayPlanResponse {
    @Guide(description: "Events ordered by time", .count(3...10))
    var schedule: [GenerableScheduleItem]
    @Guide(description: "One-sentence summary of the day theme")
    var summary: String
}

@available(iOS 26, *)
@Generable
struct GenerableNearbyHighlight {
    @Guide(description: "Object uid")
    var uid: String
    @Guide(description: "Why this is interesting right now, under 12 words")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableNearbyResponse {
    @Guide(description: "Nearby highlights, most interesting first", .count(2...8))
    var highlights: [GenerableNearbyHighlight]
}

@available(iOS 26, *)
@Generable
struct GenerableEventCollectionSummary {
    @Guide(description: "1-2 short factual sentences about this host. Only reference provided data. No times or schedules.")
    var summary: String
}

@available(iOS 26, *)
@Generable
struct GenerableFactCheck {
    @Guide(description: "Phrases from the summary that are NOT supported by the source data. Empty if everything is accurate.", .count(0...5))
    var unsupportedClaims: [String]
}

#endif
