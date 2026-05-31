//
//  RightNowWorkflow.swift
//  iBurn
//
//  The single AI Guide flow: "what's near you happening now, and what to do next."
//  Given a vibe (+ time window + place), returns a "Now near you" set and a "Next" set.
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

#if canImport(FoundationModels)
import Foundation
import CoreLocation
import MapKit
import FoundationModels
@preconcurrency import PlayaDB

// MARK: - Result Types

struct RightNowItem: Sendable, Identifiable {
    var id: String { uid }
    let uid: String
    let name: String
    let type: DataObjectType
    let pitch: String
    let walkMinutes: Int?
    /// Formatted start time for time-bound events (e.g. "3:00 PM"); nil for art/camps.
    let timeInfo: String?
}

struct RightNowResult: Sendable {
    let intro: String
    let now: [RightNowItem]
    let next: [RightNowItem]

    var isEmpty: Bool { now.isEmpty && next.isEmpty }
}

// MARK: - Candidate (internal, also used by tests)

/// A pre-LLM candidate gathered from the DB.
struct RNCandidate: Sendable {
    let uid: String
    let name: String
    let type: DataObjectType
    let coordinate: CLLocationCoordinate2D?
    /// Event start (nil for timeless art/camps).
    let startDate: Date?
    /// Formatted start time for events.
    let timeInfo: String?
    var walkMinutes: Int?
}

enum RNBucket: Sendable { case now, next }

/// Sendable curation result, decoupled from the @Generable type so it can cross a TaskGroup.
struct CuratedPick: Sendable { let uid: String; let pitch: String }
struct Curated: Sendable { let intro: String; let now: [CuratedPick]; let next: [CuratedPick] }

