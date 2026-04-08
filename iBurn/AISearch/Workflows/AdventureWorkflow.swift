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

        // Step 4: Route optimization — map numeric IDs back
        onProgress(.stepStarted(name: "route", description: "Optimizing your route..."))
        let selectedUIDs = selection.stops.compactMap { stop -> String? in
            guard let obj = objIdMap[stop.number] else { return nil }
            return objectUID(obj)
        }
        let reasonMap = Dictionary(selection.stops.compactMap { stop -> (String, String)? in
            guard let obj = objIdMap[stop.number], let uid = objectUID(obj) else { return nil }
            return (uid, stop.reason)
        }, uniquingKeysWith: { first, _ in first })

        // Get coordinates for selected items
        var stopsWithCoords: [(uid: String, coord: CLLocationCoordinate2D)] = []
        var objectInfo: [String: (name: String, type: DataObjectType)] = [:]

        for uid in selectedUIDs {
            if let art = try? await context.playaDB.fetchArt(uid: uid),
               let lat = art.gpsLatitude, let lon = art.gpsLongitude {
                stopsWithCoords.append((uid: uid, coord: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                objectInfo[uid] = (art.name, .art)
            } else if let camp = try? await context.playaDB.fetchCamp(uid: uid),
                      let lat = camp.gpsLatitude, let lon = camp.gpsLongitude {
                stopsWithCoords.append((uid: uid, coord: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                objectInfo[uid] = (camp.name, .camp)
            } else if let event = try? await context.playaDB.fetchEvent(uid: uid),
                      let lat = event.gpsLatitude, let lon = event.gpsLongitude {
                stopsWithCoords.append((uid: uid, coord: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                objectInfo[uid] = (event.name, .event)
            } else if let mv = try? await context.playaDB.fetchMutantVehicle(uid: uid) {
                objectInfo[uid] = (mv.name, .mutantVehicle)
                // MVs don't have fixed locations
            }
        }

        // Optimize route order
        let optimized = optimizeRoute(from: context.location?.coordinate, stops: stopsWithCoords)
        let optimizedUIDs = optimized.map(\.uid) + selectedUIDs.filter { uid in !optimized.contains(where: { $0.uid == uid }) }

        // Calculate walk times
        var totalWalkMinutes = 0
        var routeStops: [RouteStop] = []
        var previousCoord: CLLocationCoordinate2D? = context.location?.coordinate

        for uid in optimizedUIDs {
            let info = objectInfo[uid]
            let coord = optimized.first(where: { $0.uid == uid })?.coord

            var walkMin: Int? = nil
            if let prev = previousCoord, let curr = coord {
                walkMin = playaWalkMinutes(from: prev, to: curr)
                totalWalkMinutes += walkMin ?? 0
                previousCoord = curr
            }

            routeStops.append(RouteStop(
                id: uid,
                name: info?.name ?? uid,
                type: info?.type ?? .art,
                reason: reasonMap[uid] ?? "",
                walkMinutesFromPrevious: walkMin,
                latitude: coord?.latitude,
                longitude: coord?.longitude
            ))
        }
        onProgress(.stepCompleted(name: "route"))

        // Step 5 & 6: Generate narrative
        onProgress(.stepStarted(name: "narrative", description: "Writing your adventure..."))
        let stopsText = routeStops.enumerated().map { idx, stop in
            "Stop \(idx + 1): \(stop.name) (\(stop.type.rawValue))"
        }.joined(separator: "\n")

        let narrativeSession = LanguageModelSession(instructions: """
            Write a fun, immersive adventure narrative for a Burning Man playa tour. \
            Theme: "\(theme)". Keep it playful and inspiring.
            """)
        let narrative = try await narrativeSession.respond(
            to: Prompt("Stops:\n\(stopsText)\n\nWrite an adventure intro and a one-line visit tip per stop."),
            generating: GenerableAdventureNarrative.self
        )
        onProgress(.stepCompleted(name: "narrative"))

        // Merge tips into stops by matching stop name
        let tipsByName = Dictionary(narrative.content.tips.map { ($0.stopName.lowercased(), $0.tip) }, uniquingKeysWith: { first, _ in first })
        let finalStops = routeStops.map { stop in
            let tip = tipsByName[stop.name.lowercased()]
            return RouteStop(
                id: stop.id,
                name: stop.name,
                type: stop.type,
                reason: tip ?? stop.reason,
                walkMinutesFromPrevious: stop.walkMinutesFromPrevious,
                latitude: stop.latitude,
                longitude: stop.longitude
            )
        }

        return RouteResult(
            stops: finalStops,
            narrative: narrative.content.intro,
            totalWalkMinutes: totalWalkMinutes
        )
    }
}

#endif
