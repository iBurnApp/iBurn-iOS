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

// MARK: - Candidate Gathering (pure, no LLM — unit testable)

/// Gather "now" and "next" candidates from the database. No LLM involved so this is
/// deterministic and testable with an in-memory PlayaDB.
///
/// - `includeHappeningNow`: when true (the window contains the present), currently-happening
///   events are pulled into the "now" bucket. Timeless art/camps always go to "now".
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

    var nowCandidates: [RNCandidate] = []
    var nextCandidates: [RNCandidate] = []
    var seen = Set<String>()

    // --- Events happening now (only when the window covers the present) ---
    if includeHappeningNow {
        let current = try await playaDB.fetchCurrentEvents(now)
        for occ in current {
            let uid = occ.event.uid
            guard keep(uid), seen.insert(uid).inserted else { continue }
            if let codes, !codes.contains(occ.eventTypeCode) { continue }
            let coord = eventCoordinate(occ)
            if let region, let coord, !region.contains(coord) { continue }
            nowCandidates.append(RNCandidate(
                uid: uid, name: occ.event.name, type: .event,
                coordinate: coord, startDate: occ.startDate,
                timeInfo: formatter.string(from: occ.startDate),
                walkMinutes: walk(coord)
            ))
        }
    }

    // --- Upcoming events starting within the window ("next") ---
    // `startDate >= now` already excludes anything that has started/ended, so we don't
    // also set `includeExpired` (which filters against the real current date and would
    // drop events when querying a window in the past, e.g. tests / off-season).
    var eventFilter = EventFilter.all
    eventFilter.region = region
    eventFilter.startDate = max(windowStart, now)
    eventFilter.endDate = windowEnd
    eventFilter.eventTypeCodes = codes
    let upcoming = try await playaDB.fetchEvents(filter: eventFilter)
    for occ in upcoming.sorted(by: { $0.startDate < $1.startDate }) {
        let uid = occ.event.uid
        guard keep(uid), seen.insert(uid).inserted else { continue }
        let coord = eventCoordinate(occ)
        nextCandidates.append(RNCandidate(
            uid: uid, name: occ.event.name, type: .event,
            coordinate: coord, startDate: occ.startDate,
            timeInfo: formatter.string(from: occ.startDate),
            walkMinutes: walk(coord)
        ))
    }

    // --- Timeless art & camps near the place ("now near you") ---
    var artFilter = ArtFilter.all
    artFilter.region = region
    if !trimmedVibe.isEmpty { artFilter.searchText = trimmedVibe }
    let art = try await playaDB.fetchArt(filter: artFilter)
    for obj in art {
        guard keep(obj.uid), seen.insert(obj.uid).inserted else { continue }
        let coord = coordinate(lat: obj.gpsLatitude, lon: obj.gpsLongitude)
        nowCandidates.append(RNCandidate(
            uid: obj.uid, name: obj.name, type: .art,
            coordinate: coord, startDate: nil, timeInfo: nil, walkMinutes: walk(coord)
        ))
    }

    var campFilter = CampFilter.all
    campFilter.region = region
    if !trimmedVibe.isEmpty { campFilter.searchText = trimmedVibe }
    let camps = try await playaDB.fetchCamps(filter: campFilter)
    for obj in camps {
        guard keep(obj.uid), seen.insert(obj.uid).inserted else { continue }
        let coord = coordinate(lat: obj.gpsLatitude, lon: obj.gpsLongitude)
        nowCandidates.append(RNCandidate(
            uid: obj.uid, name: obj.name, type: .camp,
            coordinate: coord, startDate: nil, timeInfo: nil, walkMinutes: walk(coord)
        ))
    }

    // --- Mutant vehicles (roaming, no GPS → never region-scoped) ---
    if vibeMentionsVehicles(trimmedVibe) || (trimmedVibe.isEmpty && lean == .surprise) {
        var mvFilter = MutantVehicleFilter.all
        if !trimmedVibe.isEmpty { mvFilter.searchText = trimmedVibe }
        let mvs = try await playaDB.fetchMutantVehicles(filter: mvFilter)
        for obj in mvs {
            guard keep(obj.uid), seen.insert(obj.uid).inserted else { continue }
            nowCandidates.append(RNCandidate(
                uid: obj.uid, name: obj.name, type: .mutantVehicle,
                coordinate: nil, startDate: nil, timeInfo: nil, walkMinutes: nil
            ))
        }
    }

    // Order "now" by walking distance (closest first); cap each bucket.
    nowCandidates.sort { ($0.walkMinutes ?? Int.max) < ($1.walkMinutes ?? Int.max) }
    return (Array(nowCandidates.prefix(perBucketCap)), Array(nextCandidates.prefix(perBucketCap)))
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

        // Step 3: one LLM curation + pitch call
        onProgress(.stepStarted(name: "pick", description: "Picking the best"))
        let candidateByUID = Dictionary(
            (nowCands + nextCands).map { ($0.uid, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let tagged: [(cand: RNCandidate, bucket: RNBucket)] =
            nowCands.map { ($0, .now) } + nextCands.map { ($0, .next) }

        let response: GenerableRightNowResponse = try await withContextWindowRetry(
            initialCount: min(tagged.count, 18),
            minimumCount: 4
        ) { maxCount in
            try await retryWithCandidateFiltering(
                candidates: Array(tagged.prefix(maxCount)),
                minimumCount: 2,
                format: { candidateLine($0.cand) }
            ) { batch in
                try await self.generate(batch: batch, vibe: context.vibe, taste: tasteProfile)
            }
        }
        onProgress(.stepCompleted(name: "pick"))

        // Resolve picks back against the candidate set (drops any hallucinated uids).
        var usedNow = Set<String>()
        let nowItems = response.now.compactMap { pick -> RightNowItem? in
            guard let c = candidateByUID[pick.uid], usedNow.insert(pick.uid).inserted else { return nil }
            return RightNowItem(uid: c.uid, name: c.name, type: c.type, pitch: pick.pitch,
                                walkMinutes: c.walkMinutes, timeInfo: c.timeInfo)
        }
        var usedNext = usedNow
        let nextItems = response.next.compactMap { pick -> RightNowItem? in
            guard let c = candidateByUID[pick.uid], usedNext.insert(pick.uid).inserted else { return nil }
            return RightNowItem(uid: c.uid, name: c.name, type: c.type, pitch: pick.pitch,
                                walkMinutes: c.walkMinutes, timeInfo: c.timeInfo)
        }

        if nowItems.isEmpty && nextItems.isEmpty {
            return RightNowResult(intro: "Nothing stood out just now — try a different vibe or area.",
                                  now: [], next: [])
        }
        return RightNowResult(intro: response.intro, now: nowItems, next: nextItems)
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
            and the best few for NEXT. Use only the exact uids provided. Keep each pitch under 15 \
            words, concrete and grounded in the data — no hype, no invented details.
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
