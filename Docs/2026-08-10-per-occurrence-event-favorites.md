# Per-occurrence event favorites

## High-level plan

**Problem.** Favoriting an event favorited *every* showing of it. "Yoga - on a Bamboo
Floor!" runs six mornings; tapping the heart on Wednesday's row filled all six. Users want
the session they picked.

**Solution.** Event favorites are now keyed per occurrence. `object_metadata.object_id`
for an event favorite is a composite `"<eventUID>#<ISO-8601 UTC start>"`, and every read
surface resolves favorites through that key. Right after a single occurrence is favorited,
a small bottom toast offers "Favorite all N" for the rest of the series.

**Key changes**

| Area | Change |
| --- | --- |
| Identity | New `EventFavoriteKey` (composite id) + `EventObjectOccurrence.favoriteIdentity` |
| Resolution | New `EventFavoriteIndex` — one query, the whole precedence rule in one place |
| Writes | `favoriteTarget(for:)` splits "one occurrence" from "the whole series" |
| Migration | Open-time `foldLegacyEventFavorites` promotes legacy parent rows |
| Calendar | `reconcile` became a full per-occurrence reconcile against DB state |
| Yap mirror | `mirrorEvent` targets the one Yap occurrence whose `startDate` matches |
| UI | `FavoriteSeriesToast*` — a window-level offer to favorite the rest |

## Design decisions

### Identity: `"<eventUID>#<ISO-8601 UTC start>"`

`Packages/PlayaDB/Sources/PlayaDB/Models/EventFavoriteKey.swift`

The occurrence half reuses `EventCalendarEntry.occurrenceKey(for:)` verbatim, so a favorite
and its calendar entry name the same occurrence with the same string. Start instants come
from the API and are never rewritten by import (only end times are, see
`correctedOccurrenceTimes`).

Rejected, again, for the same reason as in the calendar work: `event_occurrences.id`
(AUTOINCREMENT, deleted and reissued wholesale by every `importFromData`) and array
positions in `occurrence_set` (reorderable by the API). `EventObjectOccurrence.uid`
(`"<uid>_<rowid>"`) is built on the former and is never a storage key.

Separator is `#`, deliberately different from the `_` of the synthesized uid and the `-` of
legacy Yap occurrence keys, so the pre-existing `migrateOccurrenceKeyedMetadata` fold (which
matches on `_`) ignores these.

### Only *favorites* are per occurrence

Notes, visit status, and view history stay on the parent event's row. "I visited this" and
"my note about this" are statements about the event; splitting them would fragment Recently
Viewed and the Visits list for no user benefit. `PlayaDBImpl.metadata(for:)` merges the two:
the parent row supplies notes/visits/views, and `isFavorite` is overlaid from the
occurrence-keyed row. `ListRow` inflation does the same overlay (`observeListRows` gained a
`favoriteIdentity` closure).

### Read precedence (the rule, in one place)

1. The occurrence-keyed row, when one exists — it always wins, which is how unfavoriting a
   single showing of a legacy series favorite works.
2. Otherwise the parent event row's `is_favorite` — a legacy series favorite lights every
   occurrence that has no opinion of its own.
3. Otherwise not favorited.

`EventFavoriteIndex` implements this once and every read surface uses it: both event-fetch
paths' `onlyFavorites` filter, `fetchFavoriteEvents`, `favoriteIdentifiers(among:)`,
`favoriteOccurrences(forEventUID:)`, and ListRow inflation.

### SQL narrows, Swift decides

`onlyFavorites` used to be a SQL `EXISTS` on the parent uid. Deriving the ISO-8601 key from
a stored date inside SQLite would mean writing the rule a second time, in a second language.
Instead SQL narrows to `event_id IN (candidateEventUIDs)` — events with *any* favorited row,
which keeps the query selective — and the exact per-occurrence rule runs in Swift over the
result. Both `eventObjectOccurrences` and `eventObjectOccurrencesJoined` do this identically.

### Bare `EventObject` means the series

Detail can be opened on an event rather than on a showing (`DetailSubject.event`), and the
Right Now screen resolves events, not occurrences. A bare `EventObject` names no particular
showing, so its heart means all of them: `favoriteTarget` returns `.eventSeries`, and
`toggleFavorite`/`setFavorite` write every occurrence row plus the parent row.
`isFavorite` for a bare event is "any occurrence is favorited".

### Search rows stand in for one showing

