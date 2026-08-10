# iBurn critical flows — simulator driving scripts

Companion to the `drive-app` skill. Each flow lists preconditions, steps
(as XcodeBuildMCP UI-automation actions), and what to verify. Element labels
below are the accessibility labels/identifiers observed in snapshots — match on
label text, not on elementRef numbers (refs change every snapshot).

> **Maintenance:** if a step here doesn't match the running app, fix this file in
> the same session (see "Keeping the flow docs current" in SKILL.md).
> Last verified: 2026-08-09 against the 2026 dataset, iPhone 17 Pro Max sim.

## 1. First-launch onboarding (fresh install)

Preconditions: simulator erased; feature flag set if you want the SwiftUI stack
(set it BEFORE first launch so tab construction uses it).

1. `build_run_sim` — app launches to a springboard **notifications permission
   alert** → tap "Allow" (or "Don't Allow"; flows below assume Allow).
2. Onboarding page "Welcome to iBurn" → tap **"📍 Continue with Location"**.
3. PermissionScope sheet → tap **"CONTINUE WITH LOCATION"** → system location
   alert → tap **"Allow While Using App"**.
4. Page "Reminders" → tap **"⏰ Continue with Notifications"** → PermissionScope
   sheet → tap **"CONTINUE WITH EVENTS"** → system calendar alert → tap
   **"Allow Full Access"**.
5. Pages "Search" and "Nearby" are info-only — the action button does nothing;
   **swipe left** on the page scroll-view to advance.
6. Final page "Thank you!" → tap **"🔥 Ok let's burn!"**.
7. Main UI appears (Map tab) with the **embargo alert** "Locations Are Hidden" →
   tap **"Ok cool whatever"**.

Verify: tab bar shows Map / Nearby / Favorites / Events / More — that is the *default*
arrangement. Both the Map Search Layout (§8) and the user's own tab customization (§10)
change which tabs are on the bar, so match on tab labels rather than assuming a fixed
order or count.

## 2. SwiftUI + PlayaDB stack (default ON; legacy fallback)

The flag `featureFlag.lists.useSwiftUI` (all builds, default true) gates the
Favorites/Nearby/Events/Art/Camps SwiftUI screens, More → Visit List, and PlayaDB
creation/seeding. It is ON by default; disable it to exercise the legacy
UIKit/YapDatabase stack.

- CLI (preferred for automation): terminate app →
  `xcrun simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 featureFlag.lists.useSwiftUI -bool NO`
  → relaunch. (Use `-bool YES` or delete the key to restore the default.)
- In-app (DEBUG builds only): More tab → Feature Flags → toggle "Use SwiftUI Lists".

Verify: after navigating to any tab post-launch,
`<app container>/Documents/PlayaDB.sqlite` exists, `PRAGMA journal_mode` = wal,
and `grdb_migrations` contains every migration through `v6-pin-sync`. Seeded
counts (2026 data, Aug 9 refresh + placement): 332 art / 1191 camps / 2491 events /
5032 occurrences / 494 mutant vehicles / **1580 `thumbnail_colors`**;
`object_metadata` stays empty until the user favorites/views something. Camp GPS is
non-null for 1184 of the 1191, and every one of those 1184 coordinates is **distinct**
(they are footprint centroids, not street-intersection geocodes) — a `SELECT COUNT(*)
FROM (SELECT DISTINCT gps_latitude, gps_longitude …)` well below 1184 means the placement
pipeline regressed to geocoder coordinates.

`thumbnail_colors` being populated on a *fresh* install is the signal that the
pre-baked seed restored. `iBurn/PlayaDB-<year>.zip` is gitignored and built by
`Packages/PlayaSeed` (`swift run playa-seed --fetch-media`), so a clone that has
never run the tool has no seed: the app silently falls back to importing JSON on
device, first launch takes noticeably longer, and `thumbnail_colors` fills in
gradually via `ColorPrefetcher` instead of arriving complete. Both paths are
valid — just know which one you're looking at before calling a slow first launch
a regression.

## 3. Events browsing + day tabs

Preconditions: flow 2 done (SwiftUI stack on).

1. Tap the **Events** tab.
2. Day strip shows SUN 30 → MON 7 (festival week, end-inclusive so the final
   day/Exodus is browsable; scroll the strip to reach MON 7). Tap another day
   (e.g. "WED, 2").

Verify: rows swap instantly to that day's events (day slicing is in-memory —
no spinner, no reload flash). Row content: name, type emoji, host camp,
description, "Wed 2:00pm (2h)"-style time label.

**Max Duration filter (default 6h):** occurrences longer than 6h (all-day
"amenity listing" pseudo-events) are hidden by default. The toolbar Filter
sheet has a "Max Duration" slider (1h–12h, rightmost = "Any"; exactly-6h events
stay visible — inclusive). The HID tooling cannot drag SwiftUI sliders; for
automation, inject the preference directly (app terminated first) into the
**app container** plist — the user-level `defaults write <bundle-id>` domain is
NOT what the app reads:
```
C=$(xcrun simctl get_app_container <UDID> com.trailbehind.iBurn2010 data)
# "Any": {"unlimited":{}} ; N seconds: {"limited":{"_0":N}}
xcrun simctl spawn <UDID> defaults write \
  "$C/Library/Preferences/com.trailbehind.iBurn2010" \
  "eventListFilter.maxDuration" -data 7b22756e6c696d69746564223a7b7d7d
```
then relaunch; delete the key to restore the 6h default.

**Hour scrub strip automation:** the trailing-edge hour digits are text-only AX
elements (`tap` refuses them). Use `touch {elementRef: <digit>, down: true, up: true}`
to scrub to that hour. Quirks: the "8 PM"-style scrubber bubble can stick on screen
afterwards (synthetic touches skip the DragGesture `.onEnded` reset — cosmetic only),
and a far jump (e.g. 12am → 8pm) may land on a blank viewport until the next
swipe/touch materializes rows (LazyVStack far-target estimation; short jumps land
exactly).

## 4. Favorite an event (end-to-end)

Preconditions: flow 3; pick any event row.

