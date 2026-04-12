//
//  WorkflowProtocol.swift
//  iBurn
//
//  Created by Claude Code on 4/5/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
@preconcurrency import PlayaDB

// Note: iBurn has a class named DataObject that shadows PlayaDB's DataObject protocol.
// We cannot use PlayaDB.DataObject because PlayaDB is both a module and protocol name.
// Instead, we avoid referencing DataObject directly in type annotations below.

// MARK: - Workflow Protocol

/// A multi-step agentic workflow that uses Swift orchestration + focused LLM calls
@available(iOS 26, *)
protocol Workflow {
    associatedtype Result
    var name: String { get }
    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> Result
}

// MARK: - Workflow Context

/// Shared context passed between workflow steps
@available(iOS 26, *)
struct WorkflowContext {
    let playaDB: PlayaDB
    let location: CLLocation?
    let date: Date
    var conversationHistory: [String]

    init(playaDB: PlayaDB, location: CLLocation? = nil, date: Date = Date(), conversationHistory: [String] = []) {
        self.playaDB = playaDB
        self.location = location
        self.date = date
        self.conversationHistory = conversationHistory
    }
}

// MARK: - Workflow Progress

/// Progress updates streamed to the UI during workflow execution
enum WorkflowProgress: Sendable {
    case stepStarted(name: String, description: String)
    case stepCompleted(name: String)
    case intermediateResult(text: String)
}

// MARK: - Workflow Result Types

/// Result from adventure/crawl workflows that include a route
struct RouteResult: Sendable {
    let stops: [RouteStop]
    let narrative: String
    let totalWalkMinutes: Int
}

struct RouteStop: Sendable, Identifiable {
    let id: String // uid
    let name: String
    let type: DataObjectType
    let reason: String
    let walkMinutesFromPrevious: Int?
    let latitude: Double?
    let longitude: Double?
}

/// Result from schedule optimization
struct OptimizedSchedule: Sendable {
    let items: [ScheduleEntry]
    let summary: String
    let conflictsResolved: Int
}

struct ScheduleEntry: Sendable, Identifiable {
    var id: String { uid }
    let uid: String
    let name: String
    let startTime: String
    let endTime: String
    let reason: String
    let walkMinutesFromPrevious: Int?
}

/// Result from serendipity/recommendation workflows
struct DiscoveryResult: Sendable {
    let items: [DiscoveryItem]
    let intro: String
}

struct DiscoveryItem: Sendable, Identifiable {
    var id: String { uid }
    let uid: String
    let name: String
    let type: DataObjectType
    let pitch: String
}

// MARK: - Utility: Distance Calculation

/// Calculate walking time between two coordinates on the playa
/// Assumes ~4 km/h walking speed on playa dust
func playaWalkMinutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
    let meters = fromLoc.distance(from: toLoc)
    return Int(ceil(meters / 67.0)) // ~4 km/h
}

/// Simple nearest-neighbor route optimizer
func optimizeRoute(from start: CLLocationCoordinate2D?, stops: [(uid: String, coord: CLLocationCoordinate2D)]) -> [(uid: String, coord: CLLocationCoordinate2D)] {
    guard stops.count > 1 else { return stops }

    var remaining = stops
    var ordered: [(uid: String, coord: CLLocationCoordinate2D)] = []
    var current = start ?? stops.first!.coord

    while !remaining.isEmpty {
        let nearest = remaining.enumerated().min(by: { a, b in
            let distA = CLLocation(latitude: current.latitude, longitude: current.longitude)
                .distance(from: CLLocation(latitude: a.element.coord.latitude, longitude: a.element.coord.longitude))
            let distB = CLLocation(latitude: current.latitude, longitude: current.longitude)
                .distance(from: CLLocation(latitude: b.element.coord.latitude, longitude: b.element.coord.longitude))
            return distA < distB
        })!
        ordered.append(remaining.remove(at: nearest.offset))
        current = ordered.last!.coord
    }
    return ordered
}

/// Detect time conflicts between event occurrences
func detectConflicts(_ events: [EventObjectOccurrence]) -> [(EventObjectOccurrence, EventObjectOccurrence)] {
    var conflicts: [(EventObjectOccurrence, EventObjectOccurrence)] = []
    let sorted = events.sorted { $0.startDate < $1.startDate }
    for i in 0..<sorted.count {
        for j in (i+1)..<sorted.count {
            let a = sorted[i]
            let b = sorted[j]
            // Overlap: a starts before b ends AND b starts before a ends
            if a.startDate < b.endDate && b.startDate < a.endDate {
                conflicts.append((a, b))
            }
        }
    }
    return conflicts
}

