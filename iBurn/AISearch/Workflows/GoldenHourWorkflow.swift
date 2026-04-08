//
//  GoldenHourWorkflow.swift
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
struct GenerableGoldenHourStop {
    @Guide(description: "Art number from the list")
    var number: Int
    @Guide(description: "Why this art is great at golden hour")
    var reason: String
}

@available(iOS 26, *)
@Generable
struct GenerableGoldenHourSelection {
    @Guide(description: "Selected art for golden hour viewing", .count(3...6))
    var stops: [GenerableGoldenHourStop]
}

@available(iOS 26, *)
@Generable
struct GenerableGoldenHourNarrative {
    @Guide(description: "Evocative two-sentence intro about golden hour on the playa")
    var intro: String
}

// MARK: - Golden Hour Workflow

@available(iOS 26, *)
struct GoldenHourWorkflow: Workflow {
    let name = "Golden Hour Planner"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> RouteResult {
        // Step 1: Calculate sunrise/sunset
        onProgress(.stepStarted(name: "sun", description: "Calculating golden hour..."))
        let sunTimes = brcSunTimes(for: context.date)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let sunriseStr = formatter.string(from: sunTimes.sunrise)
        let sunsetStr = formatter.string(from: sunTimes.sunset)

        // Determine if we're closer to sunrise or sunset
        let now = context.date
        let toSunrise = sunTimes.sunrise.timeIntervalSince(now)
        let toSunset = sunTimes.sunset.timeIntervalSince(now)
        let targetTime: String
        if toSunrise > 0 && toSunrise < toSunset {
            targetTime = "sunrise at \(sunriseStr)"
        } else {
            targetTime = "sunset at \(sunsetStr)"
        }
        onProgress(.stepCompleted(name: "sun"))

        // Step 2: Fetch art installations (preferring open playa / large-scale)
        onProgress(.stepStarted(name: "art", description: "Finding art for golden hour..."))
        let allArt = try await context.playaDB.fetchArt()

        // Prefer art that's likely large-scale or in open playa
        // We don't have explicit size data, but we can check location_category
        // and whether they have GPS coordinates (placed art)
        let artWithGPS = allArt.filter { $0.gpsLatitude != nil && $0.gpsLongitude != nil }
        onProgress(.stepCompleted(name: "art"))

        guard !artWithGPS.isEmpty else {
            return RouteResult(stops: [], narrative: "No art with location data found.", totalWalkMinutes: 0)
        }

        // Step 3: LLM selects art best for golden hour (numeric IDs to save tokens)
        onProgress(.stepStarted(name: "curate", description: "Curating golden hour art..."))
        let artSlice = Array(artWithGPS.prefix(18))
        let artIdMap = Dictionary(uniqueKeysWithValues: artSlice.enumerated().map { ($0.offset + 1, $0.element) })

        let selection: GenerableGoldenHourSelection = try await retryWithCandidateFiltering(
            candidates: Array(artSlice.enumerated()),
            format: { "\($0.element.name)" }
        ) { batch in
            let text = batch.map { idx, art in
                let cat = art.category ?? ""
                return "\(idx + 1). \(art.name)\(cat.isEmpty ? "" : " (\(cat))")"
            }.joined(separator: "\n")
            let session = LanguageModelSession(instructions: """
                Pick art for \(targetTime) viewing. Prefer large sculptures, reflective pieces, fire art. Use numbers.
                """)
            return try await session.respond(
                to: Prompt("Art:\n\(text)"),
                generating: GenerableGoldenHourSelection.self
            ).content
        }
        onProgress(.stepCompleted(name: "curate"))

        // Step 4: Calculate route — map numeric IDs back
        onProgress(.stepStarted(name: "route", description: "Planning your golden hour route..."))
        let routeSelections = selection.stops.compactMap { stop -> (uid: String, reason: String, typeOverride: DataObjectType?)? in
            guard let art = artIdMap[stop.number] else { return nil }
            return (uid: art.uid, reason: stop.reason, typeOverride: .art)
        }
        let route = await buildRoute(
            selections: routeSelections,
            startLocation: context.location?.coordinate,
            playaDB: context.playaDB
        )
        onProgress(.stepCompleted(name: "route"))

        // Generate narrative
        onProgress(.stepStarted(name: "narrative", description: "Setting the mood..."))
        let narrativeSession = LanguageModelSession(instructions: """
            Evocative golden hour art tour intro. Target: \(targetTime). Be poetic, concise.
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Art route: \(route.stops.map(\.name).joined(separator: " -> "))"),
            generating: GenerableGoldenHourNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        return RouteResult(
            stops: route.stops,
            narrative: narrative.content.intro + "\n\nLeave ~30 min before \(targetTime). Total walk: ~\(route.totalWalkMinutes) min.",
            totalWalkMinutes: route.totalWalkMinutes
        )
    }
}

#endif
