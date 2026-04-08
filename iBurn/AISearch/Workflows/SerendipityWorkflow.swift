//
//  SerendipityWorkflow.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Generable Types

@available(iOS 26, *)
@Generable
struct GenerableSerendipityPitch {
    @Guide(description: "Object uid")
    var uid: String
    @Guide(description: "Creative pitch for why this unexpected item is worth visiting, under 15 words")
    var pitch: String
}

@available(iOS 26, *)
@Generable
struct GenerableSerendipityResponse {
    @Guide(description: "Opening line about the unexpected discoveries")
    var intro: String
    @Guide(description: "Curated unexpected items with pitches", .count(3...5))
    var picks: [GenerableSerendipityPitch]
}

// MARK: - Serendipity Workflow

@available(iOS 26, *)
struct SerendipityWorkflow: Workflow {
    /// If true, uses random sampling. If false, uses taste-based recommendations.
    let deliberateRandom: Bool
    let name = "Serendipity"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> DiscoveryResult {
        // Step 1: Get favorites to understand taste
        onProgress(.stepStarted(name: "taste", description: "Reading your vibe..."))
        let favorites = try await context.playaDB.getFavorites()
        let favoriteUIDs = Set(favorites.map(\.uid))

        let tasteProfile: String
        if favorites.isEmpty {
            tasteProfile = "No favorites yet - recommend diverse items across all types."
        } else {
            tasteProfile = favorites.prefix(8).map { obj in
                "\(obj.objectType.rawValue): \(obj.name)"
            }.joined(separator: "\n")
        }
        onProgress(.stepCompleted(name: "taste"))

        // Step 2: Get random candidates (deliberate randomness for serendipity)
        onProgress(.stepStarted(name: "discover", description: deliberateRandom ? "Rolling the dice..." : "Finding hidden gems..."))

        var candidates: [Any] = []

        if deliberateRandom {
            // Fetch all and sample randomly
            let allArt = try await context.playaDB.fetchArt()
            let allCamps = try await context.playaDB.fetchCamps()
            let allMVs = try await context.playaDB.fetchMutantVehicles()

            var pool: [Any] = []
            pool.append(contentsOf: allArt.filter { !favoriteUIDs.contains($0.uid) })
            pool.append(contentsOf: allCamps.filter { !favoriteUIDs.contains($0.uid) })
            pool.append(contentsOf: allMVs.filter { !favoriteUIDs.contains($0.uid) })
            pool.shuffle()
            candidates = Array(pool.prefix(15))
        } else {
            // Use taste keywords to find non-favorited items
            let keywords = extractKeywords(from: favorites)
            for keyword in keywords.prefix(3) {
                let results = try await context.playaDB.searchObjects(keyword)
                let filtered = results.filter { !favoriteUIDs.contains($0.uid) }
                candidates.append(contentsOf: filtered)
            }
            // Deduplicate
            var seen = Set<String>()
            candidates = candidates.filter { obj in
                guard let uid = objectUID(obj) else { return false }
                return seen.insert(uid).inserted
            }
            candidates = Array(candidates.prefix(15))
        }
        onProgress(.stepCompleted(name: "discover"))

        guard !candidates.isEmpty else {
            return DiscoveryResult(items: [], intro: "The playa is quiet... try favoriting some items first.")
        }

        // Step 3 & 4: LLM finds creative connections and generates pitches
        onProgress(.stepStarted(name: "pitch", description: "Finding the magic connections..."))
        let candidateText = candidates.map { obj in
            formatObject(obj, detail: .brief)
        }.joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            Whimsical Burning Man guide. Pick 3-5 surprising items and write playful pitches.
            """)

        let prompt = """
            Taste: \(tasteProfile)
            Candidates:
            \(candidateText)
            """

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: GenerableSerendipityResponse.self
        )
        onProgress(.stepCompleted(name: "pitch"))

        // Resolve UIDs to objects
        let items = await resolveItems(response.content.picks, playaDB: context.playaDB)

        return DiscoveryResult(
            items: items,
            intro: response.content.intro
        )
    }

    private func resolveItems(_ picks: [GenerableSerendipityPitch], playaDB: PlayaDB) async -> [DiscoveryItem] {
        var result: [DiscoveryItem] = []
        for pick in picks {
            if let art = try? await playaDB.fetchArt(uid: pick.uid) {
                result.append(DiscoveryItem(uid: pick.uid, name: art.name, type: .art, pitch: pick.pitch))
            } else if let camp = try? await playaDB.fetchCamp(uid: pick.uid) {
                result.append(DiscoveryItem(uid: pick.uid, name: camp.name, type: .camp, pitch: pick.pitch))
            } else if let event = try? await playaDB.fetchEvent(uid: pick.uid) {
                result.append(DiscoveryItem(uid: pick.uid, name: event.name, type: .event, pitch: pick.pitch))
            } else if let mv = try? await playaDB.fetchMutantVehicle(uid: pick.uid) {
                result.append(DiscoveryItem(uid: pick.uid, name: mv.name, type: .mutantVehicle, pitch: pick.pitch))
            }
        }
        return result
    }

    private func extractKeywords(from objects: [Any]) -> [String] {
        var keywords: [String] = []
        for obj in objects.prefix(10) {
            if let art = obj as? ArtObject, let cat = art.category { keywords.append(cat) }
            if let event = obj as? EventObject { keywords.append(event.eventTypeLabel) }
            if let mv = obj as? MutantVehicleObject, let tags = mv.tagsText {
                keywords.append(contentsOf: tags.split(separator: " ").map(String.init))
            }
        }
        return Array(Set(keywords)).prefix(5).map { $0 }
    }
}

#endif
