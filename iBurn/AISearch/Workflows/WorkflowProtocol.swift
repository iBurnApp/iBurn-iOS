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
import MapKit
import FoundationModels
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

    /// Optional map-selected area to scope discovery. When nil, fall back to `location`.
    let region: MKCoordinateRegion?
    /// Time window for events ("now or soon" by default).
    let windowStart: Date
    let windowEnd: Date
    /// Free-text or chip-derived vibe ("" = none).
    let vibe: String
    /// Personalized vs surprise lean.
    let lean: DiscoveryLean

    init(
        playaDB: PlayaDB,
        location: CLLocation? = nil,
        date: Date = Date(),
        conversationHistory: [String] = [],
        region: MKCoordinateRegion? = nil,
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        vibe: String = "",
        lean: DiscoveryLean = .balanced
    ) {
        self.playaDB = playaDB
        self.location = location
        self.date = date
        self.conversationHistory = conversationHistory
        self.region = region
        self.windowStart = windowStart ?? date
        self.windowEnd = windowEnd ?? date.addingTimeInterval(2 * 3600)
        self.vibe = vibe
        self.lean = lean
    }
}

// MARK: - Workflow Progress

/// Progress updates streamed to the UI during workflow execution
enum WorkflowProgress: Sendable {
    case stepStarted(name: String, description: String)
    case stepCompleted(name: String)
    case intermediateResult(text: String)
}

// MARK: - Utility: Distance Calculation

/// Calculate walking time between two coordinates on the playa.
/// Assumes ~4 km/h walking speed on playa dust.
func playaWalkMinutes(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Int {
    let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
    let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
    let meters = fromLoc.distance(from: toLoc)
    return Int(ceil(meters / 67.0)) // ~4 km/h
}

// MARK: - Utility: Object Field Access (DataObject name-conflict workaround)

/// Extract UID from any PlayaDB object.
func objectUID(_ obj: Any) -> String? {
    if let art = obj as? ArtObject { return art.uid }
    if let camp = obj as? CampObject { return camp.uid }
    if let event = obj as? EventObject { return event.uid }
    if let mv = obj as? MutantVehicleObject { return mv.uid }
    return nil
}

/// Extract name from any PlayaDB object.
func objectName(_ obj: Any) -> String? {
    if let art = obj as? ArtObject { return art.name }
    if let camp = obj as? CampObject { return camp.name }
    if let event = obj as? EventObject { return event.name }
    if let mv = obj as? MutantVehicleObject { return mv.name }
    return nil
}

// MARK: - Retry: Candidate Filtering

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
