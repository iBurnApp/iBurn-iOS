//
//  FavoriteSeriesToast.swift
//  iBurn
//
//  Created by Claude Code on 8/10/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//

import Foundation
import PlayaDB

/// The offer made right after someone favorites one showing of a recurring event:
/// *"you favorited this Tuesday morning — want the other four too?"*
///
/// Favorites became per occurrence so that tapping a heart means the session you were
/// looking at. That is the right default, but it makes the old behaviour (favorite one,
/// get them all) impossible to reach — hence this, offered once, at the moment the
/// question is live, and never as a modal.
struct FavoriteSeriesToast: Equatable {
    /// API event uid whose remaining occurrences the action favorites.
    let eventUID: String
    /// Occurrence the user just favorited. Not touched by the action (it's already on).
    let favoritedIdentity: String
    /// How many *other* occurrences of this event exist. Always ≥ 1.
    let remainingCount: Int
    /// Event title, for the toast copy.
    let eventName: String

    var message: String { "Favorited this occurrence of \(eventName)." }

    var actionTitle: String {
        remainingCount == 1 ? "Favorite the other one" : "Favorite all \(remainingCount + 1)"
    }
}

// MARK: - Eligibility

/// Whether a favorite change should raise the "favorite the whole series?" offer, and
/// what it needs to know to do so.
///
/// A pure decision, split out from the notification plumbing and the window hosting so the
/// rule can be read (and tested) on its own. The rule is deliberately narrow — a toast that
/// shows up when it isn't useful is worse than no toast:
///
/// 1. The change **added** a favorite. Unfavoriting is never followed by an offer.
/// 2. It was an **event occurrence** (a composite `EventFavoriteKey`), not a camp, not a
///    piece of art, and not a bare event — a bare event heart already means the series.
/// 3. The event has **more than one occurrence**. A one-off has no series to offer.
enum FavoriteSeriesToastEligibility {
    /// The event uid whose occurrence count needs looking up, or nil when this change can
    /// never raise a toast. Cheap, synchronous, no database.
    static func candidateEventUID(objectType: String, uid: String, isFavorite: Bool) -> String? {
        guard isFavorite,
              objectType == DataObjectType.event.rawValue,
              let parts = EventFavoriteKey.split(uid) else { return nil }
        return parts.eventUID
    }

    /// The toast to show, given the occurrence count the lookup came back with.
    /// Nil when the event turned out not to recur (or vanished between the two steps).
    static func toast(
        eventUID: String,
        favoritedIdentity: String,
        eventName: String,
        occurrenceCount: Int
    ) -> FavoriteSeriesToast? {
        let remaining = occurrenceCount - 1
        guard remaining >= 1 else { return nil }
        return FavoriteSeriesToast(
            eventUID: eventUID,
            favoritedIdentity: favoritedIdentity,
            remainingCount: remaining,
            eventName: eventName
        )
    }
}
