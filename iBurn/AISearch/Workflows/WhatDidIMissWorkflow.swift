//
//  WhatDidIMissWorkflow.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
import MapKit
import FoundationModels
import GRDB
@preconcurrency import PlayaDB

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableMissedItemPick {
    @Guide(description: "Object uid")
    var uid: String
    @Guide(description: "Why this is worth going back for, under 15 words")
    var pitch: String
}

@available(iOS 26, *)
@Generable
struct GenerableMissedResponse {
    @Guide(description: "Opening sentence about what was missed")
    var intro: String
    @Guide(description: "Most interesting missed items", .count(2...6))
    var picks: [GenerableMissedItemPick]
}

// MARK: - What Did I Miss Workflow

@available(iOS 26, *)
struct WhatDidIMissWorkflow: Workflow {
    let name = "What Did I Miss"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> DiscoveryResult {
        // Step 1: Fetch breadcrumbs from last 24h
        onProgress(.stepStarted(name: "tracks", description: "Loading your location history..."))
        guard let storage = LocationStorage.shared else {
            return DiscoveryResult(items: [], intro: "Location history is not available.")
        }

        let since = context.date.addingTimeInterval(-24 * 3600)
        let breadcrumbs: [Breadcrumb] = try await storage.dbQueue.read { db in
            try Breadcrumb
                .filter(Column("timestamp") >= since)
                .order(Column("timestamp").asc)
                .fetchAll(db)
        }

        guard !breadcrumbs.isEmpty else {
            return DiscoveryResult(items: [], intro: "No location history found in the last 24 hours.")
        }
        onProgress(.stepCompleted(name: "tracks"))

        // Step 2: Cluster breadcrumbs by distance
        onProgress(.stepStarted(name: "cluster", description: "Analyzing your path..."))
        let coords = breadcrumbs.map { (lat: $0.coordinate.latitude, lon: $0.coordinate.longitude, timestamp: $0.timestamp) }
        let clusters = clusterCoordinates(coords, thresholdMeters: 200)
        onProgress(.stepCompleted(name: "cluster"))

        // Step 3: For each cluster centroid, find nearby objects
        onProgress(.stepStarted(name: "nearby", description: "Finding things near your path..."))
        var nearbyObjects: [Any] = []
        var seenUIDs = Set<String>()

        for cluster in clusters.prefix(8) {
            guard let first = cluster.first else { continue }
            let center = CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon)
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
            )
            let objects = try await context.playaDB.fetchObjects(in: region)
            for obj in objects where seenUIDs.insert(obj.uid).inserted {
                nearbyObjects.append(obj)
            }
        }
        onProgress(.stepCompleted(name: "nearby"))

        // Step 4: Filter out favorited/viewed objects
        onProgress(.stepStarted(name: "filter", description: "Filtering what you already know..."))
        let favorites = try await context.playaDB.getFavorites()
        let favoriteUIDs = Set(favorites.map(\.uid))
        let recentlyViewed = try await context.playaDB.fetchRecentlyViewed(limit: 50)
        let viewedUIDs = Set(recentlyViewed.map(\.uid))

        let missedObjects = nearbyObjects.filter { obj in
            guard let uid = objectUID(obj) else { return false }
            return !favoriteUIDs.contains(uid) && !viewedUIDs.contains(uid)
        }
        onProgress(.stepCompleted(name: "filter"))

        guard !missedObjects.isEmpty else {
            return DiscoveryResult(items: [], intro: "You've been thorough! Nothing notable was missed nearby.")
        }

        // Step 5: LLM curates the most interesting missed items
        onProgress(.stepStarted(name: "curate", description: "Finding hidden gems you walked past..."))
        let candidateText = missedObjects.prefix(15).map { obj in
            formatObject(obj, detail: .brief)
        }.joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            Pick the most interesting missed items. Write compelling reasons to go back.
            """)

        let response = try await session.respond(
            to: Prompt("Items near the user's path that they didn't visit:\n\(candidateText)"),
            generating: GenerableMissedResponse.self
        )
        onProgress(.stepCompleted(name: "curate"))

        // Resolve UIDs
        let items = await resolveDiscoveryItems(
            picks: response.content.picks.map { (uid: $0.uid, pitch: $0.pitch) },
            playaDB: context.playaDB
        )

        return DiscoveryResult(
            items: items,
            intro: response.content.intro
        )
    }

}

#endif
