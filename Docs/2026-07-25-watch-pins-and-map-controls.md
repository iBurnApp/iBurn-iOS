# watchOS: user map pins (bike/home/star) + map control rework

Date: 2026-07-25 (Pacific)
Branch: `watchos-updates`
Status: **complete** — 222 PlayaDB tests green, both apps build clean, and the
full phone↔watch round trip (create both directions + delete propagation) was
verified on paired Ultra 3 / iPhone 17 sims. See "Results".

## High-Level Plan

Two asks from this session, plus a gap analysis of the watch app.

1. **User map pins on the watch, synced with the phone.** "Add a pin for my
   bike" is the canonical watch use case (you park, you walk away, you need it
   back at 4am). The phone already has pins; the watch has none, and nothing
   syncs them.
2. **Rework the map's location/tracking button.** The current control is a
   hand-rolled black circle floating at `bottomTrailing` — it doesn't match the
   system toolbar buttons used elsewhere in the app, its hit target is ~30 pt
   (below the 44 pt minimum), and bottom-trailing on a watch pushes it into the
   display's corner curvature.

### Gap analysis — what the watch app has vs. what's missing

Shipped today: offline vector map (crown zoom / drag pan / compass), Browse
(Nearby, Camps, Art, Vehicles, Events), Favorites + visit status, object detail,
compass navigation to a POI, and phone↔watch favorites/visit-status sync.

Missing, roughly in value order:

| Gap | Notes |
| --- | --- |
| **User map pins** | *This session.* Phone has them (`user_map_pins`), watch has nothing, no sync. |
| **WidgetKit complication / Smart Stack** | Called out as a non-MVP follow-up in the 2026-07-03 plan and still absent. "Distance to my bike" is the obvious first complication. Needs an App Group. |
| **Nearest amenity (toilet / medical / ranger)** | The phone's sidebar has "find nearest potty"; `toilets.geojson` is already bundled on the watch, so this is cheap and high-value. |
| **Background location** | The watch stops updating location when the app backgrounds. Walking back to a pin from the wrist wants `CLBackgroundActivitySession` (or a workout session). |
| **Data updates** | The watch seeds from the bundle and never refreshes. The phone downloads updated API data mid-event; the watch stays on whatever shipped. |
| **Event reminders** | No local notifications for favorited events. |
| **Embargo unlock flag** | MVP plan intended to sync the phone's embargo-unlocked state; never implemented. Watch relies on GPS simply being absent pre-gates. |
| **Global search** | Only per-list `.searchable`; no cross-type search. |
| **Always-On display** | No luminance-reduced map rendering / `.privacySensitive` handling. |
| **Breadcrumb trails** | Phone-only. |

## Technical Details

### 1. PlayaDB — pin sync primitives

Pins live in `user_map_pins` (`Packages/PlayaDB/Sources/PlayaDB/Models/UserMapPin.swift`)
and are already the source of truth on the phone: `UserMapViewAdapter` writes
through `saveUserMapPin`/`deleteUserMapPin`, and `FilteredMapDataSource` renders
them from `observeUserMapPins`. So a pin arriving from the watch shows up on the
phone map with no extra wiring.

**Problem: deletions can't propagate.** Sync is a last-writer-wins snapshot
exchange (same as favorites). With hard deletes, a row missing from a peer's
snapshot is ambiguous — "never created here" vs "deleted there" — so a deleted
pin resurrects on the next push.

**Fix: tombstones.**

- Migration `v4-pin-sync`: `ALTER TABLE user_map_pins ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0`.
- `deleteUserMapPin(id:)` becomes a soft delete (`is_deleted = 1`, `modified_date = now`).
- `fetchUserMapPins()` / `observeUserMapPins` filter `is_deleted = 0`, so every
  existing caller sees no change.
- New sync surface, mirroring the favorites trio:
  - `userMapPinSyncSnapshot() -> [UserMapPin]` — **includes** tombstones.
  - `applyUserMapPinSync(_:) -> [UserMapPin]` — per-id LWW on `modified_date`;
    equal-or-older incoming loses; identical incoming is skipped **without
    writing**, which is what keeps a peer's snapshot from re-firing the local
    observation and causing a push loop (same invariant `applyFavoriteSync`
    relies on).
  - `observeUserMapPinSyncState(onChange:onError:)` — tracks all rows including
    tombstones.
- Orphan tombstones (a delete for a pin we never had) are **not** inserted, so
  the table only grows with pins this device actually saw.
- No tombstone pruning: a user has a handful of pins, and any expiry window
  risks resurrecting a pin from a device that was offline longer than the window.

`UserMapPin.isDeleted` decodes with `decodeIfPresent` so a payload from an older
peer that predates the column still decodes rather than failing the whole array.

New `UserMapPinType` enum in PlayaDB gives both apps one definition of the pin
type strings (`userBike`, `userHome`, `userStar`, …) plus display name and SF
Symbol. The iOS `BRCMapPointType.pinTypeString` mapping already produces exactly
these raw values.

### 2. WatchConnectivity — one context, two payloads

`FavoritesSyncManager` → renamed **`PeerSyncManager`** (it no longer only does
favorites).

Critical constraint: `updateApplicationContext(_:)` **replaces the entire
dictionary**. Two managers each pushing their own key would silently clobber
each other, so pins must ride in the same manager and the same push:

