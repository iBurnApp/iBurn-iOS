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
import GRDB
@preconcurrency import PlayaDB

// MARK: - Detail Level

/// Controls how much information tools return per item to manage context window budget
enum ToolDetailLevel: String {
    /// Name + uid only (~15 tokens/item) — for exploration steps scanning many items
    case brief
    /// Name + short desc + uid (~30 tokens/item) — default behavior
    case normal
    /// Name + full desc + location + metadata + uid (~80 tokens/item) — for final selection
    case full
}

// MARK: - Formatting Helpers

func formatObject(_ obj: Any, detail: ToolDetailLevel) -> String {
    // Extract common fields via concrete type casts (avoids DataObject protocol name conflict)
    let name: String
    let uid: String
    let typeName: String

    if let art = obj as? ArtObject {
        name = art.name; uid = art.uid; typeName = "art"
    } else if let camp = obj as? CampObject {
        name = camp.name; uid = camp.uid; typeName = "camp"
    } else if let event = obj as? EventObject {
        name = event.name; uid = event.uid; typeName = "event"
    } else if let mv = obj as? MutantVehicleObject {
        name = mv.name; uid = mv.uid; typeName = "mutantVehicle"
    } else {
        return "unknown object"
    }

    switch detail {
    case .brief:
        return "\(typeName): \(name) (uid: \(uid))"
    case .normal:
        var desc: String = "no description"
        if let d = (obj as? ArtObject)?.description { desc = String(d.prefix(80)) }
        else if let d = (obj as? CampObject)?.description { desc = String(d.prefix(80)) }
        else if let d = (obj as? EventObject)?.description { desc = String(d.prefix(80)) }
        else if let d = (obj as? MutantVehicleObject)?.description { desc = String(d.prefix(80)) }
        return "\(typeName): \(name) - \(desc) (uid: \(uid))"
    case .full:
        return formatObjectFull(obj)
    }
}

func formatObjectFull(_ obj: Any) -> String {
    if let art = obj as? ArtObject {
        var parts = ["art: \(art.name)"]
        if let desc = art.description { parts.append("desc: \(desc)") }
        if let artist = art.artist { parts.append("artist: \(artist)") }
        if let category = art.category { parts.append("category: \(category)") }
        if let loc = art.locationString { parts.append("location: \(loc)") }
        if let lat = art.gpsLatitude, let lon = art.gpsLongitude { parts.append("gps: \(lat),\(lon)") }
        parts.append("(uid: \(art.uid))")
        return parts.joined(separator: " | ")
    } else if let camp = obj as? CampObject {
        var parts = ["camp: \(camp.name)"]
        if let desc = camp.description { parts.append("desc: \(desc)") }
        if let loc = camp.locationString { parts.append("location: \(loc)") }
        if let hometown = camp.hometown { parts.append("hometown: \(hometown)") }
        if let lat = camp.gpsLatitude, let lon = camp.gpsLongitude { parts.append("gps: \(lat),\(lon)") }
        parts.append("(uid: \(camp.uid))")
        return parts.joined(separator: " | ")
    } else if let event = obj as? EventObject {
        var parts = ["event: \(event.name)"]
        if let desc = event.description { parts.append("desc: \(desc)") }
        parts.append("type: \(event.eventTypeLabel)")
        if let camp = event.hostedByCamp { parts.append("host: \(camp)") }
        parts.append("(uid: \(event.uid))")
        return parts.joined(separator: " | ")
    } else if let mv = obj as? MutantVehicleObject {
        var parts = ["vehicle: \(mv.name)"]
        if let desc = mv.description { parts.append("desc: \(desc)") }
        if let artist = mv.artist { parts.append("artist: \(artist)") }
        if let tags = mv.tagsText { parts.append("tags: \(tags)") }
        parts.append("(uid: \(mv.uid))")
        return parts.joined(separator: " | ")
    }
    return "unknown object"
}

