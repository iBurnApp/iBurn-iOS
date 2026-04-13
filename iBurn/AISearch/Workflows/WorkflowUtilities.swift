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
import FoundationModels
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

// MARK: - Context Window Management

/// Check if an error is a context window overflow.
@available(iOS 26, *)
func isContextWindowError(_ error: Error) -> Bool {
    if case LanguageModelSession.GenerationError.exceededContextWindowSize = error { return true }
    return false
}

/// Check if an error is a guardrail violation.
@available(iOS 26, *)
func isGuardrailError(_ error: Error) -> Bool {
    if case LanguageModelSession.GenerationError.guardrailViolation = error { return true }
    return false
}

/// Execute an LLM call, automatically reducing candidate count on context overflow.
/// The `attempt` closure receives the max candidate count to use.
/// Starts at `initialCount` and halves on each overflow, down to `minimumCount`.
@available(iOS 26, *)
func withContextWindowRetry<R>(
    initialCount: Int = 20,
    minimumCount: Int = 5,
    attempt: (_ maxCandidates: Int) async throws -> R
) async throws -> R {
    var count = initialCount
    while count >= minimumCount {
        do {
            return try await attempt(count)
        } catch let error where isContextWindowError(error) {
            let newCount = max(minimumCount, count / 2)
            print("Context window exceeded with \(count) candidates, retrying with \(newCount)")
            if newCount == count { throw error } // Already at minimum
            count = newCount
        }
    }
    return try await attempt(minimumCount)
}

// MARK: - Schedule Tip Generator (Pure Swift — No LLM)

/// Build factual schedule tips from actual event occurrence data.
/// Groups occurrences by event name (merges duplicate EventObjects), detects recurrence,
/// sorts by day-of-week, marks expired events. Returns up to 5 ScheduleTips.
func buildScheduleTips(from events: [EventObjectOccurrence]) -> [ScheduleTip] {
    guard !events.isEmpty else { return [] }

    let now = Date()

    // Formatters in BRC timezone
    var brcCalendar = Calendar(identifier: .gregorian)
    brcCalendar.timeZone = TimeZone.burningManTimeZone

    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEE"
    dayFormatter.timeZone = TimeZone.burningManTimeZone

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mma"
    timeFormatter.timeZone = TimeZone.burningManTimeZone
    timeFormatter.amSymbol = "am"
    timeFormatter.pmSymbol = "pm"

    func shortTime(_ date: Date) -> String {
        let minute = brcCalendar.component(.minute, from: date)
        if minute == 0 {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "ha"
            hourFormatter.timeZone = TimeZone.burningManTimeZone
            hourFormatter.amSymbol = "am"
            hourFormatter.pmSymbol = "pm"
            return hourFormatter.string(from: date)
        }
        return timeFormatter.string(from: date)
    }

    // Group by event NAME to merge duplicate EventObject records
    struct OccurrenceInfo {
        let firstEventUID: String  // for navigation
        let typeEmoji: String
        let typeName: String
        var occurrences: [(day: String, startTime: String, endTime: String, startDate: Date, endDate: Date)]
    }

    var grouped: [String: OccurrenceInfo] = [:]
    var order: [String] = []

    for event in events {
        let key = event.name
        if grouped[key] == nil {
            grouped[key] = OccurrenceInfo(
                firstEventUID: event.event.uid,
                typeEmoji: EventTypeInfo.emoji(for: event.eventTypeCode),
                typeName: EventTypeInfo.displayName(for: event.eventTypeCode),
                occurrences: []
            )
            order.append(key)
        }
        let day = dayFormatter.string(from: event.startDate)
        let start = shortTime(event.startDate)
        let end = shortTime(event.endDate)
        grouped[key]?.occurrences.append((day: day, startTime: start, endTime: end, startDate: event.startDate, endDate: event.endDate))
    }

    // Deduplicate identical occurrences within each group (same day + same time range)
    for key in order {
        guard var info = grouped[key] else { continue }
        var seen = Set<String>()
        info.occurrences = info.occurrences.filter { occ in
            let fingerprint = "\(occ.day)|\(occ.startTime)|\(occ.endTime)"
            return seen.insert(fingerprint).inserted
        }
        grouped[key] = info
    }

    // Sort by earliest occurrence's day-of-week (Sun=1 → Sat=7)
    let sorted = order.sorted { a, b in
        let startA = grouped[a]?.occurrences.first?.startDate ?? .distantFuture
        let startB = grouped[b]?.occurrences.first?.startDate ?? .distantFuture
        return startA < startB
    }

    // Build tips
    var tips: [ScheduleTip] = []
    for name in sorted.prefix(5) {
        guard let info = grouped[name] else { continue }

        let schedule: String
        if info.occurrences.count == 1 {
            let occ = info.occurrences[0]
            schedule = "\(occ.day) \(occ.startTime)-\(occ.endTime)"
        } else {
            let timeRanges = Set(info.occurrences.map { "\($0.startTime)-\($0.endTime)" })
            if timeRanges.count == 1, let timeRange = timeRanges.first {
                let days = info.occurrences.map(\.day).joined(separator: "/")
                schedule = "\(days) \(timeRange)"
            } else {
                let parts = info.occurrences.map { "\($0.day) \($0.startTime)-\($0.endTime)" }
                schedule = parts.joined(separator: ", ")
            }
        }

        let allExpired = info.occurrences.allSatisfy { $0.endDate < now }
        let earliest = info.occurrences.map(\.startDate).min() ?? .distantFuture

        tips.append(ScheduleTip(
            text: "\(name) (\(info.typeEmoji) \(info.typeName)) — \(schedule)",
            eventUID: info.firstEventUID,
            isExpired: allExpired,
            earliestStart: earliest
        ))
    }

    return tips
}

