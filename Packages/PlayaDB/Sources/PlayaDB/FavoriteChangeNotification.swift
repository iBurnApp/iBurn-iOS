//
//  FavoriteChangeNotification.swift
//  PlayaDB
//
//  Created by Claude Code on 8/9/26.
//  Copyright © 2026 Burning Man Earth. All rights reserved.
//
//  A broadcast for "the user just favorited (or unfavorited) something", for the handful of
//  places that want to react to the *act* rather than to the resulting state.
//
//  Lists and detail screens don't need this — they already redraw from the GRDB observations
//  in `observeObjects(filter:)`, which report the new state without saying what caused it.
//  What those observations can't tell you is direction ("added" vs "removed") or that a
//  person did it just now, which is exactly what a confirmation flourish is about.
//
//  This lives in the package rather than in the app because there is no app-level seam that
//  sees every toggle: the per-type `ObjectListDataProvider`s cover the browse lists, but
//  Detail, Right Now, Nearby, the map's visible-pins sheet, Recently Viewed, Visits, and
//  global search all call `PlayaDB.toggleFavorite` directly. `PlayaDBImpl.toggleFavorite` is
//  the single point they all pass through, so it's the only place one post covers them all.
//

import Foundation

public extension Notification.Name {
    /// Posted on the main queue right after `PlayaDB.toggleFavorite` commits, carrying the
    /// state the object landed in. Deliberately *not* posted by `setFavorite`, which is how
    /// watch sync and merges write — those aren't a person tapping a heart.
    ///
    /// `userInfo` keys are in `PlayaDBFavoriteChange`.
    static let playaDBFavoriteDidChange = Notification.Name("PlayaDBFavoriteDidChange")
}

/// `userInfo` keys for `Notification.Name.playaDBFavoriteDidChange`.
public enum PlayaDBFavoriteChange {
    /// `Bool` — true when the toggle *added* a favorite, false when it removed one.
    public static let isFavoriteKey = "isFavorite"
    /// `String` — the object's uid.
    public static let uidKey = "uid"
    /// `String` — the object's type, as an `ObjectType` raw value.
    public static let objectTypeKey = "objectType"

    /// Reads the direction of a change out of a notification. Returns nil for anything that
    /// isn't one of these, so an observer can't mistake a malformed post for a removal.
    public static func isFavorite(from notification: Notification) -> Bool? {
        notification.userInfo?[isFavoriteKey] as? Bool
    }

    static func post(objectType: String, uid: String, isFavorite: Bool) {
        let userInfo: [String: Any] = [
            isFavoriteKey: isFavorite,
            uidKey: uid,
            objectTypeKey: objectType,
        ]
        // The write finished on whatever executor the caller was on; observers are UI.
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .playaDBFavoriteDidChange,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}
