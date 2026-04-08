//
//  DayPlanWorkflow.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Day Plan Result

@available(iOS 26, *)
struct DayPlanResult: Sendable {
    let items: [DayPlanEntry]
    let summary: String
}

@available(iOS 26, *)
struct DayPlanEntry: Sendable {
    let uid: String
    let name: String
    let startTime: String
    let endTime: String
    let reason: String
    let walkMinutesFromPrevious: Int?
}

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableDayPlanSelection {
    @Guide(description: "Selected event UIDs in chronological order", .count(3...10))
    var selectedUIDs: [String]
    @Guide(description: "One-sentence theme for the day")
    var dayTheme: String
}

@available(iOS 26, *)
@Generable
struct GenerableDayPlanNote {
    @Guide(description: "Event name this note is for")
    var eventName: String
    @Guide(description: "One-sentence transition note about what to expect")
    var note: String
}

@available(iOS 26, *)
@Generable
struct GenerableDayPlanNarrative {
    @Guide(description: "Transition notes, one per event", .count(1...10))
    var transitionNotes: [GenerableDayPlanNote]
    @Guide(description: "Overall day summary, one sentence")
    var summary: String
}

// MARK: - Day Plan Workflow

@available(iOS 26, *)
struct DayPlanWorkflow: Workflow {
    let name = "Day Planner"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> DayPlanResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")

        // Step 1: Get favorites to understand taste
        onProgress(.stepStarted(name: "taste", description: "Understanding your interests..."))
        let favorites = try await context.playaDB.getFavorites()
        let tasteKeywords = extractKeywords(from: favorites)
        onProgress(.stepCompleted(name: "taste"))

        // Step 2: Fetch today's events matching taste
        onProgress(.stepStarted(name: "events", description: "Finding today's events..."))
        var allCandidates: [EventObjectOccurrence] = []

        // Fetch upcoming events (next 12 hours)
        let upcoming = try await context.playaDB.fetchUpcomingEvents(within: 12, from: context.date)
        allCandidates.append(contentsOf: upcoming)

        // Also search by taste keywords
        for keyword in tasteKeywords.prefix(3) {
            var filter = EventFilter.all
            filter.searchText = keyword
            filter.startingWithinHours = 12
            let results = try await context.playaDB.fetchEvents(filter: filter)
            allCandidates.append(contentsOf: results)
        }

        // Deduplicate by event UID
        var seen = Set<String>()
        allCandidates = allCandidates.filter { seen.insert($0.event.uid).inserted }
        onProgress(.stepCompleted(name: "events"))

        guard !allCandidates.isEmpty else {
            return DayPlanResult(items: [], summary: "No events found for today.")
        }

        // Step 3: Detect conflicts
        onProgress(.stepStarted(name: "optimize", description: "Optimizing your schedule..."))
        let conflicts = detectConflicts(allCandidates)

        // Step 4: LLM selects best events
        let candidateText = allCandidates.prefix(20).map { occ in
            let time = formatter.string(from: occ.startDate)
            let desc = occ.event.description?.prefix(60) ?? ""
            return "\(occ.event.name) at \(time) - \(desc) (uid: \(occ.event.uid))"
        }.joined(separator: "\n")

        var selectionPrompt = "Select 5-8 events for a great day. Order by time."
        if !conflicts.isEmpty {
            let conflictText = conflicts.prefix(3).map { "\($0.0.event.name) vs \($0.1.event.name)" }.joined(separator: ", ")
            selectionPrompt += " Resolve these conflicts by picking the better one: \(conflictText)"
        }
        if !tasteKeywords.isEmpty {
            selectionPrompt += " User likes: \(tasteKeywords.joined(separator: ", "))"
        }

        let session = LanguageModelSession(instructions: """
            You are scheduling a day at Burning Man. Pick the best events \
            that create a balanced, enjoyable day. Mix familiar interests \
            with new discoveries. Resolve any time conflicts.
            """)

        let selection = try await session.respond(
            to: Prompt("Available events:\n\(candidateText)\n\n\(selectionPrompt)"),
            generating: GenerableDayPlanSelection.self
        )
        onProgress(.stepCompleted(name: "optimize"))

        // Step 5: Calculate walk times
        onProgress(.stepStarted(name: "route", description: "Calculating walking routes..."))
        let selectedUIDs = selection.content.selectedUIDs
        let selectedEvents = selectedUIDs.compactMap { uid in
            allCandidates.first { $0.event.uid == uid }
        }

        var entries: [DayPlanEntry] = []
        var previousCoord: CLLocationCoordinate2D? = context.location?.coordinate

        for event in selectedEvents {
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)

            var walkMin: Int? = nil
            if let prevCoord = previousCoord,
               let lat = event.event.gpsLatitude, let lon = event.event.gpsLongitude {
                let eventCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                walkMin = playaWalkMinutes(from: prevCoord, to: eventCoord)
                previousCoord = eventCoord
            }

            entries.append(DayPlanEntry(
                uid: event.event.uid,
                name: event.event.name,
                startTime: startTime,
                endTime: endTime,
                reason: "",
                walkMinutesFromPrevious: walkMin
            ))
        }
        onProgress(.stepCompleted(name: "route"))

        // Step 6: LLM generates transition notes
        onProgress(.stepStarted(name: "narrative", description: "Writing your day plan..."))
        let scheduleText = entries.map { entry in
            var line = "\(entry.startTime)-\(entry.endTime): \(entry.name)"
            if let walk = entry.walkMinutesFromPrevious { line += " (~\(walk) min walk)" }
            return line
        }.joined(separator: "\n")

        let narrativeSession = LanguageModelSession(instructions: """
            Write brief, fun transition notes for a Burning Man day schedule. \
            Each note should be one sentence about what to expect or why it's exciting.
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Schedule:\n\(scheduleText)\n\nWrite one transition note per event and an overall summary."),
            generating: GenerableDayPlanNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        // Merge notes into entries by matching event name
        let notesByName = Dictionary(narrative.content.transitionNotes.map { ($0.eventName.lowercased(), $0.note) }, uniquingKeysWith: { first, _ in first })
        let finalEntries = entries.map { entry in
            DayPlanEntry(
                uid: entry.uid,
                name: entry.name,
                startTime: entry.startTime,
                endTime: entry.endTime,
                reason: notesByName[entry.name.lowercased()] ?? "",
                walkMinutesFromPrevious: entry.walkMinutesFromPrevious
            )
        }

        return DayPlanResult(
            items: finalEntries,
            summary: narrative.content.summary.isEmpty ? selection.content.dayTheme : narrative.content.summary
        )
    }

    private func extractKeywords(from favorites: [Any]) -> [String] {
        extractTasteKeywords(favorites)
    }
}

#endif