/// Cluster GPS coordinates by distance (simple greedy clustering)
func clusterCoordinates(_ coords: [(lat: Double, lon: Double, timestamp: Date)], thresholdMeters: Double = 200) -> [[(lat: Double, lon: Double, timestamp: Date)]] {
    var clusters: [[(lat: Double, lon: Double, timestamp: Date)]] = []
    for point in coords {
        var added = false
        for i in 0..<clusters.count {
            let centroid = clusters[i].first!
            let dist = CLLocation(latitude: centroid.lat, longitude: centroid.lon)
                .distance(from: CLLocation(latitude: point.lat, longitude: point.lon))
            if dist < thresholdMeters {
                clusters[i].append(point)
                added = true
                break
            }
        }
        if !added {
            clusters.append([point])
        }
    }
    return clusters
}

/// Extract UID from any PlayaDB object (workaround for DataObject name conflict)
func objectUID(_ obj: Any) -> String? {
    if let art = obj as? ArtObject { return art.uid }
    if let camp = obj as? CampObject { return camp.uid }
    if let event = obj as? EventObject { return event.uid }
    if let mv = obj as? MutantVehicleObject { return mv.uid }
    return nil
}

/// Extract name from any PlayaDB object
func objectName(_ obj: Any) -> String? {
    if let art = obj as? ArtObject { return art.name }
    if let camp = obj as? CampObject { return camp.name }
    if let event = obj as? EventObject { return event.name }
    if let mv = obj as? MutantVehicleObject { return mv.name }
    return nil
}

/// Extract taste keywords from a list of favorited objects
func extractTasteKeywords(_ objects: [Any]) -> [String] {
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

/// Calculate sunrise/sunset for Black Rock City coordinates
/// Returns (sunrise, sunset) as Dates for the given date
func brcSunTimes(for date: Date) -> (sunrise: Date, sunset: Date) {
    // BRC coordinates: 40.7864, -119.2065
    // Approximate solar times for late August at BRC:
    // Sunrise ~6:15 AM, Sunset ~7:30 PM PDT
    // This is a simplified calculation; for production, use a proper solar algorithm
    let calendar = Calendar.current
    var components = calendar.dateComponents(in: TimeZone(identifier: "America/Los_Angeles")!, from: date)
    components.hour = 6
    components.minute = 15
    let sunrise = calendar.date(from: components)!
    components.hour = 19
    components.minute = 30
    let sunset = calendar.date(from: components)!
    return (sunrise, sunset)
}

/// Retry an LLM generation call with progressive candidate filtering.
/// On failure with the full set, tries each half, then individual items to isolate problematic ones.
@available(iOS 26, *)
func retryWithCandidateFiltering<T, R>(
    candidates: [T],
    minimumCount: Int = 3,
    format: (T) -> String,
    attempt: ([T]) async throws -> R
) async throws -> R {
    guard !candidates.isEmpty else {
        throw NSError(domain: "Workflow", code: -1, userInfo: [NSLocalizedDescriptionKey: "No candidates"])
    }

    // First try with all candidates
    do {
        return try await attempt(candidates)
    } catch {
        print("LLM curate failed with \(candidates.count) candidates: \(error)")
    }

    // Split in half and try each half
    let mid = candidates.count / 2
    let firstHalf = Array(candidates.prefix(mid))
    let secondHalf = Array(candidates.suffix(from: mid))

    if firstHalf.count >= minimumCount, let result = try? await attempt(firstHalf) {
        return result
    }
    if secondHalf.count >= minimumCount, let result = try? await attempt(secondHalf) {
        return result
    }

    // Last resort: test candidates individually, collect safe ones
    var safe: [T] = []
    for item in candidates {
        do {
            _ = try await attempt([item])
            safe.append(item)
            if safe.count >= candidates.count / 2 { break }
        } catch {
            print("Filtering out candidate: \(format(item))")
        }
    }

    guard safe.count >= minimumCount else {
        throw NSError(domain: "Workflow", code: -1, userInfo: [NSLocalizedDescriptionKey: "Too many candidates trigger content filters"])
    }
    return try await attempt(safe)
}

#endif
