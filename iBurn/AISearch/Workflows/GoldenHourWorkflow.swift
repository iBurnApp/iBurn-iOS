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
struct GenerableGoldenHourSelection {
    @Guide(description: "Selected art UIDs best for golden hour viewing", .count(3...6))
    var selectedUIDs: [String]
    @Guide(description: "Why each art is great at golden hour, same order as UIDs", .count(3...6))
    var reasons: [String]
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

        // Step 3: LLM selects art best for golden hour
        onProgress(.stepStarted(name: "curate", description: "Curating golden hour art..."))
        let candidateText = artWithGPS.prefix(20).map { art in
            let desc = art.description?.prefix(80) ?? ""
            let cat = art.category ?? ""
            return "art: \(art.name) - \(desc) | category: \(cat) (uid: \(art.uid))"
        }.joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            You are selecting art installations for golden hour viewing at Burning Man. \
            Pick art that would look amazing in \(targetTime) light: \
            large-scale sculptures, reflective/metallic pieces, fire art (for sunset), \
            and installations with interesting silhouettes. Avoid indoor/shaded pieces.
            """)

        let selection = try await session.respond(
            to: Prompt("Available art:\n\(candidateText)\n\nSelect the best art for \(targetTime) viewing."),
            generating: GenerableGoldenHourSelection.self
        )
        onProgress(.stepCompleted(name: "curate"))

        // Step 4: Calculate route arriving 30 min before golden hour
        onProgress(.stepStarted(name: "route", description: "Planning your golden hour route..."))
        let selectedUIDs = selection.content.selectedUIDs
        let reasonMap = Dictionary(uniqueKeysWithValues: zip(selectedUIDs, selection.content.reasons + Array(repeating: "", count: max(0, selectedUIDs.count - selection.content.reasons.count))))

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