1. Tap an event row → detail screen (title, HOSTED BY CAMP, NEXT EVENT,
   host's other events).
2. Tap the **"Add Favorite"** heart button (top bar; becomes "Remove Favorite").
3. Tap the back button ("Events") to return to the list.
4. Take a **screenshot** — the favorited row's heart is filled/red; others are
   outlined. (Hearts are not in the AX tree.)
5. Tap the **Favorites** tab — the event appears with all its occurrences,
   under All/Events filter tabs.

Verify in DB: exactly one new `object_metadata` row, `object_type='event'`,
`object_id` equal to the parent event uid in `event_objects` (never
`"<uid>_<n>"`), `is_favorite=1`.

Also verify the Yap mirror (`FavoriteSyncService`): in
`<app container>/Library/Application Support/iBurn/iBurn-2026/iBurn-2026.sqlite`,
every per-occurrence row (`database2` table, collection `BRCEventObject`, keys
`"<apiUID>-<n>"`) gets an updated metadata blob containing `isFavorite=true` and
(with calendar permission granted) an EKEvent `calendarEventIdentifier`. The
favorited blobs are larger than the ~440-byte import-stamped baseline.

## 5. Search (FTS)

The events/favorites lists have searchable fields ("Search events",
"Search favorites"), but SwiftUI searchable fields drop out of the AX snapshot
unpredictably. Two options:

- **UI path (when the field is visible):** `type_text` into the field; results
  filter live. Porter stemming applies ("taco" matches "Tacos", "taCO").
- **DB path (always works, use for FTS correctness):**
  ```sql
  SELECT COUNT(*) FROM event_objects_fts WHERE event_objects_fts MATCH 'taco';
  INSERT INTO event_objects_fts(event_objects_fts) VALUES('integrity-check');
  ```
  2026 data: 'taco' → 12 event matches; 'oasis' → 72 camp matches.

### Global search screen (search tab / map search)

The global search screen (`GlobalSearchView`, reached from the Search tab in the
`.searchTab` layout, or the map's search field otherwise) has its own scope + filter
chrome above the results:

- **Scope bar**: a segmented control `All / Art / Camps / Events / Vehicles`, **pinned to
  the top of the content area in every state** (prompt, loading, no-results, results); the
  result list scrolls *underneath* it. Scoping changes which tables are queried at all, so
  a scoped search returns only that section (e.g. Camps + "yoga" -> a single "Camps"
  section, alphabetical). Changing scope re-runs the query without retyping. In the
  map-overlay layout the bar sits at the *bottom*, next to the docked field, instead.
  - On **iOS 26** the bar is a floating **Liquid Glass capsule** (`glassEffect`) inset
    from the screen edges, hung off `safeAreaBar` so the system's scroll edge effect
    softens the rows passing underneath. Pre-26 it is a `safeAreaInset` over an opaque
    `.bar` strip (there is no glass to keep it legible otherwise).
- **Filter button**, `line.3.horizontal.decrease.circle`, filled (`.fill`) whenever a
  filter is on — that fill is the *only* on-screen cue, and the filter persists in
  `UserDefaults` (`globalSearchFilter`) across relaunches while the scope resets to All.
  **Where it lives depends on the layout — there is exactly one per layout:**

  | Map search layout | Host | Filter affordance |
  | --- | --- | --- |
  | `.searchTab` | `NavigationController` + `UISearchTab` | **Navigation bar**, right item, next to the "Search" title |
  | `.navigationBar` | `UISearchController.searchResultsController` | Inline, trailing end of the scope bar |
  | `.bottomAccessory` | Map overlay child | Inline, trailing end of the scope bar |

- The search tab shows a real **navigation bar** ("Search" + filter item). It only does so
  because `hidesNavigationBarDuringPresentation` is off: `UISearchTab.automaticallyActivatesSearch`
  arrives with search already active, and an active search controller otherwise hides the
  nav bar (which is what left an empty band at the top of the screen).
- Sheet contents: **Only Favorites** (all scopes; also disables AI suggestions) and, under
  an "Events" section shown **only for the All and Events scopes**, three event knobs:
  **Happening Now**, **Day** ("Any day" + each festival day from `YearSettings`), and
  **Time of Day** (Any / Morning 6a-12p / Afternoon 12p-5p / Evening 5p-10p / Late night
  10p-6a, which wraps midnight). Day narrows at the SQL level (`EventFilter`
  `startDate`/`endDate`); the time band is applied to occurrences *before* the
  one-row-per-event collapse, so an event that also runs at 11pm survives a "Late night"
  filter and shows its 11pm occurrence. Day and Time are **disabled while Happening Now is
  on** (it already pins the window to now). A **Reset** button appears in the sheet when
  the filter is non-default; the sheet footer spells out the selected band's hours.
- **Favoriting works from search.** Every result row's heart is live: tapping it flips the
  row immediately and writes through `PlayaDB.toggleFavorite` (mirrored into legacy Yap
  like the list screens). Event favorites are keyed by the **parent event uid**, so every
  occurrence of that event shows filled, and favorites set on other screens show up the
  next time the search re-runs. Verify in the DB with
  `SELECT object_type, object_id, is_favorite FROM object_metadata WHERE is_favorite = 1`
  - an event row's `object_id` must match an `event_objects.uid`, never `"<uid>_<n>"`.
- Empty states name the scope: "No camps for "Yoga"" / "Nothing matches that with these
  filters on." / "Try clearing the filters"; with no filter on it is "Nothing in this
  year's data matches that."
- Matching is **AND-of-tokens** FTS, so "questions burning" matches a name containing both
  words in either order.

- **Results index rail** (right edge, `SearchResultIndexView`). Appears once the results
  run to ~12+ rows and offer more than one destination. It is the Yap-era global-search
  `sectionIndexTitles` ported forward: a **type icon** at the head of each section
  (`BRCArtIcon` / `BRCCampIcon` / `BRCEventIcon`, `car.fill` for vehicles), then
  **uppercased first letters** for art/camps/vehicles (`#` for anything non-alphabetic)
  and **day-initial + clock hour** stops for events ("M6" = Monday 6 o'clock, the format
  `GroupTransformers.searchGroup` produced). Drag it to scrub: a haptic tick per stop and a
  floating bubble naming where you are - "Camps - B", "Events - Mon 9a". When the stops
  outnumber the rail's height, type markers are kept whole and the letters between them are
  sampled with bullets in the gaps (what `UITableView` does to a crowded index). Rows
  reserve trailing room for the rail so their text never runs under it.
  - Art/camps/vehicles results are sorted with `localizedStandardCompare` client-side
    (SQLite's binary `ORDER BY name` would put "aardvark" after "Zoo" and break the A->Z
    run the rail depends on).

Automation notes:
- `type_text` into the field works here (the field is a stable AX target, unlike the
  `searchable` fields in §5's list screens). The simulator autocapitalizes the first letter
  ("Yoga") - harmless, FTS is case-insensitive.
- **Favorite hearts ARE in the accessibility tree** in every `ObjectRowView` list, labelled
  "Favorite <name>" / "Unfavorite <name>" - tap them by `elementRef` and read the label back
  to assert state (this supersedes the older "screenshot the heart" advice in SKILL.md).
- The index rail is one accessibility element labelled **"Search result index"**; resolve it
  with `wait_for_ui` and scrub it with `drag`.

## 6. Map + embargo

- Map tab renders the MapLibre offline map immediately after onboarding.
- Locations are hidden until the embargo lifts (the "Locations Are Hidden"
  alert on first run explains this). The embargo is **two-tier** per the BMorg
  API ToS: camps (and camp-hosted events) unlock at 12:01 am the Sunday before
  gates (`YearSettings.campLocationUnlock`), art (and art-located events) at
  gates-open (`eventStart`). Location-dependent pins won't appear in pre-event
  builds — this is expected, not a bug.
- The camp boundary/label style layers (`camp-boundaries`, `camp-labels-big`,
  geojson shipped inside `Map.bundle`) are gated on the camp tier via
  `MapLayerManager`/`CampLayerVisibility`: hidden while locked even when the
  "Show Camp Boundaries (Always)" map filter is on, and they appear live on
  unlock with the rest.
- **A camp's name is drawn once, the style layer draws it, and where it draws there is no
  pin at all.** A camp's GPS is the centroid of its own footprint — the same point
  `camp_labels.geojson` puts its label at — so a pin and a style label would otherwise stack
  on the same pixel. The split is per camp, not per zoom: `camp-labels-big` runs its full,
  **uncapped** zoom range (z15 up), and any camp that file has a feature for is drawn as
  **text only, with no pin**. `CampStyleLabelIndex` reads the uids out of the bundled geojson
  (lazily, off-main, once per launch); `CampPinVisibility.pinIsHidden` decides whether the
  pin is drawn and `PinLabelVisibility.labelIsHidden` whether a surviving pin writes its own
  name. Both are pure and unit-tested in `EmbargoTierTests`.
- **The style labels are the tap target.** Tapping one pushes that camp's detail screen
  directly — no callout. `MapViewAdapter` installs a `UITapGestureRecognizer` that
  `require(toFail:)`s every built-in map tap recognizer, so it only fires on taps MapLibre
  itself declined (`-gestureRecognizerShouldBegin:` refuses the map's single tap when nothing
  was hit and nothing is selected). It queries a 44×44pt box against `camp-labels-big`, takes
  the feature's `uid`, and routes through the host's `onPlayaInfoTapped`. It re-checks
  `campNamesDrawnByStyleLayer` first, so a tap on a stale tile can never open an embargoed
  camp.
- **Which camps still get a pin**, and how to exercise each in the sim:
  - **camps the geojson doesn't name** — exactly **1 of 1191 in 2026** (`Westlandia`, the
    only camp with GPS and no feature; the other 7 unlabelled camps have no GPS, so they
    produce no pin either way). It keeps a pin *and* its own `UILabel`;
  - **favourites** — a starred camp keeps its pin over its style label, because the text
    can't say "you starred this" and `showFavoritesOnMap` toggles independently of
    `showCampsOnMap`. Favourite any placed camp and watch its pin appear on the browse map;
  - **the layer not painting** — Map Filter → **"Show Camp Names (Zoomed)" off** → Done, or
    any zoom below z15, or the camp tier still embargoed. Every camp pin comes back, each
    labelling itself. Turning the filter back on removes them again on Done.
- **Static/explicit maps are never filtered.** "Show on Map" from a detail screen, and every
  list's map button, build a `StaticAnnotationDataSource` behind a plain `MapViewAdapter` —
  the pin the user asked for is always there. Suppression lives in `UserMapViewAdapter`
  (`shouldDisplay`), which only the main Map tab uses.
- **What to check:** at any zoom/filter combination each camp name appears exactly once, and
  no name is drawn on top of itself. A purple pin over style text now means one of the two
  escapes above (favourite, or unlabelled camp) — a pin on an ordinary camp at z≥15 with
  names on is a regression. The a11y snapshot is the cheapest assertion: at z17 over placed
  camps it should list only the escapes as buttons, not every camp in view.
- With "Camps (Zoomed)" **off** no camp pins appear and the style labels are untouched — they
  are never capped, so no `reloadStyle` is needed and turning the filter off at a standing
  camera shows clean labels immediately. (Before Aug 9 the layer *was* capped at the camp-pin
  zoom, which needed a `mapView.reloadStyle` to undo because MapLibre will not re-parse tiles
  it built while a layer was out of range. Both are gone.)
- The Map Filter's Done callback re-runs all four: `updateAllLayers()`,
  `refreshRegionAnnotations()`, `reloadAnnotations()`, `updatePinLabelVisibility()`. Camp pins
  appear/disappear immediately on Done — no pan required.
- Crossing the layer's **z15 minzoom** also changes which camps need a pin, and the
  observation path is zoom-blind, so `UserMapViewAdapter` rebuilds the pin set from
  `regionDidChangeAnimated` — but only when the `campNamesDrawnByStyleLayer` verdict actually
  flips, so an ordinary pan stays cheap.
- **There are two independent annotation sources on the map, and both are gated.**
  `PlayaDBAnnotationDataSource` runs GRDB observations for the "always show" settings;
  `UserMapViewAdapter.refreshRegionAnnotations()` separately queries
  `fetchObjects(in:)` for the visible bounds on every region change and adds art at
  **z ≥ 16** / camps at **z ≥ 17** / happening-now events. That region path is the one
  that actually draws camp pins in a default install (see the filter mapping below), so
  when you check the locked state you must **zoom in to z ≈ 17–18 over a placed part of
  the city** — a wide-zoom snapshot proves nothing. Its tier filtering lives in the pure
  `MapRegionAnnotationFilter` (unit-tested in `EmbargoTierTests`), and it re-runs on
  `BRCEmbargoDidClear` so an unlock repopulates the viewport without panning.
- **Automation note: XcodeBuildMCP cannot zoom or pan-to-coordinate the main map.** There is
  no pinch preset and no coordinate tap (`tap`/`touch` need an elementRef), the map view
  exposes no adjustable action, and nothing in the app moves the *main* map camera past its
  z13 launch position. Drive the camera from lldb instead — attach to the running app,
  select the main thread, walk the window hierarchy for an `MLNMapView`, and
  `objc_msgSend` `setCenterCoordinate:zoomLevel:animated:` with a plain 2-double struct
  (`CLLocationCoordinate2D` and `CGRect` are not in lldb's type context). The same trick
  runs `visibleFeaturesInRect:inStyleLayersWithIdentifiers:` to assert what a tap at a given
  point would resolve to. `snapshot_ui` is then the assertion: map annotations appear as
  buttons labelled with the object's name.
- **Map Filter camp toggles map to two different defaults**, which is why the region path
  matters: "Camps (Always)" is `kBRCShowCampsOnMapKey`, **default false** (so the
  observation path adds no camps at all out of the box), while "Camps (Zoomed)" is
  `showCampsOnlyZoomedIn`, **default true**. Art is the mirror image:
  `showArtOnlyZoomedIn` defaults true.
- To exercise location flows before placement drops, apply mock fixtures:
  `node scripts/mock_locations.js apply --map-fixtures` in
  `Submodules/iBurn-Data` (revert with `... revert`). Rebuild + relaunch: the
  bumped update.json triggers a JSON re-import with last year's placements.
  While applied, `MockDataShipGuardTests` fails and `playa-seed` refuses — by
  design; revert before committing or building seeds.
- Unlocking (More → "Unlock Location Data" passcode, or entering the BRC region)
  posts `BRCEmbargoDidClear`: the map's PlayaDB observations restart and the six
  SwiftUI list hosting controllers rebuild their root view, so pins/playa
  addresses appear immediately — **no relaunch needed**. If you have to restart
  the app to see locations after unlocking, that's a regression.
- "List" button (top-left) opens "Visible Pins" — a SwiftUI/PlayaDB list of what
  is currently drawn inside the map's visible bounds, sectioned Art / Camps /
  Events / Map Pins, nearest-first when a location is available. Tapping a data
  row pushes the PlayaDB detail screen; tapping a Map Pins row pops back to the
  map, recenters on that pin and opens its callout. Legacy Yap-fed maps (the
  `useSwiftUILists` kill-switch list screens) still get the old
  `MapPinListViewController` — the split is in `ListButtonHelper`, keyed on
  whether any visible annotation is a `DataObjectAnnotation`.
- Search field "Search" is in the map header.

### Drop the person (long-press "look from here")

**Long-press anywhere on the main map** stands a little person marker there (Street View
pegman idea) and re-points the nearby card at that spot: its ~100 m of art/camps/events, and
every distance, are then measured from the marker instead of the device.

- The marker is a **blue circular chip with a white `figure.stand` glyph**, drawn at runtime
  from an SF Symbol (`DroppedPersonMarker`) — there is no person asset in the bundle. It is
  an ephemeral `DroppedPersonAnnotation`, **never** a `BRCUserMapPoint`: nothing about it is
  written to PlayaDB or `UserSettings`, and it is gone after a relaunch.
- The gesture is a `UILongPressGestureRecognizer` installed by **`MainMapViewController`**
  (named `iBurn.dropPersonLongPress`, 0.45 s), not by `MapViewAdapter` — detail maps and
  "show on map" list maps are deliberately unaffected, because only the main map has the card.
- The card grows a **header line** — "Nearby &lt;playa address&gt;" — from
  `PlayaGeocoder.asyncReverseLookup`, falling back to "Nearby dropped pin" until (or unless)
  the geocoder answers. The header costs the card `18 + 6 = 24 pt` at default Dynamic Type,
  so it stands **124 pt** tall while a pin is down and 100 pt otherwise.
- **Long-press elsewhere moves it** — there is only ever one person on the map; the old
  annotation and its callout go away.
- **Tap the person** → callout titled with its playa address, with an ⊗ **"Remove dropped
  pin"** accessory. That, and the card's **"Hide"**, both take the marker off and put the card
  back on the device's own location.
- **"See all"** pushes the Nearby screen carrying the marker's location
  (`createNearbyViewController(locationOverride:)` → `makeNearbyViewModel(locationOverride:)`).
  That screen shows a banner **"Near &lt;address&gt;"** with a **"Use My Location"** button;
  the button clears the override *for that screen only* — the map keeps its person until you
  remove it there. The legacy UIKit `NearbyViewController` (`useSwiftUILists` off) ignores the
  override entirely; that's a documented caveat, not a bug.
- While a person is down the GPS stream keeps updating in the background but **cannot** move
  the card or re-center its query. Removing the pin snaps to the *current* fix, not the one
  from when the pin was dropped.
- Precedence on the Nearby screen is **dropped pin > Warp location > device**, and the two
  explicit choices retire each other: applying a Warp *location* drops the pin override, and
  dropping a pin outranks a warp location. A time-only Warp leaves the pin standing — the
  person changes *where*, never *when*.

**Driving it from automation.** `long_press` needs an elementRef and the map view itself
isn't one, but the recognizer is on `MLNMapView`, so a long press on **any annotation button
inside the map** (`You Are Here`, a camp/art pin) delivers the touch to it and drops the
person at that annotation's screen point. That is the only way to choose a drop coordinate
without lldb. Assertions are cheap in the AX snapshot: the card header appears as text
("Nearby 9:23 & Great Oak"), the marker as a button labelled with its address, and its
callout exposes "Remove dropped pin". At 40.7864,-119.2065 with the embargo unlocked,
long-pressing the `Snuggles` pin gives a visibly different card (camps at G & 9:15) and
Nearby list (Moth 8 m, Snuggles 2 m) than the device-sourced one (Aeshtah / Spectral Scarab /
Solar Library, all 3 m) — that contrast is the quickest proof the re-sourcing works.

### Nearby card (on-map)

A compact swipeable card pinned near the **top** of the map lists what is within ~100 m of
the user (events first, then art + camps by distance; `simctl location set` required or it
stays empty). Its footer is **"Hide" (leading) | page dots (centered) | "See all" (trailing)**,
"See all" linking into the Nearby screen.

- Card geometry at default Dynamic Type: **72 pt page + 28 pt footer = 100 pt** tall (plus a
  24 pt header while a person is dropped — see the flow above), width
  `min(380, screen − 32)`. The page is `contentInset (10) + row (60) + rowFooterGap (2)`,
  where the row is `max(thumbnail 60, text stack)` and the **worst-case text stack is 56**
  — name (20) + accessory (16) + description (16) with the VStack's two 2 pt gaps. The
  60 pt thumbnail is therefore what sets the height, and the old ~14 pt of dead space above
  the footer is gone. Rows are **top-aligned** — the name's top edge sits level with the
  60×60 thumbnail's top on every page, so swiping between a 2-line and a 3-line row must not
  move the title vertically.
- **All four card edges use the same 10 pt inset**: the thumbnail's leading/top, the
  favorite button's top/trailing, and — via the footer's `contentInset − 6` horizontal
  padding plus each button's own 6 pt label inset — the "Hide" and "See all" labels. If the
  heart looks like it hugs the corner tighter than the row does, that's a regression. The
  row's text stops at `10 + 24 + 4 = 38` pt from the trailing edge so a long name truncates
  before the heart rather than sliding under it.
- The height **follows Dynamic Type** (a `@ScaledMetric` on the text stack, relative to
  `.subheadline`) up to `extra-extra-extra-large` and stops there. So all three lines clear
  the footer at XXXL — the card is simply taller — and at `accessibility-medium` and above
  the stack overflows the frozen height and the last line **truncates** rather than colliding
  with the footer band. Accessibility sizes are still the known limit, but they now degrade by
  truncation, not overlap.
- Each page shows name (1 line), an **accessory line** (1 line, secondary), then the
  description. The accessory is `NearbyItem.accessoryLine(now:)`: an event's live timing, the
  playa address, or `"<time> · <address>"` when both apply. It is **absent entirely** when
  there is nothing to show — a locked camp or art piece — and the description then gets **2
  lines** instead of 1. The address half comes from `NearbyItem.address`, which applies the
  two-tier check per item (art tier / camp tier / host's tier for events), so pre-embargo a
  camp/art page is name + description only, exactly as before; an event keeps its timing.
  If an art piece shows "Open Playa" while locked, that's a regression. **Check
  `kBRCEntered2026EmbargoPasscodeKey` in the app's prefs plist before calling it one** (read
  it with the recipe in §8) — a passcode entered in an earlier session persists and
  legitimately unlocks everything.
- **Favorite button** (heart, **top-right corner of the card**, AX label
  "Favorite <name>" / "Unfavorite <name>"). It overlays the card *outside* the pager, so it
  keeps a fixed position and doesn't eat the swipe; it retargets to whichever page is
  showing as you swipe. The audio-tour button (art with a local file) stays in the row,
  pinned to the **bottom** of the page (just above the footer) so it clears the heart.
- **"Hide"** (footer leading, AX label "Hide nearby card") writes
  `userInterface.nearbyCard.enabled = false`. The card fades out and a glass tooltip —
  "Nearby card hidden — turn it back on in Map Filter." — fades in **in the card's place**
  for ~4 s, then auto-dismisses (tapping it dismisses early). There is no collapsed
  FAB/pin state any more; the card is either on screen or gone.
- The tooltip's 4 s life is **shorter than a screenshot round-trip**: `tap` → `screenshot`
  usually lands after it is gone. Record video instead
  (`xcrun simctl io <UDID> recordVideo --codec h264 --force out.mov`, `kill -INT`, then
  `ffmpeg -ss <t> -i out.mov -frames:v 1`) or assert on the AX snapshot returned by the tap
  itself, which does contain the tooltip's text.
- **Map Filter** (funnel button, map header) has a **"Nearby Card"** section: "Show Nearby
  Card" plus Art / Camps / Events sub-toggles (dimmed and non-actionable while the card is
  off). Preferences are `userInterface.nearbyCard.{enabled,showArt,showCamps,showEvents}`,
  written on **Done**; the card observes them and updates **live** without leaving the map.
  Turning off every type that has something nearby empties the card exactly like disabling
  it does.
- 2026 data at 40.7864,-119.2065: three **art** pieces within 100 m (The Hitchin' Post 18 m,
  Thoughts by the Edge 89 m, Unhinged Lingering 100 m) and **no** camps — so "Camps only"
  is the quickest way to prove the type filter empties the card.

**Exercising the card outside the festival window.** Events only enter the card when an
occurrence `isInNearbyWindow` (starts within 30 min / hasn't ended), so pre-event there is
nothing but art + camps. Set `BRCMockDateEnabled`/`BRCMockDateValue` (app-container prefs
via the §8 `defaults write` recipe, app terminated; default mock is 2026-09-04T11:00-0700)
to get live events — but note the mock date also lifts the embargo by date, and running
with a BRC location under a festival date makes `enteredBurningManRegion` write
`kBRCEntered2026EmbargoPasscodeKey = YES` permanently. Delete that key (again, §8 recipe —
**not** PlistBuddy) when you next want the locked state.
Event-dense mock-time spots: **40.77546,-119.20512** (9 live events + 4 camps at 11:00) and
**40.77245,-119.19365** (1 long-named event + 4 camps).

**The card may not open on an event even when events are nearby.** Art/camp observations
resolve before the event one, so the selection settles on the first camp and
`reconcileSelection` deliberately keeps it there when the events arrive and are prepended.
The dots show the real position (e.g. 5th of 12). Page **back** to reach the events: `drag`
the card's title text ref to the **right**, one page per drag — the pager's own scroll ref is
usually missing from the AX tree.

**Data limits worth knowing before you go hunting for a worst case.** In the 2026 dataset no
address is longer than 25 characters and every gps-bearing event resolves a host address, so
the accessory line fits on one line for essentially all real data at default Dynamic Type.
To see it wrap/truncate, raise Dynamic Type
(`xcrun simctl ui <UDID> content_size …`) — see the Dynamic Type note above for
where it stops growing. The 2026 build also
ships **no audio-tour `.m4a` files at all**, so the row's play button never appears from real
data; drop a file at `<container>/Documents/MediaFiles/<art uid>.m4a` to exercise it
(`afconvert -f m4af -d aac /System/Library/Sounds/Ping.aiff tour.m4a` makes a fixture; the
art uids at 40.7864,-119.2065 are in `art_objects`). Delete it again when you're done.

**Zooming the map from automation.** There is no programmatic camera control on the main map
(it opens at z13 on the Man every launch) and no pinch primitive in the tooling. What works is
a synthetic **double-tap**: `batch({ axCache: "perBatch", steps: [{action:"tap",elementRef:X},
{action:"tap",elementRef:X}] })` is fast enough to register as one, and each batch zooms in.
Use the **"You Are Here"** annotation as X after `simctl location set` + one tap on
**"Tracking Mode"** (follow), so every zoom step stays centred on the coordinate you chose.
From the default z13, four batches lands around z17–18 — art pins show up on the third,
camps on the fourth. Two ways to read the annotations back: MapLibre publishes each one as an
AX button whose **label is the name and value is the playa address**
(`e20|tap|button|Moth|9:00 4815', Plaza|`), and the header **"List"** button opens Visible
Pins, which says "No pins visible" when the map is genuinely empty. The snapshot's
`screenHash` is a handy check that a locked and an unlocked run were compared at the *same*
camera.

**Automation hazard: MapLibre + accessibility.** `snapshot_ui` (and the AX refresh every
`tap`/`batch` does) walks MapLibre's annotation container, which can throw
`std::out_of_range` and abort the app — the stack is
`automationElements → MapLibre → __cxa_throw`, and it fires most often right after
dismissing the Map Filter sheet. It is an automation-only crash, not a user-visible one. Use
`touch {down,up}` instead of `tap` for the sheet's **Done** button, and expect the pager's
scroll ref (the one `drag` needs to page the card) to drop out of the AX tree periodically —
relaunching the app brings it back.

### Nearby screen (list) — event filter, window, ordering

The full-screen Nearby list (tab, or the card's "See all") shares its event filter with the
card above — one `NearbyEventFilterStore`, persisted under `nearbyEventFilter` /
`nearbyEventFilter.maxDuration`.

- Nav bar is **Warp (leading) | filter | map (trailing)**. The filter button (AX label
  "Filter Nearby Events") opens the same `EventFilterSheet` the Events tab uses, minus the
  "Show Expired Events" toggle — Nearby's time gate is its own now-window, so that control
  would do nothing. Icon is `line.3.horizontal.decrease.circle`, **`.fill`** when anything
  differs from the defaults, matching the sheet's Reset button.
- **Max Duration defaults to 6h**, same as the Events tab, applied in SQL. Without it the
  list is dominated by 10–12 h "amenity listing" pseudo-events (open bars, stamp stations).
  Changing it re-queries **both** surfaces live — no relaunch, no leaving the map.
- Events are ordered **starting-soon first (soonest first), then already-started
  (most-recently-started first)**, not by ascending start time — a 12 h listing that began
  at 09:00 must not outrank a set that starts in ten minutes.
- Row timing labels use the **effective (warped) date**, not wall-clock now. Under Warp a
  row reads "12:00pm (4h left)"; if it reads like a plain future date ("Wed 12:00pm (4h)")
  while warped, the display date has been decoupled from the filter date again.
- Quickest end-to-end check with the 2026 data: mock date `2026-09-02T19:00Z` and
  `simctl location set 40.79169,-119.21120` puts 9 in-window events within the card's 100 m
  (7 of them >6 h), so the card's page dots read **9 at "Any" and 2 at the 6h default** —
  a one-glance proof that the cap reaches the card too.

**A file edit to the prefs plist *does* stick if you restart the simulator's cfprefsd**
(`xcrun simctl spawn <UDID> launchctl kickstart -k system/com.apple.cfprefsd.xpc.daemon`
after the edit, before launching). Worth knowing for the few values `defaults` can't write
comfortably — `nearbyEventFilter.maxDuration` is a JSON **data** blob
(`{"limited":{"_0":21600}}` / `{"unlimited":{}}`), easiest to write with python3 `plistlib`.

## 7. Detail screen

From any list row (event/camp/art):
- Title + description, host section (tap navigates to host detail),
  "NEXT EVENT" section, "See all N events from <host>".
- Top bar: Share, favorite heart, back.
- Viewing a detail writes `last_viewed`/`first_viewed` metadata (this must NOT
  cause list observations to re-emit — the metadata region excludes those
  columns; regression-tested in FilterObservationTests).

### More → Visit List (PlayaDB, default)

More tab → **Visit List** pushes the SwiftUI `VisitListHostingController`
(`useSwiftUILists` ON; OFF falls back to the Yap-fed `VisitListViewController`).

- Segmented picker **All / Want to Visit / Visited** over sections
  "⭐ Want to Visit" and "✅ Visited" (there is never an "unvisited" section);
  rows are mixed art/camp/event with hearts + distance, `map` toolbar button.
- Populate it from a detail screen's VISIT STATUS cell, then back out to More →
  Visit List. There is **no observation API for visit status**: the list re-fetches
  on every appearance and on `didBecomeActive` (so a watch-applied status shows up
  after backgrounding/foregrounding, not live while on screen).
- Verify in DB: `SELECT object_type, object_id, visit_status FROM object_metadata
  WHERE visit_status != 0;` — art/camp rows keyed by uid, events by the **parent**
  event uid.

## 8. Feature Flags screen

More tab → scroll to the bottom → **"Debug"** (DEBUG only). Contains the date
override, "Use SwiftUI Lists", and the **Map Search Layout** picker.

Navigating here is awkward: `MoreViewController`'s table cells are **not exposed
as tap targets** in the AX snapshot — "Debug" shows up only as a `text` row. Use
`touch` (which accepts a text elementRef) rather than `tap`:

```
touch({ elementRef: "<ref of the 'Debug' text row>", down: true, up: true })
```

"Use SwiftUI Lists" takes effect on next relaunch for tab construction. The Map
Search Layout picker (`navigationBar` / `bottomAccessory` / `searchTab`) applies
**live** via `.mapSearchLayoutDidChange` — no relaunch. Both bottom layouts are iOS
26-only; below 26 every choice resolves to `navigationBar` (`MapSearchLayout.resolved`),
so an 18.x sim always shows the search field under the nav bar title and all five tabs.

**Bar appearance is version-split too, and it's the map screen's alone.** The map asks for
clear nav/tab bars (`Appearance.applyTransparent*Appearance`, applied in
`MainMapViewController.viewWillAppear` and undone on disappear) so iOS 26 can paint Liquid
Glass behind the floating controls. Below 26 there is no glass behind a clear bar, so those
two calls fall back to the standard translucent `systemChromeMaterial` bars the rest of the
app uses. **What to check on an 18.x sim:** the Map tab's nav bar and tab bar have the same
material background as Nearby/Favorites/Events/More. Tab items or the search field sitting
directly on the map with no bar background at all is the pre-26 regression this guards
against; on 26 the same screens keep transparent bars with glass button capsules, which is
correct there.

`searchTab` adds a Search tab and **defaults Favorites off the bar**, so the tabs
become Map / Nearby / Events / More plus a detached search button. Favorites keeps two
entry points instead of a tab: a **floating button** stacked above the search circle
(§8a — it opens Favorites by default, and the user can repoint it) and a row at the top of
More. The map's nearby card also carries a "See all"
link into Nearby. Switching layouts while standing on a tab that's no longer on the bar
lands you on Map — `UITab`'s view controller provider is lazy, so the old selection isn't
findable in the new arrangement.

That default is **part of `TabConfiguration`, not something `TabController` applies on the
way out** (`TabConfiguration.layoutHiddenByDefault`), so the Customize Tabs screen (§10),
the More rows, and the real bar always agree. `TabController.isDisplacedFromTabBar` is just
"not in `TabConfiguration.current.visible`", so hiding Favorites by hand while `searchTab`
already hides it still yields **exactly one** Favorites row in More.

Layout switching vs. the user's choice: a tab the user has never moved by hand follows
whichever layout is active (switch to `searchTab` → Favorites hides; switch away → it comes
back). Once the user moves Favorites in Customize Tabs, that choice is recorded in
`userInterface.tabBar.visibilityOverrides` and sticks across layout switches until Reset.

### 8a. Floating action button (`searchTab` layout only)

A 56pt Liquid Glass circle with an **outline** glyph, AX label = the screen it opens,
identifier `floatingActionButton` (`iBurn/Tabs/FloatingActionButton.swift`). It lives on
`TabController`'s own view, so it is on screen over every tab.

**Placement — it stacks on the search circle.** Bottom pinned to `tabBar.topAnchor` −12;
horizontally it is *measured*, not guessed: `TabController.searchTabCenterX()` walks the tab
bar's view tree for the trailing-most round item (square bounds 36–80pt in the bar's trailing
quarter — on this layout, the detached search circle) and centers the button on it, falling
back to safe-area trailing −16 if nothing matches. The measurement only works because it
calls `tabBar.layoutIfNeeded()` first: layout is top-down, so at `viewDidLayoutSubviews` time
the bar has a frame but its subtree is still all zero rects, and without the forced pass the
button silently keeps the fallback inset. Verify by screenshot, not by eye — the FAB and the
search circle should share a center to the pixel (1163.5px on an iPhone 17 Pro Max at 3x,
both with a 4-tab and a 2-tab bar).

MapLibre's attribution ⓘ used to sit in that corner. It no longer renders at all:
`MLNMapView.brc_setDefaults` sets `attributionButton.isHidden = true` app-wide, since the
app credits map data on the Credits screen and in the Settings acknowledgements. The
MapLibre wordmark logo is untouched, bottom-left. (The **AX element** "About this map" still
appears in `snapshot_ui` output — MapLibre publishes it from the map view itself — so judge
this from a screenshot, not the snapshot.)

- **What it opens is a user setting.** `FloatingActionButtonAction` ∈ {`favorites` (default),
  `events`, `nearby`}, stored in `userInterface.fab.action`; a master on/off lives in
  `userInterface.fab.enabled` (default true). Both are edited in Customize Tabs (§10) and
  write through `FloatingActionButtonSettings`, which posts `.floatingActionButtonDidChange`
  so the live button updates **while that screen is still open**. Glyphs: `heart`,
  `calendar`, `safari` (the compass, matching the Nearby tab icon — `location` would collide
  with the map's tracking arrow).
- **Visible only when** the `searchTab` layout is active *and* the button is enabled *and*
  the chosen screen is off the bar (`FloatingActionButtonVisibility.isVisible`). Choosing
  Events or Nearby therefore hides the button under the default layout, because those tabs
  are on the bar — the Floating Button footer says so and tells the user to remove that tab.
  Re-add the chosen screen in Customize Tabs and the button disappears — never two doors to
  one screen. Nothing on iOS 18.x, ever.
- **Tap → the chosen list as a `.large` sheet** with a grabber
  (`TabController.presentFloatingAction()`), built from the matching
  `BRCAppDelegate.create*ViewController()` — the same screen the tab and the More row use —
  wrapped in a `NavigationController`. Detail and "Show Map" pushes stay *inside* the sheet.
  Dismiss by dragging the list down (the sheet has no Done button); `drag` on the sheet's
  scroll view is unreliable from automation, so relaunching the app is the quick way out.
- **Hidden while search is active.** Selecting the search tab collapses the bar into a
  search field but triggers **no layout pass** on the tab bar controller, so this is driven
  by the search controller's delegate (`GlobalSearchTabFactory.makeSearchTabRoot(
  dependencies:searchActivationDidChange:)` → `TabController.searchIsActive`). If you touch
  either, re-check: tap Search → button gone; tap Close → button back.

### Writing app preferences from outside the app

Several flows need a preference set before launch. Two facts, both learned the hard way:

- `simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 <key> …` — the *user-level*
  domain — does **not** reach the app's container, which is what the app actually reads.
- **Editing the container plist as a file (PlistBuddy / `plutil`) is unreliable.** The
  simulator's `cfprefsd` holds a cached copy of that plist and rewrites it from cache, so a
  PlistBuddy `Set` appears to succeed and is then silently discarded — you re-read the file
  and the key is gone (or reverted). `plutil -replace` is doubly wrong here: it reads the
  `.` in these key names as a key path.

The reliable form goes through `defaults` **against the container path** (no `.plist`
extension), with the **app terminated first** so nothing re-writes the file behind you:

```bash
xcrun simctl terminate <UDID> com.trailbehind.iBurn2010
C=$(xcrun simctl get_app_container <UDID> com.trailbehind.iBurn2010 data)
PREFS="$C/Library/Preferences/com.trailbehind.iBurn2010"

# Map Search Layout (§8)
xcrun simctl spawn <UDID> defaults write "$PREFS" userInterface.map.searchLayout -string searchTab

# Unlock the location embargo (§6)
xcrun simctl spawn <UDID> defaults write "$PREFS" kBRCEntered2026EmbargoPasscodeKey -bool YES

# …and re-lock it
xcrun simctl spawn <UDID> defaults delete "$PREFS" kBRCEntered2026EmbargoPasscodeKey
```

Read values back the same way (`defaults read "$PREFS" <key>`), again with the app
terminated — a running app's writes land in the cache, not the file.

**Capturing animations:** `record_sim_video` has failed to return a file path here;
`xcrun simctl io <UDID> recordVideo --codec h264 --force out.mov` in the background
(then `kill -INT`) works. Step through with ffmpeg — a `fps=2` tile locates the
transition, then `-ss <t> -t 1 -vf fps=60,tile=...` shows whether it actually
animated. Worth doing before trusting "the animation is broken/fixed" by eye, and the
only practical way to catch short-lived overlays such as the nearby card's hide tooltip.
Note `-frames:v 1` with `tile=` only covers the first tile's worth of frames — pass `-ss`
to reach later parts of a long recording.

**Software keyboard:** the simulator flips into hardware-keyboard mode after the
first `type_text` call and stays there, so keyboard-up states can't be captured
without quitting and reopening Simulator.app first (and `⌘K` via AppleScript is
blocked by Accessibility permissions).

## 9. watchOS app (iBurnWatch)

Companion watch app **embedded in the iOS app** (`iBurn.app/Watch/iBurnWatch.app`)
but independently runnable (`WKRunsIndependentlyOfCompanionApp`). Bundle id
`com.trailbehind.iBurn2010.watchkitapp`. Two ways to get it on a watch sim:

- **Paired install (companion path):** build scheme `iBurn`, `simctl install`
  the iOS app on a phone sim with an active watch pair (`xcrun simctl list
  pairs`) — the watch app auto-installs on the paired watch within ~10 s.
  Location authorization can carry over from the phone app.
- **Direct install (development):** build scheme `iBurnWatch` for
  `id=<WATCH_UDID>` (or `generic/platform=watchOS Simulator`) and
  `simctl install` the watch app directly.

Set XcodeBuildMCP session defaults to the watch sim UDID +
`simulatorPlatform: "watchOS Simulator"` before snapshot/tap.

**The watch seeds from the same pre-baked database as the phone.** It ships its own
copy at `iBurnWatch/PlayaDB-<year>.zip` (also gitignored, written by the same
`playa-seed` run) and restores it in `iBurnWatchApp.init()` — *before* `createPlayaDB()`,
since the restore is a no-op once a database file exists. `WatchSeeder.seedIfNeeded`
then runs in the root `.task` and re-imports only when the bundled JSON is newer
than the seed. Verify with the same query as §2 against
`com.trailbehind.iBurn2010.watchkitapp`'s container; `thumbnail_colors` = 1573 there
too (unused on watch — no thumbnails are rendered — but it rides along in the shared
seed). `update_info.created_at` staying at the *bake* time rather than launch time is
the tell that the restore was used and no JSON import ran.

1. Build (see above for scheme choice).
2. Set a BRC location first: `xcrun simctl location <WATCH_UDID> set 40.7864,-119.2065`.
3. Launch via simctl. On a fresh direct install, first launch shows the
   **location permission alert** — swipe the alert scroll-view up twice to
   reveal the buttons, then tap **"Allow While Using App"** (or "Allow Once").
4. Root is a **NavigationStack with the Map fullscreen** (Canvas-rendered BRC:
   dashed pentagon fence, radial street grid, plazas, user dot, The Man /
   Center Camp markers, user pins). Digital Crown zooms the map, drag pans —
   there is intentionally no page-swiping (gesture conflict). All four controls
   are **system toolbar buttons**, one per screen corner:
   top-left "Browse" (list.bullet), top-right "Favorites" (heart.circle),
   bottom-left the tracking button, bottom-right "Drop a pin here"
   (mappin.and.ellipse). The two bottom ones are `.bottomBar` toolbar items
   (watchOS 10+) — watchOS renders them as corner circles, not a bar.
5. The tracking button cycles MapKit-style, **free → follow → follow-heading →
   free**; its AX label states the *next* mode ("Follow my location" /
   "Switch to compass mode" / "Stop following my location"), which is the
   reliable way to assert the current mode from a snapshot. Simulators have no
   compass hardware, so heading mode stays north-up and no calibration hint shows.
6. **Browse** → rows: 📍 Nearby / 📌 Pins / 🏕️ Camps / 🎨 Art / 🚌 Vehicles / 🎪 Events.
   - Camps/Art/Vehicles: alphabetical searchable list (search field automation
     is unreliable — the watch keyboard's AX field doesn't accept `type_text`;
     verify search logic in code/DB instead), distances shown with a GPS fix.
   - Events: day-chip strip ("Sun 30" …, defaults to today or first day; chips
     switch the list instantly) over name + "5:00 PM (2h)" rows. `adlt` events
     are excluded unless the user's location is on-playa.
7. Nearby → tap a row → Detail (favorite toggle, **visit-status button** — tap
   opens a sheet: Not Visited / Visited / Want to Visit — description,
   event occurrence times, **Navigate** when the object has GPS) → Navigate
   shows target marker + user dot + live "<distance> · <bearing>°" readout.
8. Favorites toolbar has a **Filter** button (sheet with "Show":
   Favorites / Want to Visit / Visited and "Type": All/Camps/Art/Events/Vehicles;
   icon fills when non-default).
9. **User map pins** (bike / home / star), synced with the phone:
   - Drop: bottom-right toolbar button → sheet with tinted Bike (green) /
     Home (orange) / Pin (yellow) rows → tap saves at the **current GPS fix**
     and dismisses. With no fix the sheet shows "Waiting for GPS…" instead —
     after a sim reboot the location resets, so re-run `simctl location set`
     or you'll only see that state.
   - List: Browse → 📌 Pins (distance-sorted; empty state "No pins yet").
   - Detail: Navigate (same compass view as objects) / Rename / Delete.
     Delete asks for confirmation, then pops back to the list.
   - Pins also render on the map as tinted circles with their SF Symbol inside.
     A pin at your exact location is hidden under the user dot (the dot draws
     last) — move the sim location to see it.

Verify: city geometry renders (not a blank background); PlayaDB.sqlite exists in
the watch app container with 2026 counts
(`xcrun simctl get_app_container <WATCH_UDID> com.trailbehind.iBurn2010.watchkitapp data`);
favoriting writes `object_metadata` `camp|<uid>|1` etc.;
dropping a pin writes `user_map_pins`
(`SELECT id,title,pin_type,is_deleted FROM user_map_pins;`).

### Phone↔watch sync (`PeerSyncManager`)

Favorites, visit status, **and user map pins** sync bidirectionally over
WatchConnectivity `applicationContext` (best-effort, latest-state; LWW merge via
`PlayaDB.applyFavoriteSync` / `applyUserMapPinSync`). All payloads ride in **one**
manager and one context dictionary — `updateApplicationContext` replaces the
dictionary wholesale, so a second publisher would clobber the first.
Both sims must be a booted **pair**
(`xcrun simctl list pairs` → "(active, connected)"); the phone app and watch app
each start their manager at launch (phone: `DependencyContainer` init; watch:
root `.task` after seeding).

1. Favorite an event on the phone (flow 4) → within seconds the watch's
   `object_metadata` gains `event|<parent uid>|1` with `favorite_updated_at`
   set, and the watch Favorites screen lists it (event details show occurrence
   times, e.g. "Sun 5:00 – 7:00 PM").
2. Favorite a camp on the watch (Nearby → detail → Add Favorite) → the phone's
   PlayaDB gains `camp|<uid>|1` AND the phone's Yap mirror updates the
   `BRCCampObject` metadata blob (`isFavorite=true`; for events, all
   `"<uid>-<n>"` occurrence rows + EKEvent, same as flow 4).
3. Delivery requires the peer app to be installed at push time; the managers
   re-push on `sessionWatchStateDidChange`/`sessionCompanionAppInstalledDidChange`,
   on activation, and on every favorite change, so a fresh watch install
   converges on first launch.

Sync checks: `SELECT object_type, object_id, is_favorite, visit_status FROM
object_metadata WHERE favorite_updated_at IS NOT NULL OR visit_status_updated_at
IS NOT NULL;` on either DB. Un-favoriting syncs too (rows persist with
`is_favorite=0`).

**Pins sync the same way** (LWW on `modified_date`):

1. Drop a pin on the watch → the phone's `user_map_pins` gains the row and the
   annotation appears on the phone map immediately (`FilteredMapDataSource`
   observes PlayaDB; no Yap mirror is involved).
2. Drop one on the phone (map sidebar bike/home/star → name → Save) → it appears
   in the watch's Browse → Pins.
3. Delete on either device → the row becomes a **tombstone**
   (`is_deleted=1`, `modified_date` bumped) rather than disappearing, which is
   what lets the deletion win the peer's merge. Expect the tombstone row to
   persist in both DBs; only `fetchUserMapPins`/`observeUserMapPins` filter it.
   A tombstone for a pin the peer never had is **not** inserted, so the two DBs
   legitimately differ in tombstone rows — compare `is_deleted=0` rows when
   checking convergence.

**Visit status syncs the same way** (per-field LWW on `visit_status_updated_at`,
values 0=unvisited/1=visited/2=wantToVisit): setting "Want to Visit" on the
watch shows up in the phone's PlayaDB `visit_status` AND its Yap metadata blob;
setting a status in the phone detail's VISIT STATUS cell (below USER NOTES —
present on both the legacy and PlayaDB detail paths) appears on the watch.
The rating prompt ("Enjoying iBurn?") can block phone UI automation — it's not
in the AX tree, so there's no elementRef to tap. Appirater is configured with
`setTimeBeforeReminding:2` (`BRCAppDelegate.m`), so a plain terminate + relaunch
can bring it straight back. Suppress it at the defaults layer instead, then
relaunch:

```bash
xcrun simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 kAppiraterDeclinedToRate -bool YES
xcrun simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 kAppiraterRatedCurrentVersion -bool YES
```

Pre-embargo note: the bundled data has **zero GPS rows**, so Nearby shows an
explanatory empty state and Detail hides Navigate. To exercise those flows,
inject GPS into a few `camp_objects` rows via plain `UPDATE` — the
`*_spatial_update` triggers keep `spatial_index` in sync automatically — then
uninstall the app afterward so the DB reseeds clean.

## 10. Customize Tabs (tab bar configuration)

More tab → **Customize Tabs** (in the same group as Appearance). `MoreViewController` cells
are not tap targets in the AX snapshot, so reach it with
`touch({ elementRef: <ref of the "Customize Tabs" text row>, down: true, up: true })`.

The screen is a SwiftUI list held in **permanent edit mode** (`.environment(\.editMode,
.constant(.active))`), with three sections (the third only on the `searchTab` layout):

- **Tab Bar** — every visible tab, each row `minus.circle.fill` (or a `lock.fill` for Map
  and More, which can't be hidden) + icon + title + a drag handle. Footer: "Drag to
  reorder. Map and More always stay on the tab bar." **This section always matches the real
  bar**, so in the `searchTab` layout it lists four rows (Map / Nearby / Events / More),
  not five.
- **In More** — hidden tabs with a green `plus.circle.fill`; "Nothing hidden." when empty.
  In the `searchTab` layout Favorites starts here by default, and the footer says why. When the
  bar is at capacity the plus buttons are **disabled and grey** (they drop out of the AX
  targets entirely — a hidden row with no `Add <tab> to tab bar` ref is the disabled state),
  and the footer gains "The tab bar is full — …".
- **Floating Button** (`searchTab` layout only — the section is absent otherwise, since
  there is no button to configure) — a **Show Floating Button** toggle and an **Opens**
  menu picker (Favorites / Events / Nearby) that greys out while the toggle is off. See
  §8a. The footer is the whole UX for the awkward case: picking a screen that still has a
  tab hides the button, and the footer says "*Events* is on the tab bar, so the floating
  button is hidden — one way in is enough. Remove *Events* from the bar above to bring the
  button back." Both controls write immediately and the button on screen follows within the
  same frame.
- **Reset** (nav bar trailing) is disabled only while nothing has been customized —
  including the invisible case where the user *explicitly* hid Favorites under `searchTab`,
  which looks identical to the default until you change layouts (`TabConfiguration.isUntouched`).
  Reset covers the **tab arrangement only** — it does not touch the floating button's
  settings, which are separate preferences.

Every edit writes `TabConfiguration.current` (`userInterface.tabBar.order` +
`userInterface.tabBar.hidden` + `userInterface.tabBar.visibilityOverrides`) and posts
`.tabConfigurationDidChange`, so the tab bar **rebuilds live behind the screen** — there is
nothing to save or cancel.

Automation: the minus/plus buttons *do* receive taps in active edit mode (tap their
`Remove <tab> from tab bar` / `Add <tab> to tab bar` AX refs). The **Opens** picker needs
the *value* element, not the row: `tap` on the row's `Opens` button ref lands on the label
and does nothing — `touch({ elementRef: <ref of the value text, e.g. "Favorites">, down:
true, up: true })` opens the menu, whose items then appear as `Favorites|heart`,
`Events|calendar`, `Nearby|safari` refs. (The picker is `.menu` style precisely because a
navigation-link picker is not reliably tappable in a permanently-editing List.) Reordering
works with
`drag` on a row's `drag` handle image — `distance ≈ 0.06` per row of travel, e.g.
`drag({ elementRef: <handle>, direction: "down", distance: 0.12, duration: 1.6, steps: 30 })`.

Verify: hiding a tab removes it from the bar and adds a row at the **top of More**;
un-hiding puts it back (appended to the end of the bar — re-adding does *not* restore the
original position); Reset restores the active layout's default (Map / Nearby / Favorites /
Events / More, minus Favorites under `searchTab`, where the floating button replaces it).

> Regression to re-check after any edit here: a **just-unhidden row must show a drag handle
> and survive being dragged**. Both sections hold `TabIdentifier` values, so when they shared
> `id: \.self` the permanently-editing List recycled the cell across the section boundary —
> the new Tab Bar row came back with no reorder handle and the next drag crashed. The fix is
> section-scoped row IDs (`bar.<id>` / `more.<id>`) plus `.id(configuration.hidden)` on the
> List. Exercise: hide a tab → un-hide it → drag it twice.

> **Capacity rule.** A compact-width bar shows five items; a sixth makes UIKit spill the
> tail into its *own* `•••` More tab — a second "More" beside the app's, with Search inside
> the overflow. So app tabs get **`TabConfiguration.visibleCapacity` slots: 5, or 4 while
> the search tab holds one** (`.searchTab` layout on iOS 26). The clamp
> (`TabConfiguration.limited(toCapacity:)`) runs in the `current` getter and drops the
> **last hideable** visible tabs; `TabController.rebuildTabs()` re-applies `prefix` as a
> guard. Because it is applied on read and **never persisted**, a layout switch that shrinks
> capacity doesn't record a user choice: put all five on the bar under `navigationBar`,
> switch to `searchTab` → the last hideable tab drops into More with `visibilityOverrides`
> untouched, and
> switching back restores it at its custom position. In the UI the rule shows up as greyed-out
> plus buttons, so you can no longer produce the duplicate-More state by hand.

> `TabController` keeps **one `UITab` per root view controller** (`tabCache`). A `UITab`
> owns the view controller its provider returns, so building a second tab around the same
> root raises "UIViewController cannot be shared between multiple UITab" — which crashed
> the app on the first rebuild after launch. If you touch `rebuildTabs()`, exercise a
> *second* rebuild (hide a tab from this screen), not just app launch.

## Known quirks / expected noise

- Yap legacy import logs ("Marking event ... as all-day", "Duped dates for ...")
  appear at every fresh launch — legacy pipeline, unrelated to PlayaDB.
- "Error fetching updates: unsupported URL" in sim logs: the updates URL secret
  is empty in local builds. Expected.
- Walk/bike times show "? min" until a location is set
  (`xcrun simctl location <UDID> set 40.7864,-119.2065`) — **and also whenever the object's
  embargo tier still hides its placement**, since the estimate is derived from the
  embargoed coordinates. So on the Nearby screen pre-embargo, camps and art legitimately
  read `🚶🏽 ? min 🚴🏽 ? min` even with a location fix; a real walk time there is a leak
  (`NearbyItem.canShowLocation` / `NearbyViewModel.distanceString`).
- The app dual-writes favorites Yap→PlayaDB; PlayaDB object data comes from the
  bundled seed only (network updates still flow through YapDatabase).
