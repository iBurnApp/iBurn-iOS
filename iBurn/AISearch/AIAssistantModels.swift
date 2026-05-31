//
//  AIAssistantModels.swift
//  iBurn
//
//  Generable types for the camp/art detail-page event-collection summaries.
//  (The legacy recommend/day-plan/nearby assistant models were removed with the
//  AI Guide overhaul; these two remain because DetailViewModel uses them.)
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

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
