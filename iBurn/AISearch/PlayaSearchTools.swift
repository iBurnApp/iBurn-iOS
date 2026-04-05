//
//  PlayaSearchTools.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Search by Keyword (FTS5)

@available(iOS 26, *)
struct SearchByKeywordTool: Tool {
    let name = "searchByKeyword"
    let description = "Full-text search across all art, camps, events, and vehicles"

    @Generable
    struct Arguments {
        @Guide(description: "Search keywords")
        var query: String
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        let results = try await playaDB.searchObjects(arguments.query)
        if results.isEmpty { return "No results found." }
        return results.prefix(15).map { obj in
            "\(obj.objectType.rawValue): \(obj.name) (uid: \(obj.uid))"
        }.joined(separator: "\n")
    }
}

// MARK: - Fetch Art

@available(iOS 26, *)
struct FetchArtTool: Tool {
    let name = "fetchArt"
    let description = "Search art installations by keyword"

    @Generable
    struct Arguments {
        @Guide(description: "Keyword to search for")
        var keyword: String?
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        var filter = ArtFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchArt(filter: filter)
        if results.isEmpty { return "No art found." }
        return results.prefix(10).map { art in
            let desc = art.description?.prefix(80) ?? "no description"
            return "art: \(art.name) - \(desc) (uid: \(art.uid))"
        }.joined(separator: "\n")
    }
}

// MARK: - Fetch Camps

@available(iOS 26, *)
struct FetchCampsTool: Tool {
    let name = "fetchCamps"
    let description = "Search theme camps by keyword"

    @Generable
    struct Arguments {
        @Guide(description: "Keyword to search for")
        var keyword: String?
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        var filter = CampFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchCamps(filter: filter)
        if results.isEmpty { return "No camps found." }
        return results.prefix(10).map { camp in
            let desc = camp.description?.prefix(80) ?? "no description"
            return "camp: \(camp.name) - \(desc) (uid: \(camp.uid))"
        }.joined(separator: "\n")
    }
}

// MARK: - Fetch Mutant Vehicles

@available(iOS 26, *)
struct FetchMutantVehiclesTool: Tool {
    let name = "fetchVehicles"
    let description = "Search mutant vehicles by keyword or tags"

    @Generable
    struct Arguments {
        @Guide(description: "Keyword to search for")
        var keyword: String?
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        var filter = MutantVehicleFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchMutantVehicles(filter: filter)
        if results.isEmpty { return "No vehicles found." }
        return results.prefix(10).map { mv in
            let desc = mv.description?.prefix(80) ?? "no description"
            return "vehicle: \(mv.name) - \(desc) (uid: \(mv.uid))"
        }.joined(separator: "\n")
    }
}

#endif