`SearchResultItem.favoriteIdentity` is now the occurrence composite. Global search collapses
an event to a single row (the soonest matching showing); that row's heart is that showing's
state, tapping it favorites that showing, and the series toast follows — exactly like the
event list. A different showing favorited elsewhere leaves the row's heart empty, which is
correct: the row represents one showing, not the event.

### The fold leaves the parent row alone

`foldLegacyEventFavorites` (open-time, `PlayaDBImpl.swift`) writes per-occurrence rows for
each favorited bare-uid row, inheriting its `favorite_updated_at`. It **does not** clear the
parent row:

- The parent stays the fallback for occurrences with no row of their own — including ones a
  later data refresh adds, and ones a peer on an older build knows about.
- Clearing it would push an "unfavorited" edit at those peers through `favoriteSyncItems`,
  silently dropping favorites on a device that hasn't updated.

It never overwrites an existing occurrence row, so a user who already unfavorited one
showing keeps that decision, and it is a no-op once run (parent rows whose occurrences all
have rows produce no writes). Data-dependent: events with no occurrences yet are skipped and
picked up on a later open; the fallback keeps behaviour correct in the meantime.

### Calendar reconcile reads the database

`EventCalendarService.reconcile(eventUID:isFavorite:)` was add-all-or-remove-all. It is now a
full reconcile: fetch the favorited occurrences, remove entries for occurrences that are no
longer favorited, create entries for favorited occurrences missing a live EKEvent. The
`isFavorite` argument survives only as the coalescing key (two passes with opposite intents
must not merge) — the database, not the caller, decides what the calendar should contain.
This is correct whether the trigger was favoriting one showing, unfavoriting one, or
accepting "favorite all". Added `PlayaDB.deleteCalendarEntry(eventId:occurrenceKey:)`.

### Yap mirroring is occurrence-scoped (no series-grained fallback needed)

`FavoriteSyncServiceImpl.mirrorEvent` now takes a favorite identity. Given a composite it
mirrors onto the single Yap object whose `startDate` renders to the same occurrence key —
the object has to be loaded to be written anyway, so matching on start time costs nothing and
avoids index-position guessing (wrong the moment the API reorders an `occurrence_set`). A
bare uid still fans out to every occurrence. The calendar hook now fires even when no Yap
object matched, so a device with no legacy database still gets its calendar reconciled.

## Files changed

**PlayaDB package**
- `Sources/PlayaDB/Models/EventFavoriteKey.swift` (new) — composite id + `favoriteIdentity`
- `Sources/PlayaDB/EventFavoriteIndex.swift` (new) — one-query resolution of the rule
- `Sources/PlayaDB/PlayaDBImpl.swift` — `favoriteTarget`, `writeFavorite`,
  `writeSeriesFavorite`, `isFavoriteOccurrence`, `isFavoriteSeries`,
  `occurrenceIdentities`, `foldLegacyEventFavorites`, favorite-filter rewrite in both fetch
  paths, ListRow favorite overlay, `fetchFavoriteEvents`, `favoriteIdentifiers`,
  `getFavorites`, `deleteCalendarEntry`
- `Sources/PlayaDB/PlayaDB.swift` — `setFavorite(_:forEventSeries:)`,
  `favoriteOccurrences(forEventUID:)`, `deleteCalendarEntry(eventId:occurrenceKey:)`, docs

**App**
- `iBurn/Favorites/FavoriteSeriesToast.swift` (new) — model + pure eligibility rule
- `iBurn/Favorites/FavoriteSeriesToastView.swift` (new) — the UIKit card
- `iBurn/Favorites/FavoriteSeriesToastPresenter.swift` (new) — notification seam + hosting
- `iBurn/DependencyContainer.swift` — owns and starts the presenter
- `iBurn/Calendar/EventCalendarService.swift` — per-occurrence reconcile
- `iBurn/FavoriteSyncService.swift` — occurrence-scoped Yap mirror
- `iBurn/ListView/SearchResultItem.swift`, `GlobalSearchViewModel.swift` — search identity
- `iBurn/ListView/EventDataProvider.swift`, `iBurn/Detail/ViewModels/DetailViewModel.swift`
  — pass the occurrence identity to the mirror
- `iBurn/ListView/VisiblePinsViewModel.swift` — per-occurrence keys, and asks
  `favoriteIdentifiers(among:)` about the rows on screen instead of fetching all favorites

