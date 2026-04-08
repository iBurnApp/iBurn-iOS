//
//  ScheduleOptimizerWorkflow.swift
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

// MARK: - Schedule Optimizer Result

@available(iOS 26, *)
struct ScheduleOptimizerResult: Sendable {
    let items: [DayPlanEntry]
    let summary: String
    let conflictsResolved: Int
}

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableConflictResolution {
    @Guide(description: "UID of the event to keep")
    var keepUID: String
    @Guide(description: "Brief reason for keeping this one over the other")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableScheduleNote {
    @Guide(description: "Event name this note is for")
    var eventName: String
    @Guide(description: "Brief note about what to expect at this event")
    var note: String
}

@available(iOS 26, *)
@Generable
struct GenerableScheduleSummary {
    @Guide(description: "One-sentence summary of the optimized schedule")
    var summary: String
    @Guide(description: "Notes about events", .count(1...10))
    var notes: [GenerableScheduleNote]
}

// MARK: - Schedule Optimizer Workflow

@available(iOS 26, *)
struct ScheduleOptimizerWorkflow: Workflow {
    let name = "Schedule Optimizer"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> ScheduleOptimizerResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")

        // Step 1: Fetch all favorited events with occurrences
        onProgress(.stepStarted(name: "favorites", description: "Loading your favorited events..."))
        let favoriteEvents = try await context.playaDB.fetchFavoriteEvents()
        onProgress(.stepCompleted(name: "favorites"))

        guard !favoriteEvents.isEmpty else {
            return ScheduleOptimizerResult(
                items: [],
                summary: "No favorited events found. Favorite some events first!",
                conflictsResolved: 0
            )
        }

        // Step 2: Detect time conflicts (pure Swift)
        onProgress(.stepStarted(name: "conflicts", description: "Analyzing schedule conflicts..."))
        let conflicts = detectConflicts(favoriteEvents)
        onProgress(.stepCompleted(name: "conflicts"))

        // Step 3: Calculate walk times between consecutive events
        onProgress(.stepStarted(name: "walkTimes", description: "Calculating walking routes..."))
        let sortedEvents = favoriteEvents.sorted { $0.startDate < $1.startDate }
        onProgress(.stepCompleted(name: "walkTimes"))

        // Step 4: Resolve conflicts via LLM
        var removedUIDs = Set<String>()
        var conflictsResolved = 0

        if !conflicts.isEmpty {
            onProgress(.stepStarted(name: "resolve", description: "Resolving \(conflicts.count) conflict(s)..."))

            for (eventA, eventB) in conflicts {
                // Skip if one was already removed
                guard !removedUIDs.contains(eventA.event.uid) && !removedUIDs.contains(eventB.event.uid) else { continue }

                let timeA = formatter.string(from: eventA.startDate)
                let timeB = formatter.string(from: eventB.startDate)

                let conflictPrompt = """
                    Overlap: A) \(eventA.event.name) at \(timeA) (\(eventA.event.eventTypeLabel)) uid:\(eventA.event.uid)
                    B) \(eventB.event.name) at \(timeB) (\(eventB.event.eventTypeLabel)) uid:\(eventB.event.uid)
                    """

                let session = LanguageModelSession(instructions: """
                    Pick the more unique/time-sensitive event to keep.
                    """)
                let resolution = try await session.respond(
                    to: Prompt(conflictPrompt),
                    generating: GenerableConflictResolution.self
                )

                let removeUID = resolution.content.keepUID == eventA.event.uid ? eventB.event.uid : eventA.event.uid
                removedUIDs.insert(removeUID)
                conflictsResolved += 1
            }
            onProgress(.stepCompleted(name: "resolve"))
        }

        // Build final schedule (filter out removed events)
        let finalEvents = sortedEvents.filter { !removedUIDs.contains($0.event.uid) }

        // Calculate walk times for final schedule
        var entries: [DayPlanEntry] = []
        var previousCoord: CLLocationCoordinate2D? = context.location?.coordinate

        for event in finalEvents {
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

        // Step 5: Generate summary via LLM
        onProgress(.stepStarted(name: "summary", description: "Writing your optimized schedule..."))
        let scheduleText = entries.map { "\($0.startTime): \($0.name)" }.joined(separator: "\n")

        let summarySession = LanguageModelSession(instructions: """
            Summarize an optimized Burning Man schedule. Note what to expect at each event.
            """)
        let summary = try await summarySession.respond(
            to: Prompt("Schedule:\n\(scheduleText)\n\nConflicts resolved: \(conflictsResolved)"),
            generating: GenerableScheduleSummary.self
        )
        onProgress(.stepCompleted(name: "summary"))

        // Merge notes into entries by matching event name
        let finalEntries = mergeNotesByName(
            entries: entries,
            notes: summary.content.notes.map { (name: $0.eventName, text: $0.note) },
            entryName: { $0.name },
            merge: { entry, note in
                DayPlanEntry(uid: entry.uid, name: entry.name, startTime: entry.startTime,
                             endTime: entry.endTime, reason: note,
                             walkMinutesFromPrevious: entry.walkMinutesFromPrevious)
            }
        )

        return ScheduleOptimizerResult(
            items: finalEntries,
            summary: summary.content.summary,
            conflictsResolved: conflictsResolved
        )
    }
}

#endif
