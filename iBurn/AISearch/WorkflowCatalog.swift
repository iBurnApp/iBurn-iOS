//
//  WorkflowCatalog.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// Describes a workflow available in the AI Guide
struct WorkflowInfo: Identifiable {
    let id: WorkflowID
    let title: String
    let subtitle: String
    let icon: String
    let section: WorkflowSection
}

enum WorkflowID: String, CaseIterable {
    case forYou
    case surpriseMe
    case whatDidIMiss
    case dayPlanner
    case adventure
    case campCrawl
    case goldenHour
    case scheduleOptimizer
}

enum WorkflowSection: String, CaseIterable {
    case discover = "Discover"
    case plan = "Plan"
    case optimize = "Optimize"
}

/// The full catalog of available workflows
enum WorkflowCatalog {
    static let all: [WorkflowInfo] = [
        // Discover
        WorkflowInfo(
            id: .forYou,
            title: "For You",
            subtitle: "Personalized picks based on your favorites",
            icon: "sparkles",
            section: .discover
        ),
        WorkflowInfo(
            id: .surpriseMe,
            title: "Surprise Me",
            subtitle: "Roll the dice and discover something unexpected",
            icon: "dice",
            section: .discover
        ),
        WorkflowInfo(
            id: .whatDidIMiss,
            title: "What Did I Miss?",
            subtitle: "Things you walked past but didn't stop at",
            icon: "eye.slash",
            section: .discover
        ),

        // Plan
        WorkflowInfo(
            id: .dayPlanner,
            title: "Day Planner",
            subtitle: "AI-optimized schedule with walking routes",
            icon: "calendar.badge.clock",
            section: .plan
        ),
        WorkflowInfo(
            id: .adventure,
            title: "Adventure Generator",
            subtitle: "Themed playa tours with stops and tips",
            icon: "map",
            section: .plan
        ),
        WorkflowInfo(
            id: .campCrawl,
            title: "Camp Crawl",
            subtitle: "Themed camp-hopping with events at each stop",
            icon: "figure.walk",
            section: .plan
        ),
        WorkflowInfo(
            id: .goldenHour,
            title: "Golden Hour Art",
            subtitle: "Art that glows at sunrise or sunset",
            icon: "sun.horizon",
            section: .plan
        ),

        // Optimize
        WorkflowInfo(
            id: .scheduleOptimizer,
            title: "Schedule Optimizer",
            subtitle: "Resolve conflicts in your favorited events",
            icon: "calendar.badge.checkmark",
            section: .optimize
        ),
    ]

    static func workflows(for section: WorkflowSection) -> [WorkflowInfo] {
        all.filter { $0.section == section }
    }
}
