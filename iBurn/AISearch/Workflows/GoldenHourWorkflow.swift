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
        let selectedUIDs = selection.stops.compactMap { artIdMap[$0.number]?.uid }
        let reasonMap = Dictionary(selection.stops.compactMap { stop -> (String, String)? in
            guard let art = artIdMap[stop.number] else { return nil }
            return (art.uid, stop.reason)
        }, uniquingKeysWith: { first, _ in first })

        var stopsWithCoords: [(uid: String, coord: CLLocationCoordinate2D)] = []
        var artNames: [String: String] = [:]

        for uid in selectedUIDs {
            if let art = artWithGPS.first(where: { $0.uid == uid }),
               let lat = art.gpsLatitude, let lon = art.gpsLongitude {
                stopsWithCoords.append((uid: uid, coord: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                artNames[uid] = art.name
            }
        }

        let optimized = optimizeRoute(from: context.location?.coordinate, stops: stopsWithCoords)

        var totalWalkMinutes = 0
        var routeStops: [RouteStop] = []
        var previousCoord: CLLocationCoordinate2D? = context.location?.coordinate

        for stop in optimized {
            var walkMin: Int? = nil
            if let prev = previousCoord {
                walkMin = playaWalkMinutes(from: prev, to: stop.coord)
                totalWalkMinutes += walkMin ?? 0
                previousCoord = stop.coord
            }

            routeStops.append(RouteStop(
                id: stop.uid,
                name: artNames[stop.uid] ?? stop.uid,
                type: .art,
                reason: reasonMap[stop.uid] ?? "",
                walkMinutesFromPrevious: walkMin,
                latitude: stop.coord.latitude,
                longitude: stop.coord.longitude
            ))
        }
        onProgress(.stepCompleted(name: "route"))

        // Generate narrative
        onProgress(.stepStarted(name: "narrative", description: "Setting the mood..."))
        let narrativeSession = LanguageModelSession(instructions: """
            Write an evocative intro for a golden hour art tour at Burning Man. \
            Target: \(targetTime). Be poetic but concise.
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Art route for \(targetTime): \(routeStops.map(\.name).joined(separator: " -> "))"),
            generating: GenerableGoldenHourNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        return RouteResult(
            stops: routeStops,
            narrative: narrative.content.intro + "\n\nLeave ~30 min before \(targetTime) to reach the first stop. Total walk: ~\(totalWalkMinutes) min.",
            totalWalkMinutes: totalWalkMinutes
        )
    }
}

#endif
