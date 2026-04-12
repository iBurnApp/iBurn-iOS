//
//  ContextBudget.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Tracks token budget for LLM context windows.
/// Apple Foundation Models have ~4K token limit.
/// We reserve ~500 tokens for system overhead, leaving ~3500 for content.
struct ContextBudget {
    static let maxTokens = 3500
    private(set) var used: Int = 0

    var remaining: Int { Self.maxTokens - used }

    /// Rough estimate: ~4 characters per token
    static func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// Allocate text within the budget, truncating if needed
    mutating func allocate(_ text: String) -> String {
        let tokens = Self.estimateTokens(text)
        if tokens <= remaining {
            used += tokens
            return text
        }
        let charLimit = remaining * 4
        used = Self.maxTokens
        if charLimit <= 0 { return "" }
        return String(text.prefix(charLimit)) + "..."
    }

    /// Check if there's room for approximately this many items at a given detail level
    func canFit(itemCount: Int, detailLevel: ToolDetailLevel) -> Bool {
        let tokensPerItem: Int
        switch detailLevel {
        case .brief: tokensPerItem = 15
        case .normal: tokensPerItem = 30
        case .full: tokensPerItem = 80
        }
        return remaining >= itemCount * tokensPerItem
    }

    /// Suggest detail level based on how many items need to fit
    static func suggestDetailLevel(itemCount: Int, availableTokens: Int = maxTokens) -> ToolDetailLevel {
        if itemCount * 80 <= availableTokens { return .full }
        if itemCount * 30 <= availableTokens { return .normal }
        return .brief
    }
}
