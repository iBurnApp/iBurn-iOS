//
//  AdventureWorkflow.swift
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

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableKeywords {
    @Guide(description: "Search keywords extracted from the theme", .count(2...5))
    var keywords: [String]
}

@available(iOS 26, *)
@Generable
struct GenerableSelectedStop {
    @Guide(description: "Stop number from the list")
    var number: Int
    @Guide(description: "Brief reason why this stop was selected")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableStopSelection {
    @Guide(description: "Selected stops for the adventure", .count(3...7))
    var stops: [GenerableSelectedStop]
}

@available(iOS 26, *)
@Generable
struct GenerableAdventureTip {
    @Guide(description: "Name of the stop this tip is for")
    var stopName: String
    @Guide(description: "One-line visit tip for this stop")
    var tip: String
}

@available(iOS 26, *)
@Generable
struct GenerableAdventureNarrative {
    @Guide(description: "Two-sentence adventure intro setting the mood")
    var intro: String
    @Guide(description: "Visit tips, one per stop", .count(1...8))
    var tips: [GenerableAdventureTip]
}

// MARK: - Adventure Workflow

@available(iOS 26, *)
struct AdventureWorkflow: Workflow {
    let theme: String
    let name = "Adventure Generator"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> RouteResult {
        // Step 1: Extract theme keywords via LLM
        onProgress(.stepStarted(name: "theme", description: "Understanding your adventure theme..."))
        let keywordSession = LanguageModelSession(instructions: """
            Extract search keywords from a Burning Man adventure theme request. \
            Return diverse keywords that would find relevant art, camps, and events.
            """)
        let keywords = try await keywordSession.respond(
            to: Prompt("Theme: \(theme)"),
            generating: GenerableKeywords.self
        )
        onProgress(.stepCompleted(name: "theme"))

        // Step 2: Parallel DB queries with keywords (brief detail)
        onProgress(.stepStarted(name: "search", description: "Exploring the playa..."))
        var allCandidates: [Any] = []

        for keyword in keywords.content.keywords {
            let results = try await context.playaDB.searchObjects(keyword)
            allCandidates.append(contentsOf: results)
        }

        // Deduplicate by UID
        var seen = Set<String>()
        allCandidates = allCandidates.filter { obj in
            guard let uid = objectUID(obj) else { return false }
            return seen.insert(uid).inserted
        }
        onProgress(.stepCompleted(name: "search"))

        guard !allCandidates.isEmpty else {
            return RouteResult(stops: [], narrative: "Couldn't find enough items for this adventure theme.", totalWalkMinutes: 0)
        }

        // Step 3: LLM selects best stops (numeric IDs to save tokens)
        onProgress(.stepStarted(name: "curate", description: "Curating the best stops..."))
        let candidateSlice = Array(allCandidates.prefix(18))
        let objIdMap = Dictionary(uniqueKeysWithValues: candidateSlice.enumerated().map { ($0.offset + 1, $0.element) })

        let selection: GenerableStopSelection = try await retryWithCandidateFiltering(
            candidates: Array(candidateSlice.enumerated()),
            format: { objectName($0.element) ?? "unknown" }
        ) { batch in
            let text = batch.map { idx, obj in
                "\(idx + 1). \(formatObject(obj, detail: .brief))"
            }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                Pick 4-7 stops for a "\(theme)" Burning Man adventure. Mix types. Use the numbers.
                """)
            return try await session.respond(
                to: Prompt("Stops:\n\(text)"),
                generating: GenerableStopSelection.self
            ).content
        }
        onProgress(.stepCompleted(name: "curate"))

        // Step 4: Build optimized route
        onProgress(.stepStarted(name: "route", description: "Optimizing your route..."))
        let routeSelections = selection.stops.compactMap { stop -> (uid: String, reason: String, typeOverride: DataObjectType?)? in
            guard let obj = objIdMap[stop.number], let uid = objectUID(obj) else { return nil }
            return (uid: uid, reason: stop.reason, typeOverride: nil)
        }
        let route = await buildRoute(
            selections: routeSelections,
            startLocation: context.location?.coordinate,
            playaDB: context.playaDB
        )
        onProgress(.stepCompleted(name: "route"))

        // Step 5: Generate narrative with tips
        onProgress(.stepStarted(name: "narrative", description: "Writing your adventure..."))
        let stopsText = route.stops.enumerated().map { idx, stop in
            "\(idx + 1). \(stop.name) (\(stop.type.rawValue))"
        }.joined(separator: "\n")

        let narrativeSession = LanguageModelSession(instructions: """
            Write a fun adventure intro and one tip per stop. Theme: "\(theme)".
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Stops:\n\(stopsText)"),
            generating: GenerableAdventureNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        // Merge tips into stops
        let finalStops = mergeNotesByName(
            entries: route.stops,
            notes: narrative.content.tips.map { (name: $0.stopName, text: $0.tip) },
            entryName: { $0.name },
            merge: { stop, tip in
                RouteStop(id: stop.id, name: stop.name, type: stop.type, reason: tip,
                          walkMinutesFromPrevious: stop.walkMinutesFromPrevious,
                          latitude: stop.latitude, longitude: stop.longitude)
            }
        )

        return RouteResult(
            stops: finalStops,
            narrative: narrative.content.intro,
            totalWalkMinutes: route.totalWalkMinutes
        )
    }
}

#endif
