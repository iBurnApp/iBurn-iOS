//
//  CampCrawlWorkflow.swift
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
struct GenerableCampStop {
    @Guide(description: "Camp number from the list")
    var number: Int
    @Guide(description: "Brief visit tip for this camp")
    var tip: String
}

@available(iOS 26, *)
@Generable
struct GenerableCampSelection {
    @Guide(description: "Selected camps for the crawl", .count(3...6))
    var camps: [GenerableCampStop]
}

@available(iOS 26, *)
@Generable
struct GenerableCrawlNarrative {
    @Guide(description: "Fun two-sentence intro for the camp crawl")
    var intro: String
}

// MARK: - Camp Crawl Workflow

@available(iOS 26, *)
struct CampCrawlWorkflow: Workflow {
    let theme: String
    let name = "Camp Crawl"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> RouteResult {
        // Step 1: Parse theme keywords
        onProgress(.stepStarted(name: "theme", description: "Planning your camp crawl..."))
        let keywordSession = LanguageModelSession(instructions: """
            Extract search keywords for finding themed camps at Burning Man.
            """)
        let keywords = try await keywordSession.respond(
            to: Prompt("Camp crawl theme: \(theme)"),
            generating: GenerableKeywords.self
        )
        onProgress(.stepCompleted(name: "theme"))

        // Step 2: Search camps by theme
        onProgress(.stepStarted(name: "search", description: "Finding camps..."))
        var campCandidates: [CampObject] = []

        for keyword in keywords.content.keywords {
            var filter = CampFilter.all
            filter.searchText = keyword
            let results = try await context.playaDB.fetchCamps(filter: filter)
            campCandidates.append(contentsOf: results)
        }

        // Deduplicate
        var seen = Set<String>()
        campCandidates = campCandidates.filter { seen.insert($0.uid).inserted }
        onProgress(.stepCompleted(name: "search"))

        guard !campCandidates.isEmpty else {
            return RouteResult(stops: [], narrative: "Couldn't find camps matching '\(theme)'.", totalWalkMinutes: 0)
        }

        // Step 3: Fetch hosted events for top camps
        onProgress(.stepStarted(name: "events", description: "Checking what's happening at each camp..."))
        var campEventInfo: [String: String] = [:]

        for camp in campCandidates.prefix(10) {
            let events = try await context.playaDB.fetchEvents(hostedByCampUID: camp.uid)
            if !events.isEmpty {
                let eventNames = events.prefix(3).map(\.event.name).joined(separator: ", ")
                campEventInfo[camp.uid] = eventNames
            }
        }
        onProgress(.stepCompleted(name: "events"))

        // Step 4: LLM selects best camps (numeric IDs to save tokens)
        onProgress(.stepStarted(name: "curate", description: "Curating the best stops..."))
        let candidateSlice = Array(campCandidates.prefix(15))
        let campIdMap = Dictionary(uniqueKeysWithValues: candidateSlice.enumerated().map { ($0.offset + 1, $0.element) })

        let selection: GenerableCampSelection = try await retryWithCandidateFiltering(
            candidates: Array(candidateSlice.enumerated()),
            format: { "\($0.element.name)" }
        ) { batch in
            let text = batch.map { idx, camp in
                let events = campEventInfo[camp.uid].map { " events: \($0)" } ?? ""
                return "\(idx + 1). \(camp.name)\(events)"
            }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                Pick 4-6 camps for a "\(theme)" camp crawl. Use the numbers.
                """)
            return try await session.respond(
                to: Prompt("Camps:\n\(text)"),
                generating: GenerableCampSelection.self
            ).content
        }
        onProgress(.stepCompleted(name: "curate"))

        // Step 5: Build optimized route
        onProgress(.stepStarted(name: "route", description: "Building your route..."))
        let routeSelections = selection.camps.compactMap { stop -> (uid: String, reason: String, typeOverride: DataObjectType?)? in
            guard let camp = campIdMap[stop.number] else { return nil }
            return (uid: camp.uid, reason: stop.tip, typeOverride: .camp)
        }
        let route = await buildRoute(
            selections: routeSelections,
            startLocation: context.location?.coordinate,
            playaDB: context.playaDB
        )
        onProgress(.stepCompleted(name: "route"))

        // Step 6: Generate narrative
        onProgress(.stepStarted(name: "narrative", description: "Writing your crawl guide..."))
        let stopsText = route.stops.map(\.name).joined(separator: " -> ")
        let narrativeSession = LanguageModelSession(instructions: """
            Write a fun, short intro for a "\(theme)" camp crawl.
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Route: \(stopsText)"),
            generating: GenerableCrawlNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        return RouteResult(
            stops: route.stops,
            narrative: narrative.content.intro,
            totalWalkMinutes: route.totalWalkMinutes
        )
    }

}

#endif
