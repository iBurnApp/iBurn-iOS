//
//  Vibe.swift
//  iBurn
//
//  Suggestion chips and free-text → event-type mapping for the AI "Right Now" guide.
//  Pure Swift (no FoundationModels) so it stays unit-testable. Event type codes match
//  EventTypeInfo (the codes actually stored in PlayaDB for the bundled dataset).
//
//  Created by Claude Code on 5/29/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation

/// A tappable suggestion on the Right Now screen. Tapping seeds the query (`vibe`),
/// a discovery `lean`, and an optional event-type constraint.
struct SuggestionChip: Identifiable, Sendable {
    let id: String
    let label: String
    let icon: String
    /// Seed text used as the vibe / keyword search.
    let vibe: String
    let lean: DiscoveryLean
    /// Event type codes to constrain event candidates. nil = no constraint.
    let eventTypeCodes: Set<String>?
    /// True when results shouldn't be region-scoped (e.g. roaming art cars have no fixed GPS).
    let nonRegional: Bool

    init(
        id: String,
        label: String,
        icon: String,
        vibe: String,
        lean: DiscoveryLean = .balanced,
        eventTypeCodes: Set<String>? = nil,
        nonRegional: Bool = false
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.vibe = vibe
        self.lean = lean
        self.eventTypeCodes = eventTypeCodes
        self.nonRegional = nonRegional
    }
}

extension SuggestionChip {
    /// The chips shown across the top of the Right Now screen.
    static let all: [SuggestionChip] = [
        SuggestionChip(id: "coffee", label: "Coffee", icon: "cup.and.saucer.fill",
                       vibe: "coffee", eventTypeCodes: ["tea", "food"]),
        SuggestionChip(id: "music", label: "Live music", icon: "music.note",
                       vibe: "live music", eventTypeCodes: ["live", "prty"]),
        SuggestionChip(id: "dance", label: "Dance", icon: "music.quarternote.3",
                       vibe: "dance party", eventTypeCodes: ["prty", "perf"]),
        SuggestionChip(id: "food", label: "Food", icon: "fork.knife",
                       vibe: "food", eventTypeCodes: ["food", "tea"]),
        SuggestionChip(id: "workshops", label: "Workshops", icon: "graduationcap.fill",
                       vibe: "workshop class", eventTypeCodes: ["work"]),
        SuggestionChip(id: "wellness", label: "Yoga & wellness", icon: "figure.mind.and.body",
                       vibe: "yoga wellness", eventTypeCodes: ["medt", "hlng", "sprt"]),
        SuggestionChip(id: "fire", label: "Fire art", icon: "flame.fill",
                       vibe: "fire", eventTypeCodes: ["fire"]),
        SuggestionChip(id: "artcars", label: "Art cars", icon: "car.fill",
                       vibe: "art car mutant vehicle", eventTypeCodes: nil, nonRegional: true),
        SuggestionChip(id: "chill", label: "Quiet & chill", icon: "moon.zzz.fill",
                       vibe: "quiet chill ambient relax", eventTypeCodes: ["medt", "hlng"]),
        SuggestionChip(id: "surprise", label: "Surprise me", icon: "dice.fill",
                       vibe: "", lean: .surprise),
    ]
}

/// Map free-text vibe to a set of event type codes, or nil when nothing matches
/// (in which case events fall back to full-text search on the vibe).
/// Codes match EventTypeInfo / the values stored in PlayaDB.
func eventTypeCodes(forVibe vibe: String) -> Set<String>? {
    let text = vibe.lowercased()
    guard !text.isEmpty else { return nil }

    // keyword -> codes
    let rules: [(needles: [String], codes: [String])] = [
        (["coffee", "tea", "chai", "espresso", "latte"], ["tea", "food"]),
        (["food", "eat", "snack", "dinner", "breakfast", "brunch", "lunch", "grilled"], ["food", "tea"]),
        (["live music", "band", "concert", "jazz", "acoustic"], ["live"]),
        (["music", "dj", "rave", "party", "dance", "club", "beats", "disco"], ["prty"]),
        (["workshop", "class", "learn", "talk", "lecture", "skill"], ["work"]),
        (["yoga", "wellness", "meditat", "breathwork", "movement", "fitness", "stretch"], ["medt"]),
        (["massage", "spa", "healing", "reiki", "bodywork"], ["hlng"]),
        (["self care", "selfcare", "care"], ["sprt"]),
        (["fire", "flame", "burn", "spectacle"], ["fire"]),
        (["performance", "show", "theater", "theatre", "circus", "cabaret"], ["perf"]),
        (["game", "games", "play", "competition", "tournament"], ["game"]),
        (["ritual", "ceremony", "ceremon", "sacred", "temple"], ["cere"]),
        (["kid", "kids", "family", "child"], ["kid"]),
        (["parade", "procession"], ["prde"]),
        (["art", "craft", "make", "create"], ["arts"]),
        (["chill", "quiet", "relax", "ambient", "lounge", "calm"], ["medt", "hlng"]),
    ]

    var codes = Set<String>()
    for rule in rules where rule.needles.contains(where: { text.contains($0) }) {
        codes.formUnion(rule.codes)
    }
    return codes.isEmpty ? nil : codes
}
