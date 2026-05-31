//
//  EventSummaryCache.swift
//  iBurn
//
//  In-memory cache for AI-generated event summaries, keyed by host UID.
//

import Foundation

/// Actor-based RAM cache for AI event summaries.
/// Thread-safe and matches the async/await calling pattern used by the workflow pipeline.
actor EventSummaryCache {
    static let shared = EventSummaryCache()

    private var cache: [String: EventSummaryContent] = [:]

    func get(_ hostUID: String) -> EventSummaryContent? {
        cache[hostUID]
    }

    func set(_ hostUID: String, content: EventSummaryContent) {
        cache[hostUID] = content
    }
}
