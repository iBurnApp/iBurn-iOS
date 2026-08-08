# iBurn critical flows — simulator driving scripts

Companion to the `drive-app` skill. Each flow lists preconditions, steps
(as XcodeBuildMCP UI-automation actions), and what to verify. Element labels
below are the accessibility labels/identifiers observed in snapshots — match on
label text, not on elementRef numbers (refs change every snapshot).

> **Maintenance:** if a step here doesn't match the running app, fix this file in
> the same session (see "Keeping the flow docs current" in SKILL.md).
> Last verified: 2026-08-08 against the 2026 dataset, iPhone 17 Pro Max sim.

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
counts (2026 data, Aug 6 refresh): 330 art / 1196 camps / 2361 events /
4894 occurrences / 495 mutant vehicles / **1580 `thumbnail_colors`**;
`object_metadata` stays empty until the user favorites/views something.

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

- **Scope bar**: a segmented control `All / Art / Camps / Events / Vehicles`. Scoping
  changes which tables are queried at all, so a scoped search returns only that section
  (e.g. Camps + "yoga" → a single "Camps" section, alphabetical). Changing scope re-runs
  the query without retyping. Five segments plus the filter button fill the width — it
  fits on iPhone 17 Pro Max, check for truncation on narrower devices.
- **Filter button** (trailing, `line.3.horizontal.decrease.circle`): opens the "Filter
  Search" sheet. The icon switches to the **`.fill` variant whenever a filter is on**, and
  that is the *only* on-screen cue — the filter persists in `UserDefaults`
  (`globalSearchFilter`) across relaunches while the scope resets to All.
- Sheet contents: **Only Favorites** (all scopes; also disables AI suggestions) and, under
  an "Events" section, **Happening Now** — which is shown **only for the All and Events
  scopes**. A **Reset** button appears in the sheet when the filter is non-default.
- Empty states name the scope: "No camps for "Yoga"" / "Nothing matches that with these
  filters on." / "Try clearing the filters"; with no filter on it is "Nothing in this
  year's data matches that."
- Matching is **AND-of-tokens** FTS, so "questions burning" matches a name containing both
  words in either order.

Automation note: `type_text` into the field works here (the field is a stable AX target,
unlike the `searchable` fields in §5's list screens). The simulator autocapitalizes the
first letter ("Yoga") — harmless, FTS is case-insensitive.

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

### Nearby card (on-map)

A compact swipeable card pinned near the **top** of the map lists what is within ~100 m of
the user (events first, then art + camps by distance; `simctl location set` required or it
stays empty). Page dots + a "See all" link into the Nearby screen sit in its footer.

- **Close button** (X, top-right of the card, AX label "Hide nearby card") writes
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
**live** via `.mapSearchLayoutDidChange` — no relaunch.

`searchTab` rearranges the tab bar: **Events is replaced by a Search tab**, so the
tabs become Map / Nearby / Favorites / More plus a detached search button. Events
is reached from a More row that only appears in this layout. The map's nearby card
also carries a "See all" link into Nearby. Switching layouts while standing on the
displaced tab lands you on Map — `UITab`'s view controller provider is lazy, so the
old selection isn't findable in the new arrangement.

Layout displacement and the user's own tab customization (§10) compose: hiding Events in
Customize Tabs while `searchTab` has already displaced it still yields **exactly one**
Events row in More (`TabController.isDisplacedFromTabBar` is the single source of truth).

**Capturing animations:** `record_sim_video` has failed to return a file path here;
`xcrun simctl io <UDID> recordVideo --codec h264 --force out.mov` in the background
(then `kill -INT`) works. Step through with ffmpeg — a `fps=2` tile locates the
transition, then `-ss <t> -t 1 -vf fps=60,tile=...` shows whether it actually
animated. Worth doing before trusting "the animation is broken/fixed" by eye, and the
only practical way to catch short-lived overlays such as the nearby card's hide tooltip.
Note `-frames:v 1` with `tile=` only covers the first tile's worth of frames — pass `-ss`
to reach later parts of a long recording.

Setting the layout from outside the app is unreliable:
`simctl spawn <UDID> defaults write com.trailbehind.iBurn2010
userInterface.map.searchLayout -string searchTab` frequently does not survive to
the next launch (the running app flushes its own cached defaults over it, and
even writing while terminated didn't take). Drive the in-app picker instead.

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
.constant(.active))`), with two sections:

- **Tab Bar** — every visible tab, each row `minus.circle.fill` (or a `lock.fill` for Map
  and More, which can't be hidden) + icon + title + a drag handle. Footer: "Drag to
  reorder. Map and More always stay on the tab bar."
- **In More** — hidden tabs with a green `plus.circle.fill`; "Nothing hidden." when empty.
- **Reset** (nav bar trailing) is disabled while the configuration is the default.

Every edit writes `TabConfiguration.current` (`userInterface.tabBar.order` +
`userInterface.tabBar.hidden`) and posts `.tabConfigurationDidChange`, so the tab bar
**rebuilds live behind the screen** — there is nothing to save or cancel.

Automation: the minus/plus buttons *do* receive taps in active edit mode (tap their
`Remove <tab> from tab bar` / `Add <tab> to tab bar` AX refs). Reordering works with
`drag` on a row's `drag` handle image — `distance ≈ 0.06` per row of travel, e.g.
`drag({ elementRef: <handle>, direction: "down", distance: 0.12, duration: 1.6, steps: 30 })`.

Verify: hiding a tab removes it from the bar and adds a row at the **top of More**;
un-hiding puts it back (appended to the end of the bar — re-adding does *not* restore the
original position); Reset restores Map / Nearby / Favorites / Events / More.

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
  (`xcrun simctl location <UDID> set 40.7864,-119.2065`).
- The app dual-writes favorites Yap→PlayaDB; PlayaDB object data comes from the
  bundled seed only (network updates still flow through YapDatabase).
