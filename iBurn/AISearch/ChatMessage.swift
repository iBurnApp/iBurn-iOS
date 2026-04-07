//
//  ChatMessage.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
@preconcurrency import PlayaDB

// MARK: - Chat Message

struct ChatMessage: Identifiable, Sendable {
    let id: UUID
    let role: Role
    let content: MessageContent
    let timestamp: Date

    init(role: Role, content: MessageContent) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    enum Role: Sendable {
        case user
        case assistant
        case system
    }

    enum MessageContent: Sendable {
        case text(String)
        case objectCards([ObjectCard])
        case schedule(ScheduleResult)
        case adventure(AdventureResult)
        case quickActions([QuickAction])
        case loading(String)
        case error(String)
    }
}

// MARK: - Object Card

struct ObjectCard: Identifiable, Sendable {
    var id: String { uid }
    let uid: String
    let name: String
    let type: DataObjectType
    let reason: String
    let distance: String?
    let timeInfo: String?
}

// MARK: - Schedule Result

struct ScheduleResult: Sendable {
    let entries: [ScheduleResultEntry]
    let summary: String
    let conflictsResolved: Int
}

struct ScheduleResultEntry: Identifiable, Sendable {
    var id: String { uid }
    let uid: String
    let name: String
    let startTime: String
    let endTime: String
    let reason: String
    let walkMinutesFromPrevious: Int?
}

// MARK: - Adventure Result

struct AdventureResult: Sendable {
    let narrative: String
    let stops: [AdventureStop]
    let totalWalkMinutes: Int
}

struct AdventureStop: Identifiable, Sendable {
    var id: String { uid }
    let uid: String
    let name: String
    let type: DataObjectType
    let tip: String
    let walkMinutesFromPrevious: Int?
}

// MARK: - Quick Action

struct QuickAction: Identifiable, Sendable {
    let id: UUID
    let label: String
    let prompt: String
    let icon: String

    init(label: String, prompt: String, icon: String) {
        self.id = UUID()
        self.label = label
        self.prompt = prompt
        self.icon = icon
    }
}

// MARK: - Quick Start Presets

extension QuickAction {
    static let quickStartActions: [QuickAction] = [
        QuickAction(label: "Surprise Me", prompt: "Surprise me with something unexpected", icon: "dice"),
        QuickAction(label: "Plan Adventure", prompt: "Plan a playa adventure for me", icon: "map"),
        QuickAction(label: "Optimize Schedule", prompt: "Optimize my schedule and resolve conflicts", icon: "calendar.badge.checkmark"),
        QuickAction(label: "Camp Crawl", prompt: "Plan a themed camp crawl", icon: "figure.walk"),
        QuickAction(label: "What Did I Miss?", prompt: "What interesting things did I walk past but miss?", icon: "eye.slash"),
        QuickAction(label: "Golden Hour Art", prompt: "Plan a golden hour art viewing route", icon: "sun.horizon"),
    ]
}