private func formatEventOccurrence(_ occ: EventObjectOccurrence, detail: ToolDetailLevel, formatter: DateFormatter) -> String {
    let time = formatter.string(from: occ.startDate)
    switch detail {
    case .brief:
        return "event: \(occ.event.name) at \(time) (uid: \(occ.event.uid))"
    case .normal:
        let desc = occ.event.description?.prefix(60) ?? ""
        return "event: \(occ.event.name) at \(time) - \(desc) (uid: \(occ.event.uid))"
    case .full:
        let desc = occ.event.description ?? "no description"
        let endTime = formatter.string(from: occ.endDate)
        var parts = ["event: \(occ.event.name)", "time: \(time)-\(endTime)", "type: \(occ.event.eventTypeLabel)"]
        parts.append("desc: \(desc)")
        if let camp = occ.event.hostedByCamp { parts.append("host: \(camp)") }
        if let lat = occ.event.gpsLatitude, let lon = occ.event.gpsLongitude {
            parts.append("gps: \(lat),\(lon)")
        }
        parts.append("(uid: \(occ.event.uid))")
        return parts.joined(separator: " | ")
    }
}

private func makeTimeFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
    return formatter
}

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
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let results = try await playaDB.searchObjects(arguments.query)
        if results.isEmpty { return "No results found." }
        return results.prefix(15).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
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
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        var filter = ArtFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchArt(filter: filter)
        if results.isEmpty { return "No art found." }
        return results.prefix(10).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
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
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        var filter = CampFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchCamps(filter: filter)
        if results.isEmpty { return "No camps found." }
        return results.prefix(10).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
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
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        var filter = MutantVehicleFilter.all
        filter.searchText = arguments.keyword
        let results = try await playaDB.fetchMutantVehicles(filter: filter)
        if results.isEmpty { return "No vehicles found." }
        return results.prefix(10).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
    }
}

// MARK: - Get Favorites (taste profile)

@available(iOS 26, *)
struct GetFavoritesTool: Tool {
    let name = "getFavorites"
    let description = "Get the user's favorited art, camps, events, and vehicles to understand their taste"

    @Generable
    struct Arguments {
        @Guide(description: "Unused, pass empty string")
        var placeholder: String?
    }

    let playaDB: PlayaDB
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let favorites = try await playaDB.getFavorites()
        if favorites.isEmpty { return "No favorites yet." }
        return favorites.prefix(20).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
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
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let events = try await playaDB.fetchUpcomingEvents(
            within: arguments.withinHours, from: Date()
        )
        if events.isEmpty { return "No upcoming events found." }
        let formatter = makeTimeFormatter()
        return events.prefix(15).map {
            formatEventOccurrence($0, detail: detailLevel, formatter: formatter)
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
    var detailLevel: ToolDetailLevel = .normal

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
        return objects.prefix(15).map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
    }
}

// MARK: - New Tools

// MARK: Fetch Events by Camp

@available(iOS 26, *)
struct FetchEventsByCampTool: Tool {
    let name = "fetchEventsByCamp"
    let description = "Find events hosted by a specific camp"

    @Generable
    struct Arguments {
        @Guide(description: "Camp UID")
        var campUID: String
    }

    let playaDB: PlayaDB
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let events = try await playaDB.fetchEvents(hostedByCampUID: arguments.campUID)
        if events.isEmpty { return "No events found for this camp." }
        let formatter = makeTimeFormatter()
        return events.prefix(10).map {
            formatEventOccurrence($0, detail: detailLevel, formatter: formatter)
        }.joined(separator: "\n")
    }
}

// MARK: Fetch Events at Art

@available(iOS 26, *)
struct FetchEventsAtArtTool: Tool {
    let name = "fetchEventsAtArt"
    let description = "Find events located at a specific art installation"

    @Generable
    struct Arguments {
        @Guide(description: "Art installation UID")
        var artUID: String
    }

    let playaDB: PlayaDB
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let events = try await playaDB.fetchEvents(locatedAtArtUID: arguments.artUID)
        if events.isEmpty { return "No events found at this art." }
        let formatter = makeTimeFormatter()
        return events.prefix(10).map {
            formatEventOccurrence($0, detail: detailLevel, formatter: formatter)
        }.joined(separator: "\n")
    }
}

// MARK: Fetch Events by Type

@available(iOS 26, *)
struct FetchEventsByTypeTool: Tool {
    let name = "fetchEventsByType"
    let description = "Find events by type code (e.g. 'work' for workshops, 'prty' for parties, 'perf' for performances, 'food' for food, 'kid' for kids, 'fire' for fire, 'para' for parade)"

    @Generable
    struct Arguments {
        @Guide(description: "Event type code")
        var eventTypeCode: String
        @Guide(description: "Only show events starting within this many hours", .range(1...24))
        var withinHours: Int?
    }

