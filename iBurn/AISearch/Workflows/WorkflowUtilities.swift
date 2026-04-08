//
//  WorkflowUtilities.swift
//  iBurn
//
//  Shared utilities for AI workflows to eliminate duplication across
//  route building, object resolution, candidate formatting, and note merging.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
@preconcurrency import PlayaDB

// MARK: - Object Resolution

/// Resolved metadata for any PlayaDB object — common fields needed by workflows.
struct ResolvedObject {
    let uid: String
    let name: String
    let type: DataObjectType
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// Resolve a single UID to its object metadata by trying each type.
func resolveObject(uid: String, playaDB: PlayaDB) async -> ResolvedObject? {
    if let art = try? await playaDB.fetchArt(uid: uid) {
        return ResolvedObject(uid: uid, name: art.name, type: .art, latitude: art.gpsLatitude, longitude: art.gpsLongitude)
    } else if let camp = try? await playaDB.fetchCamp(uid: uid) {
        return ResolvedObject(uid: uid, name: camp.name, type: .camp, latitude: camp.gpsLatitude, longitude: camp.gpsLongitude)
    } else if let event = try? await playaDB.fetchEvent(uid: uid) {
        return ResolvedObject(uid: uid, name: event.name, type: .event, latitude: event.gpsLatitude, longitude: event.gpsLongitude)
    } else if let mv = try? await playaDB.fetchMutantVehicle(uid: uid) {
        return ResolvedObject(uid: uid, name: mv.name, type: .mutantVehicle, latitude: nil, longitude: nil)
    }
    return nil
}

/// Batch resolve UIDs to objects.
func resolveObjects(uids: [String], playaDB: PlayaDB) async -> [String: ResolvedObject] {
    var result: [String: ResolvedObject] = [:]
    for uid in uids {
        if let obj = await resolveObject(uid: uid, playaDB: playaDB) {
            result[uid] = obj
        }
    }
    return result
}

/// Resolve LLM picks (uid + pitch) into DiscoveryItems.
/// Works with any type that has `uid` and `pitch` string properties.
func resolveDiscoveryItems(picks: [(uid: String, pitch: String)], playaDB: PlayaDB) async -> [DiscoveryItem] {
    var result: [DiscoveryItem] = []
    for pick in picks {
        if let obj = await resolveObject(uid: pick.uid, playaDB: playaDB) {
            result.append(DiscoveryItem(uid: pick.uid, name: obj.name, type: obj.type, pitch: pick.pitch))
        }
    }
    return result
}

// MARK: - Route Building

/// Built route with stops and total walking time.
struct BuiltRoute {
    let stops: [RouteStop]
    let totalWalkMinutes: Int
}

/// Build an optimized walking route from selected UIDs with reasons/tips.
/// Resolves coordinates, optimizes order, and calculates walk times.
func buildRoute(
    selections: [(uid: String, reason: String, typeOverride: DataObjectType?)],
    startLocation: CLLocationCoordinate2D?,
    playaDB: PlayaDB
) async -> BuiltRoute {
    let resolved = await resolveObjects(uids: selections.map(\.uid), playaDB: playaDB)
    let reasonMap = Dictionary(selections.map { ($0.uid, $0.reason) }, uniquingKeysWith: { first, _ in first })
    let typeOverrides = Dictionary(selections.compactMap { s -> (String, DataObjectType)? in
        guard let t = s.typeOverride else { return nil }
        return (s.uid, t)
    }, uniquingKeysWith: { first, _ in first })

    // Collect stops with coordinates for route optimization
    var stopsWithCoords: [(uid: String, coord: CLLocationCoordinate2D)] = []
    for sel in selections {
        if let obj = resolved[sel.uid], let coord = obj.coordinate {
            stopsWithCoords.append((uid: sel.uid, coord: coord))
        }
    }

    // Optimize route order, append items without coordinates at the end
    let optimized = optimizeRoute(from: startLocation, stops: stopsWithCoords)
    let optimizedUIDs = optimized.map(\.uid) + selections.map(\.uid).filter { uid in
        !optimized.contains(where: { $0.uid == uid })
    }

    // Build stops with walk times
    var totalWalkMinutes = 0
    var routeStops: [RouteStop] = []
    var previousCoord: CLLocationCoordinate2D? = startLocation

    for uid in optimizedUIDs {
        let obj = resolved[uid]
        let coord = optimized.first(where: { $0.uid == uid })?.coord

        var walkMin: Int? = nil
        if let prev = previousCoord, let curr = coord {
            walkMin = playaWalkMinutes(from: prev, to: curr)
            totalWalkMinutes += walkMin ?? 0
            previousCoord = curr
        }

        routeStops.append(RouteStop(
            id: uid,
            name: obj?.name ?? uid,
            type: typeOverrides[uid] ?? obj?.type ?? .art,
            reason: reasonMap[uid] ?? "",
            walkMinutesFromPrevious: walkMin,
            latitude: coord?.latitude,
            longitude: coord?.longitude
        ))
    }

    return BuiltRoute(stops: routeStops, totalWalkMinutes: totalWalkMinutes)
}

// MARK: - Numeric Candidate Formatting

/// Format candidates as a numbered list and build an ID map for token-efficient LLM prompts.
/// Returns the formatted text and a map from 1-based numbers back to objects.
func buildNumberedList<T>(
    candidates: [T],
    maxCount: Int = 18,
    format: (Int, T) -> String
) -> (text: String, idMap: [Int: T]) {
    let slice = Array(candidates.prefix(maxCount))
    let idMap = Dictionary(uniqueKeysWithValues: slice.enumerated().map { ($0.offset + 1, $0.element) })
    let text = slice.enumerated().map { idx, item in
        format(idx + 1, item)
    }.joined(separator: "\n")
    return (text, idMap)
}

// MARK: - Note Merging

/// Merge LLM-generated notes into entries by matching on lowercased name.
func mergeNotesByName<Entry>(
    entries: [Entry],
    notes: [(name: String, text: String)],
    entryName: (Entry) -> String,
    merge: (Entry, String) -> Entry
) -> [Entry] {
    let noteMap = Dictionary(notes.map { ($0.name.lowercased(), $0.text) }, uniquingKeysWith: { first, _ in first })
    return entries.map { entry in
        if let note = noteMap[entryName(entry).lowercased()] {
            return merge(entry, note)
        }
        return entry
    }
}

#endif
