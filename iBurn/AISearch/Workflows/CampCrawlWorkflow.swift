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
    @Guide(description: "Camp UID")
    var uid: String
    @Guide(description: "Brief visit tip for this specific camp")
    var tip: String
}

@available(iOS 26, *)
@Generable
struct GenerableCampSelection {
    @Guide(description: "Selected camps for the crawl, each with its UID and tip", .count(3...6))
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

        // Step 4: LLM selects best camps (with retry, filtering problematic candidates)
        onProgress(.stepStarted(name: "curate", description: "Curating the best stops..."))
        let selection: GenerableCampSelection = try await retryWithCandidateFiltering(
            candidates: Array(campCandidates.prefix(12)),
            format: { $0.name }
        ) { batch in
            let text = batch.map { camp in
                let desc = camp.description?.prefix(60) ?? ""
                let events = campEventInfo[camp.uid].map { " | Events: \($0)" } ?? ""
                return "camp: \(camp.name) - \(desc)\(events) (uid: \(camp.uid))"
            }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                Select 3-\(min(6, batch.count)) camps for a themed camp crawl. Theme: "\(theme)". \
                Prefer camps with interesting events. Order for a good experience flow.
                """)
            return try await session.respond(
                to: Prompt("Candidates:\n\(text)"),
                generating: GenerableCampSelection.self
            ).content
        }
        onProgress(.stepCompleted(name: "curate"))

        // Step 5: Calculate walking route
        onProgress(.stepStarted(name: "route", description: "Building your route..."))
        let selectedUIDs = selection.camps.map(\.uid)
        let tipMap = Dictionary(selection.camps.map { ($0.uid, $0.tip) }, uniquingKeysWith: { first, _ in first })

        var stopsWithCoords: [(uid: String, coord: CLLocationCoordinate2D)] = []
        var campNames: [String: String] = [:]

        for uid in selectedUIDs {
            if let camp = campCandidates.first(where: { $0.uid == uid }),
               let lat = camp.gpsLatitude, let lon = camp.gpsLongitude {
                stopsWithCoords.append((uid: uid, coord: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                campNames[uid] = camp.name
            } else if let camp = campCandidates.first(where: { $0.uid == uid }) {
                campNames[uid] = camp.name
            }
        }

        let optimized = optimizeRoute(from: context.location?.coordinate, stops: stopsWithCoords)
        let optimizedUIDs = optimized.map(\.uid) + selectedUIDs.filter { uid in !optimized.contains(where: { $0.uid == uid }) }

        var totalWalkMinutes = 0
        var routeStops: [RouteStop] = []
        var previousCoord: CLLocationCoordinate2D? = context.location?.coordinate

        for uid in optimizedUIDs {
            let coord = optimized.first(where: { $0.uid == uid })?.coord

            var walkMin: Int? = nil
            if let prev = previousCoord, let curr = coord {
                walkMin = playaWalkMinutes(from: prev, to: curr)
                totalWalkMinutes += walkMin ?? 0
                previousCoord = curr
            }

            routeStops.append(RouteStop(
                id: uid,
                name: campNames[uid] ?? uid,
                type: .camp,
                reason: tipMap[uid] ?? "",
                walkMinutesFromPrevious: walkMin,
                latitude: coord?.latitude,
                longitude: coord?.longitude
            ))
        }
        onProgress(.stepCompleted(name: "route"))

        // Step 6: Generate narrative
        onProgress(.stepStarted(name: "narrative", description: "Writing your crawl guide..."))
        let narrativeSession = LanguageModelSession(instructions: """
            Write a fun, short intro for a Burning Man camp crawl. Theme: "\(theme)".
            """)
        let stopsText = routeStops.map(\.name).joined(separator: " -> ")
        let narrative = try await narrativeSession.respond(
            to: Prompt("Camp crawl route: \(stopsText)"),
            generating: GenerableCrawlNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        return RouteResult(
            stops: routeStops,
            narrative: narrative.content.intro,
            totalWalkMinutes: totalWalkMinutes
        )
    }

}

#endif