```swift
["favoritesV1": <Data>, "userMapPinsV1": <Data>]
```

The manager holds two observations and two cached snapshots, and every push
emits whichever keys it currently has.

### 3. Watch UI

- **`PinsScreen`** — saved pins sorted by distance, reachable from Browse.
- **`PinDetailScreen`** — navigate (reuses the compass view), rename, delete.
- **Drop-pin sheet** from the map's bottom toolbar: Bike / Home / Star, saved at
  the current GPS fix. Disabled with an explanation when there's no fix.
- Pins render on the map as `MapMarker`s. `MapMarker` gains an optional
  `symbolName` so PlayaGeo can draw the SF Symbol inside the dot (via
  `Text(Image(systemName:))`, which `GraphicsContext.resolve` tints correctly —
  `context.draw(Image)` does not).
- `NavigationScreen` is generalized from `any DataObject` to a name +
  coordinate so pins can reuse it.

### 4. Map controls

`ToolbarItemPlacement.bottomBar` is available on watchOS 10+ (verified against
`WatchOS26.5.sdk` SwiftUI `.swiftinterface`), and `.buttonStyle(.glass)` /
`.glassProminent` on watchOS 26+. So the floating custom button is replaced by
real toolbar items that get system styling, system hit targets, and correct
inset from the display's rounded corners — the same treatment as the Browse and
Favorites buttons in the top bar.

Bottom bar: `[tracking, drop pin]`.

Tracking cycle also corrected to MapKit's order — **free → follow →
followHeading → free**. Previously `followHeading` fell back to `follow`, so
there was no way to return to free-look except by panning.

## Results

### Sim verification (Apple Watch Ultra 3 49mm + paired iPhone 17, watchOS/iOS 26)

Watch-local, all via UI automation:

- Drop sheet → Bike → row lands in `user_map_pins`
  (`…|Bike|40.7864|-119.2065|userBike|0`); the marker renders at the user's
  position (hidden under the user dot at 0 m, visible once the sim location moves).
- Browse → 📌 Pins lists it with distance; detail shows the green bicycle glyph.
- Navigate reuses the compass view and reads "413 m · 134°" after moving the sim
  location.
- Delete → confirmation → pops to the list, which shows the empty state. DB row
  survives as `is_deleted=1` with a bumped `modified_date`.
- With no GPS fix the drop sheet shows "Waiting for GPS…" (seen for real after a
  sim reboot cleared the simulated location).
- Fresh install applies `v1…v4-pin-sync` on the watch.

Cross-device, both apps running on a connected pair:

| Step | Result |
| --- | --- |
| Drop **Home** on watch | Phone `user_map_pins` gains it; annotation appears on the phone map geocoded to "9:59 & 2181' Inner Playa" |
| Drop **Bike** on phone (sidebar → name → Save) | Watch Pins lists it at 1.5 km |
| Delete **Home** on watch | Phone row becomes `is_deleted=1` and the annotation leaves the phone map |
| Watch's older **Bike** tombstone | Correctly **not** inserted on the phone — orphan tombstones are skipped by design |

### Tests

`swift test`: 222 passing (4 skipped), including 15 new `UserMapPinSyncTests`
covering insert, newer-wins, older-loses, tie-loses, self-snapshot no-op,
tombstone-deletes-local, orphan-tombstone-ignored, newer-local-beats-older-
tombstone, earliest-createdDate, idempotence, and decoding a payload with no
`is_deleted` key. `SchemaMigrationTests` updated for the v4 identifier.

### Two things worth recording

**A trailing-closure warning caught a real bug.** Adding `onPinsApplied` as a
second optional closure parameter silently re-bound the existing unlabeled
trailing closures at both call sites (`DependencyContainer`, `IBurnWatchApp`)
from favorites to pins — favorites-applied notifications would have stopped
firing. Both call sites now pass `onFavoritesApplied:` explicitly.

**The YapDatabase build failure in this worktree was stale Pods, not code.**
`Pods/YapDatabase/…/YapReachability.m` still carried
`#import <netinet6/in6.h>`, which the modules build rejects as a private header.
The Podfile has always pointed at `Submodules/YapDatabase` (whose copy lacks that
import); this worktree's `Pods/` was a stale CDN install of 4.0.1. `pod install`
resolved it (`Installing YapDatabase 4.0 (was 4.0.1)`). Verified pre-existing by
stashing all changes and rebuilding baseline. Podfile/Podfile.lock needed no
change; the cosmetic pbxproj churn CocoaPods emitted was reverted.

## Follow-ups not taken

- **Tombstone pruning.** Deliberately omitted: pin counts are tiny, and any
  expiry window risks resurrecting a pin from a device offline longer than it.
- **Pin markers aren't tappable on the map.** Canvas has no hit-testing here;
  pins are reached through Browse → Pins.
- **`userHome`'s orange matches the landmark marker color** (The Man / Center
  Camp). The SF Symbol distinguishes them, but a distinct palette would be better.

## Cross-References

- `Docs/2026-07-03-watchos-mvp-plan.md` — original watch plan; this closes one
  of its listed follow-ups.
- `Docs/2026-07-11-swiftui-lists-default-on.md` (Session 2) — favorites sync
  design this extends.
- `Docs/2025-08-21-user-map-pin-coordinate-fix.md` — phone-side pin history.