    let playaDB: PlayaDB
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        var filter = EventFilter.all
        filter.eventTypeCodes = [arguments.eventTypeCode]
        if let hours = arguments.withinHours {
            filter.startingWithinHours = hours
        }
        let events = try await playaDB.fetchEvents(filter: filter)
        if events.isEmpty { return "No events found for type '\(arguments.eventTypeCode)'." }
        let formatter = makeTimeFormatter()
        return events.prefix(15).map {
            formatEventOccurrence($0, detail: detailLevel, formatter: formatter)
        }.joined(separator: "\n")
    }
}

// MARK: Fetch Object Details

@available(iOS 26, *)
struct FetchObjectDetailsTool: Tool {
    let name = "fetchObjectDetails"
    let description = "Get full details for an object by UID (art, camp, event, or vehicle)"

    @Generable
    struct Arguments {
        @Guide(description: "Object UID")
        var uid: String
    }

    let playaDB: PlayaDB

    func call(arguments: Arguments) async throws -> String {
        if let art = try await playaDB.fetchArt(uid: arguments.uid) {
            return formatObjectFull(art)
        }
        if let camp = try await playaDB.fetchCamp(uid: arguments.uid) {
            return formatObjectFull(camp)
        }
        if let event = try await playaDB.fetchEvent(uid: arguments.uid) {
            return formatObjectFull(event)
        }
        if let mv = try await playaDB.fetchMutantVehicle(uid: arguments.uid) {
            return formatObjectFull(mv)
        }
        return "Object not found for uid: \(arguments.uid)"
    }
}

// MARK: Get View History

@available(iOS 26, *)
struct GetViewHistoryTool: Tool {
    let name = "getViewHistory"
    let description = "Get recently viewed objects ordered by most recent"

    @Generable
    struct Arguments {
        @Guide(description: "Max number of items to return", .range(1...20))
        var limit: Int?
    }

    let playaDB: PlayaDB
    var detailLevel: ToolDetailLevel = .normal

    func call(arguments: Arguments) async throws -> String {
        let limit = arguments.limit ?? 10
        let objects = try await playaDB.fetchRecentlyViewed(limit: limit)
        if objects.isEmpty { return "No recently viewed items." }
        return objects.map { formatObject($0, detail: detailLevel) }.joined(separator: "\n")
    }
}

// MARK: Get Location History

@available(iOS 26, *)
struct GetLocationHistoryTool: Tool {
    let name = "getLocationHistory"
    let description = "Get the user's GPS breadcrumb trail from the last N hours"

    @Generable
    struct Arguments {
        @Guide(description: "Hours of history to retrieve", .range(1...48))
        var hours: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        guard let storage = LocationStorage.shared else {
            return "Location history not available."
        }
        let hours = arguments.hours ?? 24
        let since = Date().addingTimeInterval(-Double(hours) * 3600)
        let breadcrumbs: [Breadcrumb] = try await storage.dbQueue.read { db in
            try Breadcrumb
                .filter(Column("timestamp") >= since)
                .order(Column("timestamp").desc)
                .limit(100)
                .fetchAll(db)
        }
        if breadcrumbs.isEmpty { return "No location history found." }
        let formatter = makeTimeFormatter()
        return breadcrumbs.enumerated().compactMap { idx, crumb -> String? in
            guard idx % 5 == 0 else { return nil } // Sample every 5th point
            let time = formatter.string(from: crumb.timestamp)
            return "\(time): \(crumb.coordinate.latitude),\(crumb.coordinate.longitude)"
        }.joined(separator: "\n")
    }
}

// MARK: Calculate Distance

@available(iOS 26, *)
struct CalculateDistanceTool: Tool {
    let name = "calculateDistance"
    let description = "Calculate walking distance and time between two GPS locations on the playa"

    @Generable
    struct Arguments {
        @Guide(description: "Start latitude")
        var fromLatitude: Double
        @Guide(description: "Start longitude")
        var fromLongitude: Double
        @Guide(description: "End latitude")
        var toLatitude: Double
        @Guide(description: "End longitude")
        var toLongitude: Double
    }

    func call(arguments: Arguments) async throws -> String {
        let from = CLLocation(latitude: arguments.fromLatitude, longitude: arguments.fromLongitude)
        let to = CLLocation(latitude: arguments.toLatitude, longitude: arguments.toLongitude)
        let meters = from.distance(from: to)
        let walkMinutes = Int(ceil(meters / 67.0)) // ~4 km/h on playa dust
        return "Distance: \(Int(meters))m, walk time: ~\(walkMinutes) min"
    }
}

#endif