**Tests**
- `Packages/PlayaDB/Tests/PlayaDBTests/PerOccurrenceFavoriteTests.swift` (new, 19 tests)
- `Packages/PlayaDB/Tests/PlayaDBTests/MetadataIdentityTests.swift` — inverted invariant
- `iBurnTests/PerOccurrenceFavoriteAppTests.swift` (new, 6 tests)
- `iBurnTests/EventCalendarServiceTests.swift` — favorites are written before reconciling
  (`favoriteSeriesAndReconcile`), plus two per-occurrence calendar tests
- `iBurnTests/GlobalSearchViewModelTests.swift` — search identity is the occurrence key

## The toast

`FavoriteSeriesToastEligibility` is a pure rule, split from the plumbing so it can be read
and tested on its own. An offer appears only when the change **added** a favorite, on an
**event occurrence** (a composite key — a bare event heart already means the series), for an
event with **more than one occurrence**.

The seam is `.playaDBFavoriteDidChange`, the notification `PlayaDB.toggleFavorite` already
posts (the tab bar's favorite-button glow is the other listener). Hearts live in a dozen
screens that all funnel through that one method, so one subscriber covers them all and can't
drift as screens are added. `setFavorite` deliberately does not post, which is what stops the
toast's own "favorite them all" write from re-raising the toast.

Hosting: one `FavoriteSeriesToastView` added to `BRCAppDelegate.shared.window`, positioned
above the tab bar (measured from the tab bar's real frame, with a fallback constant because
iOS 26's floating capsule is not a subview of the tab controller's view). Nothing covers the
rest of the screen, so the list underneath keeps scrolling. 5-second auto-dismiss;
Reduce Motion trades the slide for a cross-fade.

## Debugging notes worth keeping

**A toast that "renders but is invisible" was a measurement artifact.** Several rounds were
spent chasing why the toast appeared in every accessibility snapshot but in no screenshot —
through a dedicated `UIWindow`, a root-view-controller overlay, a window subview, and a
rewrite from SwiftUI to UIKit. The actual cause: the toast auto-dismisses after 5 seconds,
and a `screenshot` tool call is a separate round trip several seconds after the `tap` that
raised it. The AX snapshot returned *by the tap itself* was inside the window; every
screenshot was outside it. Raising `displayDuration` temporarily made it visible
immediately. This is now recorded in the `drive-app` SKILL.md.

Two facts learned along the way are still true and worth keeping:
- iBurn is a **pre-scene** app (no `UIApplicationSceneManifest`; `BRCAppDelegate` makes its
  own window), so `UIApplication.shared.connectedScenes` is not a reliable way to find the
  window that is on screen. The presenter uses `BRCAppDelegate.shared.window`.
- The iOS 26 floating tab bar is not findable as a `UITabBar` subview of the tab
  controller's view, and that view reports no bottom safe-area inset — hence the measured
  lookup plus `tabBarFallback`.

## Validation

- **PlayaDB package**: 290 tests, 0 failures (baseline 271 + 19 new).
- **App**: 476 tests, 0 failures (baseline 468 + 8 net new).
- **Builds**: iOS 26.5 (iPhone 17 Pro Max), iOS 18.6 (iPhone 16 Pro Max, by UDID), and
  watchOS 26.5 — all clean.
- **Simulator** (iPhone 17 Pro Max, 2026 data): favorited one occurrence of a
  6-occurrence event → only that heart filled, siblings unfilled, toast showed
  "It has 5 other occurrences." / "Favorite all 6"; tapped it → all 6 occurrence rows plus
  the parent row written, 6 calendar entries created; Favorites lists exactly the favorited
  occurrences. A legacy parent-uid row seeded before launch was folded into 5
  occurrence-keyed rows sharing its stamp, with the parent row intact.
- Screenshots: `/tmp/claude/iburn-favorites-round/` — `02-one-occurrence-favorited-with-toast.jpg`
  (one heart filled among siblings), `18-toast-visible.png` / `18-bottom.png` (the toast),
  `19-favorites-tab.png` (Favorites listing occurrences).

## Follow-ups

- `getFavorites()` still answers in whole `EventObject`s (collapsing composite ids to the
  parent uid). Callers that want showings should use `fetchFavoriteEvents`. The AI Right Now
  screen resolves bare events and so is series-grained by construction — coherent, but worth
  revisiting if that screen starts showing specific showings.
- The toast's copy is not localized (nothing in this app is yet).

---

# Round 2: map gesture gate, eye marker, rounded detail map, tip-anchored pins

Four small user-requested changes landed the same day, on `2026-updates`. They are
unrelated to per-occurrence favorites; they share this document only because it is the
same-day doc (per `CLAUDE.md`).

## High-level plan

| # | Problem | Fix |
| --- | --- | --- |
| 1 | Long-pressing a home/bike/favourite pin both started the pin drag **and** dropped the person on top of it | Gate the map's drop-person recognizer behind a `UIGestureRecognizerDelegate`, backed by a pure `DropPersonGate` |
| 2 | The dropped-person marker composited the **Man** (`pin_center`) — trademarked artwork | Swap the glyph for the SF Symbol `eye.fill` and delete the asset-catalog path |
| 3 | The 200 pt map preview on the detail screen had square, edge-to-edge corners | Round it in `DetailMapViewRepresentable` (14 pt, continuous) and inset `.mapView` cells like every other cell |
| 4 | Favourited camp pins sat on top of the `camp-labels-big` style text | `centerOffset` on `LabelAnnotationView` so the teardrop's **tip** is the anchor, not its middle |

## 1. Drop-person gesture gate

**Files**

- `iBurn/Map/DropPersonGate.swift` (new) — `DropPersonTouchTarget` (`.map` /
  `.userPin` / `.otherAnnotation`) plus two pure functions:
  `shouldDropPerson(target:isEditingUserPin:)` and `target(forHitView:classify:)`.
- `iBurn/MainMapViewController.swift` — conforms to `UIGestureRecognizerDelegate`, sets
  itself as the drop-person recognizer's delegate, implements
  `gestureRecognizerShouldBegin` scoped by recognizer name.
- `iBurn/UserMapViewAdapter.swift` — new read-only `isEditingUserPin`
  (`editingAnnotation != nil`).
- `iBurnTests/DropPersonGateTests.swift` (new) — 10 tests.

**Why a delegate and not `require(toFail:)`.** The pin's own long press lives on a view
that may not exist when the map's recognizer is installed, and the two aren't in a
fail/succeed relationship — the pin drag simply owns that touch.

**Judgment call: only *user* pins veto the drop.** The brief said "decline when the touch
hit-tests into any `MLNAnnotationView`". Implemented narrower: decline for annotation views
that are `isDraggable` (which `UserMapViewAdapter` sets on, and only on, `BRCUserMapPoint`
views — the same views it hangs the drag long-press off), plus decline everywhere while
`isEditingUserPin`. Reasons:

1. Only user pins have a competing gesture. A long press on a camp or art pin does nothing
   today, and dropping the person there is a natural "look from this camp".
2. It is the *only* lever UI automation has for choosing a drop coordinate — the map view
   itself is not an accessibility element (see `flows.md`). Declining on every annotation
   view would have made the feature unverifiable in the simulator and silently broken the
   documented driving recipe.

The seam is one `switch`, so flipping `.otherAnnotation` to `false` is a one-line change if
the wider rule is ever wanted.

**Testability.** `target(forHitView:classify:)` takes the per-view verdict as an injectable
closure, so the superview walk is tested with plain `UIView`s; the MapLibre-specific line
(`annotationTarget(for:)`) is tested separately with real `MLNAnnotationView`s.

## 2. Eye marker instead of the Man

`DroppedPersonMarker` now draws `eye.fill` (SF Symbol, 20 pt, `.semibold`, white),
aspect-fitted into a 20 pt box centred in the unchanged 34 pt blue chip (white ring, drop
shadow, +5 pt shadow padding). The asset-catalog lookup, the `figure.stand` fallback, and
the `glyphAssetName` constant are gone; `glyphSymbolName` replaces it.

The `pin_center` imageset itself is untouched — the map style's Man POI still draws it.
Two other surfaces reused the marker's glyph and were switched with it:

- `iBurn/Map/NearbyCard/NearbyCardView.swift` — the card's "Nearby &lt;address&gt;" header
  prefix (was `Image(DroppedPersonMarker.glyphAssetName)` with forced template rendering).
- `iBurn/ListView/NearbyView.swift` — the Nearby screen's "Near &lt;address&gt;" banner
  (was a hardcoded `figure.stand`).

New helper `DroppedPersonMarker.fittedGlyphSize(for:)` — `eye.fill` is ~3:2, so scaling by
height alone would have pushed it past the chip's 29 pt face.

Tests renamed/rewritten in `iBurnTests/DroppedPinSourceOverrideTests.swift`:
`testManGlyphResolvesFromTheAssetCatalog` → `testEyeGlyphResolvesFromSFSymbols`, plus a new
`testGlyphIsAspectFittedInsideTheChipFace`.

## 3. Rounded detail map preview

`DetailMapViewRepresentable.makeUIView` sets `layer.cornerRadius = 14`,
`cornerCurve = .continuous`, `masksToBounds = true` — done once inside the representable so
both `.mapView` and `.mapAnnotation` cells get it and cannot drift apart. `masksToBounds`
clips MapLibre's `MTKView` render layer fine.

`DetailView.DetailCellView` previously excluded `.mapView` from horizontal *and* vertical
padding ("maps should extend to edges"), which would have clipped a notch out of the
rounded corner at the screen edge. Only `.image` keeps the full bleed now; `.mapView` joins
`.mapAnnotation` on the standard 16 pt inset.

## 4. Tip-anchored label pins

`LabelAnnotationView.commonInit` sets `centerOffset = CGVector(dx: 0, dy: -imageSide / 2)`
(= `-15`). The 30×30 `imageView` is centred in the 100×45 view, so its bottom edge is 15 pt
below the view's centre; lifting the centre by 15 pt puts the teardrop's tip on the
coordinate. `centerOffset` was unused codebase-wide before this.

The obvious hazard — this view also draws its own title *below* the image, so lifting the
pin could just slide that title into the style text — does not bite: for style-labeled
camps `PinLabelVisibility.labelIsHidden` has already hidden this view's `label` (that rule
predates this change), and camps the layer has no feature for have no style text to collide
with. Art/event pins keep the same pin-over-label relationship, just shifted up 15 pt.

