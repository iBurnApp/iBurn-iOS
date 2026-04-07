//
//  ConversationManager.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Manages conversation state across multiple turns.
/// Recycles the LanguageModelSession after a configurable number of turns
/// to prevent context window overflow, preserving a summary of the conversation.
@available(iOS 26, *)
final class ConversationManager: @unchecked Sendable {
    private let maxTurns = 5
    private var turnCount = 0
    private var discussedUIDs: [String] = []
    private var userPreferences: [String] = []
    private var topicSummary: String = ""

    /// Record that we discussed certain objects
    func recordDiscussedUIDs(_ uids: [String]) {
        // Keep last 5 UIDs
        discussedUIDs.append(contentsOf: uids)
        if discussedUIDs.count > 5 {
            discussedUIDs = Array(discussedUIDs.suffix(5))
        }
    }

    /// Record a user preference stated in conversation
    func recordPreference(_ preference: String) {
        userPreferences.append(preference)
        if userPreferences.count > 3 {
            userPreferences = Array(userPreferences.suffix(3))
        }
    }

    /// Update topic summary
    func updateTopic(_ topic: String) {
        topicSummary = topic
    }

    /// Increment turn counter and check if session should be recycled
    func incrementTurn() -> Bool {
        turnCount += 1
        return turnCount >= maxTurns
    }

    /// Reset the turn counter (call after recycling session)
    func recycle() {
        turnCount = 0
    }

    /// Get conversation context summary for a new session
    var conversationSummary: [String] {
        var parts: [String] = []
        if !topicSummary.isEmpty {
            parts.append("Topic: \(topicSummary)")
        }
        if !discussedUIDs.isEmpty {
            parts.append("Recently discussed UIDs: \(discussedUIDs.joined(separator: ", "))")
        }
        if !userPreferences.isEmpty {
            parts.append("User preferences: \(userPreferences.joined(separator: "; "))")
        }
        return parts
    }

    /// Whether we have conversation context from previous turns
    var hasContext: Bool {
        !discussedUIDs.isEmpty || !userPreferences.isEmpty || !topicSummary.isEmpty
    }
}

#endif