/// Run `work`, returning nil if it doesn't finish within `seconds` (or returns nil itself).
/// The on-device model can be slow or stall on first use; this keeps the UI from hanging.
func runWithTimeout<T: Sendable>(seconds: Double, _ work: @Sendable @escaping () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await work() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

// MARK: - Candidate Gathering (pure, no LLM — unit testable)

/// Gather "now" and "next" candidates from the database. No LLM involved so this is
/// deterministic and testable with an in-memory PlayaDB.
///
/// Event-first: "now" = events happening right now (when the window covers the present),
/// "next" = events starting within the window. Camps/art are only used as a fallback when
/// no events match (so the screen is never just a pile of camps when events exist).
///
/// - `includeHappeningNow`: when true (the window contains the present), currently-happening
///   events are pulled into the "now" bucket.
func gatherRightNowCandidates(
    playaDB: PlayaDB,
    region: MKCoordinateRegion?,
    origin: CLLocationCoordinate2D,
    now: Date,
    windowStart: Date,
    windowEnd: Date,
    vibe: String,
    lean: DiscoveryLean,
    favoriteUIDs: Set<String>,
    includeHappeningNow: Bool,
    perBucketCap: Int = 10
) async throws -> (now: [RNCandidate], next: [RNCandidate]) {
    let codes = eventTypeCodes(forVibe: vibe)
    let trimmedVibe = vibe.trimmingCharacters(in: .whitespacesAndNewlines)
    let excludeFavorites = (lean == .surprise)
    let formatter = brcTimeFormatter()

    func keep(_ uid: String) -> Bool {
        excludeFavorites ? !favoriteUIDs.contains(uid) : true
    }
    func walk(_ coord: CLLocationCoordinate2D?) -> Int? {
        guard let coord else { return nil }
        return playaWalkMinutes(from: origin, to: coord)
    }
    func eventCandidate(_ occ: EventObjectOccurrence) -> RNCandidate {
        let coord = eventCoordinate(occ)
        return RNCandidate(
            uid: occ.event.uid, name: occ.event.name, type: .event,
            coordinate: coord, startDate: occ.startDate,
            timeInfo: formatter.string(from: occ.startDate), walkMinutes: walk(coord)
        )
    }

    // Camps & art matching the vibe in the area. They serve double duty: they're event
    // hosts (we expand them to their events below) and the fallback when no events exist.
    var artFilter = ArtFilter.all
    artFilter.region = region
    if !trimmedVibe.isEmpty { artFilter.searchText = trimmedVibe }
    let artInArea = try await playaDB.fetchArt(filter: artFilter)

    var campFilter = CampFilter.all
    campFilter.region = region
    if !trimmedVibe.isEmpty { campFilter.searchText = trimmedVibe }
    let campsInArea = try await playaDB.fetchCamps(filter: campFilter)

    // Collect candidate event occurrences from multiple sources:
    //  (a) the region-scoped event query (catches events whose host GPS is in the join),
    //  (b) events hosted by the matched camps / art — this catches events the region query
    //      misses when the event's host GPS isn't populated, and is what surfaces "the camp
    //      that's serving coffee right now" as its actual event.
    func regionQuery(_ typeCodes: Set<String>?) async throws -> [EventObjectOccurrence] {
        var filter = EventFilter.all
        filter.region = region
        filter.startDate = max(windowStart, now)
        filter.endDate = windowEnd
        filter.eventTypeCodes = typeCodes
        return try await playaDB.fetchEvents(filter: filter)
    }
    var occurrences: [EventObjectOccurrence] = []
    var regionOccs = try await regionQuery(codes)
    if regionOccs.isEmpty, codes != nil { regionOccs = try await regionQuery(nil) }
    occurrences += regionOccs
    for camp in campsInArea.prefix(10) {
        occurrences += (try? await playaDB.fetchEvents(hostedByCampUID: camp.uid)) ?? []
    }
    for art in artInArea.prefix(10) {
        occurrences += (try? await playaDB.fetchEvents(locatedAtArtUID: art.uid)) ?? []
    }

    // Classify occurrences that overlap the window (and haven't ended) into now / next.
    let windowFloor = max(windowStart, now)
    var nowEvents: [RNCandidate] = []
    var nextEvents: [RNCandidate] = []
    var seenEvents = Set<String>()
    for occ in occurrences.sorted(by: { $0.startDate < $1.startDate }) {
        let uid = occ.event.uid
        guard keep(uid), seenEvents.insert(uid).inserted else { continue }
        guard occ.startDate < windowEnd, occ.endDate > windowFloor else { continue }
        if includeHappeningNow, occ.startDate <= now, occ.endDate > now {
            nowEvents.append(eventCandidate(occ))
        } else {
            nextEvents.append(eventCandidate(occ))
        }
    }

    // Events lead. When any exist, return only events — no camps/art mixed in.
    if !nowEvents.isEmpty || !nextEvents.isEmpty {
        return (Array(nowEvents.prefix(perBucketCap)), Array(nextEvents.prefix(perBucketCap)))
    }

    // --- Fallback: no events in the window → the matched places themselves. ---
    var places: [RNCandidate] = []
    var seenPlaces = Set<String>()
    for obj in artInArea {
        guard keep(obj.uid), seenPlaces.insert(obj.uid).inserted else { continue }
        let coord = coordinate(lat: obj.gpsLatitude, lon: obj.gpsLongitude)
        places.append(RNCandidate(uid: obj.uid, name: obj.name, type: .art,
                                  coordinate: coord, startDate: nil, timeInfo: nil, walkMinutes: walk(coord)))
    }
    for obj in campsInArea {
        guard keep(obj.uid), seenPlaces.insert(obj.uid).inserted else { continue }
        let coord = coordinate(lat: obj.gpsLatitude, lon: obj.gpsLongitude)
        places.append(RNCandidate(uid: obj.uid, name: obj.name, type: .camp,
                                  coordinate: coord, startDate: nil, timeInfo: nil, walkMinutes: walk(coord)))
    }
    if vibeMentionsVehicles(trimmedVibe) || (trimmedVibe.isEmpty && lean == .surprise) {
        var mvFilter = MutantVehicleFilter.all
        if !trimmedVibe.isEmpty { mvFilter.searchText = trimmedVibe }
        for obj in try await playaDB.fetchMutantVehicles(filter: mvFilter) {
            guard keep(obj.uid), seenPlaces.insert(obj.uid).inserted else { continue }
            places.append(RNCandidate(uid: obj.uid, name: obj.name, type: .mutantVehicle,
                                      coordinate: nil, startDate: nil, timeInfo: nil, walkMinutes: nil))
        }
    }

    places.sort { ($0.walkMinutes ?? Int.max) < ($1.walkMinutes ?? Int.max) }
    return (Array(places.prefix(perBucketCap)), [])
}

// MARK: - Helpers

private func coordinate(lat: Double?, lon: Double?) -> CLLocationCoordinate2D? {
    guard let lat, let lon else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
}

private func eventCoordinate(_ occ: EventObjectOccurrence) -> CLLocationCoordinate2D? {
    coordinate(lat: occ.event.gpsLatitude, lon: occ.event.gpsLongitude)
}

private func vibeMentionsVehicles(_ vibe: String) -> Bool {
    let t = vibe.lowercased()
    return t.contains("art car") || t.contains("mutant") || t.contains("vehicle") || t.contains("car")
}

private func brcTimeFormatter() -> DateFormatter {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    f.timeZone = .burningManTimeZone
    return f
}

extension MKCoordinateRegion {
    /// Simple bounding-box containment check.
    func contains(_ coord: CLLocationCoordinate2D) -> Bool {
        abs(coord.latitude - center.latitude) <= span.latitudeDelta / 2 &&
        abs(coord.longitude - center.longitude) <= span.longitudeDelta / 2
    }
}

// MARK: - Generable Output

@available(iOS 26, *)
@Generable
struct GenerableRightNowPick {
    @Guide(description: "The exact uid from the candidate list")
    var uid: String
    @Guide(description: "Why it's worth it right now, under 15 words, concrete and grounded in the data")
    var pitch: String
}

@available(iOS 26, *)
@Generable
struct GenerableRightNowResponse {
    @Guide(description: "One short, concrete opening line. No hype.")
    var intro: String
    @Guide(description: "Best picks happening now or to go see near the user", .count(0...5))
    var now: [GenerableRightNowPick]
    @Guide(description: "Best picks coming up soon", .count(0...5))
    var next: [GenerableRightNowPick]
}

// MARK: - Workflow

@available(iOS 26, *)
struct RightNowWorkflow: Workflow {
    let name = "RightNow"

    func execute(context: WorkflowContext, onProgress: @escaping (WorkflowProgress) -> Void) async throws -> RightNowResult {
        // Step 1: taste
        onProgress(.stepStarted(name: "taste", description: "Reading your favorites"))
        let favorites = try await context.playaDB.getFavorites()
        let favoriteUIDs = Set(favorites.map(\.uid))
        let tasteProfile: String
        if context.lean == .surprise || favorites.isEmpty {
            tasteProfile = ""
        } else {
            tasteProfile = favorites.prefix(8).map { "\($0.objectType.rawValue): \($0.name)" }.joined(separator: "\n")
        }
        onProgress(.stepCompleted(name: "taste"))

        // Step 2: gather candidates
        onProgress(.stepStarted(name: "gather", description: "Finding what's around you"))
        let origin = context.region?.center ?? context.location?.coordinate ?? YearSettings.manCenterCoordinate
        let filterRegion = context.region ?? context.location.map {
            MKCoordinateRegion(center: $0.coordinate,
                               span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
        }
        let includeNow = context.windowStart <= context.date && context.date <= context.windowEnd

        let (nowCands, nextCands) = try await gatherRightNowCandidates(
            playaDB: context.playaDB,
            region: filterRegion,
            origin: origin,
            now: context.date,
            windowStart: context.windowStart,
            windowEnd: context.windowEnd,
            vibe: context.vibe,
            lean: context.lean,
            favoriteUIDs: favoriteUIDs,
            includeHappeningNow: includeNow
        )
        onProgress(.stepCompleted(name: "gather"))

        guard !nowCands.isEmpty || !nextCands.isEmpty else {
            return RightNowResult(
                intro: "Nothing matching nearby right now — try a wider area or a different vibe.",
                now: [], next: []
            )
        }

        // Step 3: LLM curation + pitch — best-effort, bounded by a timeout. If the model
        // stalls / is filtered / is still loading, fall back to the gathered candidates so
        // the screen never hangs.
        onProgress(.stepStarted(name: "pick", description: "Picking the best"))
        let candidateByUID = Dictionary(
            (nowCands + nextCands).map { ($0.uid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let tagged: [(cand: RNCandidate, bucket: RNBucket)] =
            nowCands.map { ($0, .now) } + nextCands.map { ($0, .next) }

        let curated: Curated? = await runWithTimeout(seconds: Self.curationTimeoutSeconds) { [self] in
            do {
                return try await curate(tagged: tagged, vibe: context.vibe, taste: tasteProfile)
            } catch {
                #if DEBUG
                print("[RightNow] curation failed: \(error)")
                #endif
                return nil
            }
        }
        onProgress(.stepCompleted(name: "pick"))

        var used = Set<String>()
        let nowItems: [RightNowItem]
        let nextItems: [RightNowItem]
        let intro: String
        if let curated, !(curated.now.isEmpty && curated.next.isEmpty) {
            // Resolve picks back against the candidate set (drops any hallucinated uids).
            nowItems = items(from: curated.now, byUID: candidateByUID, used: &used)
            nextItems = items(from: curated.next, byUID: candidateByUID, used: &used)
            intro = curated.intro.isEmpty ? "Here's what's around you." : curated.intro
        } else {
            // No AI picks (timed out / filtered / model unavailable) — show the candidates.
            nowItems = fallbackItems(nowCands, used: &used)
            nextItems = fallbackItems(nextCands, used: &used)
            intro = "Here's what's around you right now."
        }

        if nowItems.isEmpty && nextItems.isEmpty {
            return RightNowResult(intro: "Nothing stood out — try a different vibe or area.",
                                  now: [], next: [])
        }
        return RightNowResult(intro: intro, now: nowItems, next: nextItems)
    }

    private static let curationTimeoutSeconds: Double = 22

    /// Run the guarded LLM curation and map it to a Sendable `Curated`.
    private func curate(
        tagged: [(cand: RNCandidate, bucket: RNBucket)],
        vibe: String,
        taste: String
    ) async throws -> Curated {
        let response: GenerableRightNowResponse = try await withContextWindowRetry(
            initialCount: min(tagged.count, 12),
            minimumCount: 4
        ) { maxCount in
            try await retryWithCandidateFiltering(
                candidates: Array(tagged.prefix(maxCount)),
                minimumCount: 2,
                format: { candidateLine($0.cand) }
            ) { batch in
                try await self.generate(batch: batch, vibe: vibe, taste: taste)
            }
        }
        return Curated(
            intro: response.intro,
            now: response.now.map { CuratedPick(uid: $0.uid, pitch: $0.pitch) },
            next: response.next.map { CuratedPick(uid: $0.uid, pitch: $0.pitch) }
        )
    }

    /// Resolve LLM picks to display items, skipping unknown/duplicate uids.
    private func items(
        from picks: [CuratedPick],
        byUID: [String: RNCandidate],
        used: inout Set<String>
    ) -> [RightNowItem] {
        picks.compactMap { pick in
            guard let c = byUID[pick.uid], used.insert(pick.uid).inserted else { return nil }
            return RightNowItem(uid: c.uid, name: c.name, type: c.type, pitch: pick.pitch,
                                walkMinutes: c.walkMinutes, timeInfo: c.timeInfo)
        }
    }

    /// Present gathered candidates directly (no AI pitch) when curation is unavailable.
    private func fallbackItems(
        _ candidates: [RNCandidate],
        used: inout Set<String>,
        limit: Int = 5
    ) -> [RightNowItem] {
        var out: [RightNowItem] = []
        for c in candidates where used.insert(c.uid).inserted {
            out.append(RightNowItem(uid: c.uid, name: c.name, type: c.type, pitch: "",
                                    walkMinutes: c.walkMinutes, timeInfo: c.timeInfo))
            if out.count >= limit { break }
        }
        return out
    }

    private func generate(
        batch: [(cand: RNCandidate, bucket: RNBucket)],
        vibe: String,
        taste: String
    ) async throws -> GenerableRightNowResponse {
        let nowText = batch.filter { $0.bucket == .now }.map { candidateLine($0.cand) }.joined(separator: "\n")
        let nextText = batch.filter { $0.bucket == .next }.map { candidateLine($0.cand) }.joined(separator: "\n")

        var prompt = "Vibe: \(vibe.isEmpty ? "anything good" : vibe)\n"
        if !taste.isEmpty { prompt += "\nUser tends to like:\n\(taste)\n" }
        prompt += "\nNOW (happening or to go see near them):\n\(nowText.isEmpty ? "(none)" : nowText)"
        prompt += "\n\nNEXT (coming up soon):\n\(nextText.isEmpty ? "(none)" : nextText)"

        let session = LanguageModelSession(instructions: """
            You are a concise Burning Man guide. From the candidates, pick the best few for NOW \
            and the best few for NEXT. Each candidate is tagged with its type (event, camp, art, \
            mutantVehicle) — describe it accurately and never call a camp or art piece an "event". \
            Use only the exact uids provided. Keep each pitch under 15 words, concrete and grounded \
            in the data — no hype, no invented details.
            """)
        return try await session.respond(
            to: Prompt(prompt),
            generating: GenerableRightNowResponse.self
        ).content
    }
}

/// One-line candidate description for the LLM prompt.
func candidateLine(_ c: RNCandidate) -> String {
    var s = "uid:\(c.uid) — \(c.type.rawValue): \(c.name)"
    if let t = c.timeInfo { s += " @ \(t)" }
    if let w = c.walkMinutes { s += " (~\(w)min walk)" }
    return s
}

#endif