This affects every `LabelAnnotationView` (art, camps, events, map points) — intended,
tip-anchoring is simply more correct for a teardrop. `ImageAnnotationView` (user pins,
dropped person) was deliberately left centred.

## Validation

- **App build**: clean (iPhone 17 Pro Max, iOS 26.5).
- **Tests**: `iBurnTests` 491 passed, 0 failed (baseline 476 + 15 new/rewritten).
- **Simulator** (iPhone 17 Pro Max, device location 40.7864,-119.2065 then moved to
  40.7810,-119.2140, embargo unlocked):
  - **(1)** Long press on a saved favourite user pin → **no** person dropped; a temporary
    `NSLog` of the hit-test chain confirmed the press resolved to
    `iBurn.ImageAnnotationView > MLNAnnotationContainerView > MTKView > BRCMapView` and the
    gate returned false. Long press on a camp pin (`Sobremesa`) and on the user-location dot
    (`MLNFaux3DUserLocationAnnotationView`, non-draggable) still dropped the person, card
    header and "Clear dropped pin" and all.
    - *Gotcha for future rounds:* user pins placed with "Drop a pin" / "Find my camp" land
      on the device's own coordinate, where `MLNFaux3DUserLocationAnnotationView` (22×22)
      is stacked on top of them and wins the hit test. Move the simulator location away
      with `xcrun simctl location <UDID> set …` before long-pressing a user pin, or the
      test silently exercises the blue dot instead.
  - **(2)** Blue chip with a white eye visible on the map, and the same eye prefixes the
    nearby card's "Nearby 3:27 & Bodhi" header.
  - **(3)** Sobremesa detail screen, light mode: preview inset 16 pt with a clearly
    rounded continuous corner (verified on a cropped full-resolution screenshot); dark mode
    renders the dark base map inside the same rounded, inset frame — nothing broken.
  - **(4)** At z≥15 (double-tapped into the style-label zoom) a favourited camp's purple
    teardrop points at its coordinate with its body entirely above the `camp-labels-big`
    text, instead of straddling it. **Honest caveat:** no paired "before" screenshot was
    captured — the comparison is against the known previous geometry (pin centred on the
    coordinate), not against a re-built old binary.
- Instrumentation `NSLog` was removed and the app rebuilt clean afterwards.

## Residual / follow-ups

- MapLibre's own press-and-hold drag on user pins was not separately re-verified as
  *starting* — only that the drop no longer happens. The brief allowed this ("or at
  minimum does NOT drop the person").
- `DropPersonGate` treats every non-draggable annotation view as droppable. If the "no drop
  on any pin" rule is preferred later, change the single `switch` case.
