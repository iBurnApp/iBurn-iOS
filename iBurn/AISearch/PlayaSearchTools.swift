//
//  PlayaSearchTools.swift
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

// MARK: - Get Favorites (taste profile)

@available(iOS 26, *)
struct GetFavoritesTool: Tool {
    let name = "getFavorites"
    let description = "Get the user's favorited art, camps, events, and vehicles"

    @Generable
    struct Arguments {
        @Guide(description: "Unused, pass empty string")
        var placeholder: String?
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        let favorites = try await playaDB.getFavorites()
        if favorites.isEmpty { return "No favorites yet." }
        return favorites.prefix(20).map { obj in
            "\(obj.objectType.rawValue): \(obj.name) (uid: \(obj.uid))"
        }.joined(separator: "\n")
    }
}

// MARK: - Fetch Upcoming Events

@available(iOS 26, *)
struct FetchUpcomingEventsTool: Tool {
    let name = "fetchUpcomingEvents"
    let description = "Find events starting within the next few hours"

    @Generable
    struct Arguments {
        @Guide(description: "Hours ahead to look", .range(1...12))
        var withinHours: Int
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        let events = try await playaDB.fetchUpcomingEvents(
            within: arguments.withinHours, from: Date()
        )
        if events.isEmpty { return "No upcoming events found." }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return events.prefix(15).map { occ in
            let time = formatter.string(from: occ.startDate)
            let desc = occ.event.description?.prefix(60) ?? ""
            return "event: \(occ.event.name) at \(time) - \(desc) (uid: \(occ.event.uid))"
        }.joined(separator: "\n")
    }
}

// MARK: - Fetch Nearby Objects

@available(iOS 26, *)
struct FetchNearbyObjectsTool: Tool {
    let name = "fetchNearby"
    let description = "Find art, camps, and events near a GPS location"

    @Generable
    struct Arguments {
        @Guide(description: "GPS latitude")
        var latitude: Double
        @Guide(description: "GPS longitude")
        var longitude: Double
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        let center = CLLocationCoordinate2D(
            latitude: arguments.latitude,
            longitude: arguments.longitude
        )
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        let objects = try await playaDB.fetchObjects(in: region)
        if objects.isEmpty { return "Nothing found nearby." }
        return objects.prefix(15).map { obj in
            "\(obj.objectType.rawValue): \(obj.name) (uid: \(obj.uid))"
        }.joined(separator: "\n")
    }
}

#endif