// MARK: - Event Collection Summary

/// Generate schedule tips (pure Swift) and an AI overview (LLM) for a host's events.
/// Tips are always factual. The LLM overview may fail — tips alone are returned in that case.
@available(iOS 26, *)
func generateEventCollectionSummary(
    events: [EventObjectOccurrence],
    hostName: String,
    hostUID: String,
    hostDescription: String? = nil
) async -> EventSummaryContent? {
    guard !events.isEmpty else { return nil }

    // Check cache first
    if let cached = await EventSummaryCache.shared.get(hostUID) {
        return cached
    }

    // Step 1: Build factual tips from real data (instant, no LLM)
    let tips = buildScheduleTips(from: events)

    // Step 2: Generate overview via LLM (may fail — that's OK)
    let overview = await generateEventOverview(events: events, hostName: hostName, hostDescription: hostDescription)

    // Only return content if we have something to show
    guard overview != nil || !tips.isEmpty else { return nil }

    let content = EventSummaryContent(summary: overview, tips: tips)
    await EventSummaryCache.shared.set(hostUID, content: content)
    return content
}

/// LLM-generated overview. Can mention event names and camp offerings, but no timing info.
@available(iOS 26, *)
private func generateEventOverview(
    events: [EventObjectOccurrence],
    hostName: String,
    hostDescription: String? = nil
) async -> String? {
    do {
        return try await withContextWindowRetry(
            initialCount: min(events.count, 20),
            minimumCount: 2
        ) { maxCount in
            let slice = Array(events.prefix(maxCount))

            let result: GenerableEventCollectionSummary = try await retryWithCandidateFiltering(
                candidates: slice,
                minimumCount: 2,
                format: { $0.name }
            ) { batch in
                let text = batch.enumerated().map { idx, event in
                    let type = EventTypeInfo.displayName(for: event.eventTypeCode)
                    let desc = event.description.map { String($0.prefix(120)) } ?? ""
                    return "\(idx + 1). \(event.name) [\(type)]\(desc.isEmpty ? "" : " - \(desc)")"
                }.joined(separator: "\n")

                var prompt = "Events hosted by \(hostName):\n\(text)"
                if let hostDesc = hostDescription, !hostDesc.isEmpty {
                    prompt += "\n\nCamp description: \(String(hostDesc.prefix(200)))"
                }

                let session = LanguageModelSession(instructions: """
                    Summarize what \(hostName) offers in 1-2 short sentences. \
                    You can mention interesting or unique events by name and \
                    describe what they're about. You can also mention camp \
                    offerings from the description. Do NOT mention any times, \
                    days, or schedules — those are shown separately.
                    """)
                return try await session.respond(
                    to: Prompt(prompt),
                    generating: GenerableEventCollectionSummary.self
                ).content
            }
            return result.summary
        }
    } catch {
        print("Event overview generation failed: \(error)")
        return nil
    }
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
