# iBurn critical flows — simulator driving scripts

Companion to the `drive-app` skill. Each flow lists preconditions, steps
(as XcodeBuildMCP UI-automation actions), and what to verify. Element labels
below are the accessibility labels/identifiers observed in snapshots — match on
label text, not on elementRef numbers (refs change every snapshot).

> **Maintenance:** if a step here doesn't match the running app, fix this file in
> the same session (see "Keeping the flow docs current" in SKILL.md).
> Last verified: 2026-07-03 against the 2026 dataset, iPhone 17 Pro Max sim.

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

Verify: tab bar shows Map / Nearby / Favorites / Events / More.

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
and `grdb_migrations` contains `v1-initial-schema`. Seeded counts (2026 data,
July 18 refresh): 321 art / 1201 camps / 2208 events / 4697 occurrences;
`object_metadata` stays empty until the user favorites/views something.

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

## 6. Map + embargo

- Map tab renders the MapLibre offline map immediately after onboarding.
- Camp/art locations are hidden until the embargo lifts (the "Locations Are
  Hidden" alert on first run explains this). Location-dependent pins won't
  appear in pre-event builds — this is expected, not a bug.
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

More tab → scroll to Feature Flags (DEBUG only) → toggles including
"Use SwiftUI Lists". Toggling takes effect on next relaunch for tab
construction.

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

1. Build (see above for scheme choice).
2. Set a BRC location first: `xcrun simctl location <WATCH_UDID> set 40.7864,-119.2065`.
3. Launch via simctl. On a fresh direct install, first launch shows the
   **location permission alert** — swipe the alert scroll-view up twice to
   reveal the buttons, then tap **"Allow While Using App"** (or "Allow Once").
4. Root is a **NavigationStack with the Map fullscreen** (Canvas-rendered BRC:
   dashed pentagon fence, radial street grid, plazas, user dot, The Man /
   Center Camp markers; compass + recenter buttons bottom-right). Toolbar:
   top-left "Browse" (list.bullet), top-right "Favorites". Digital Crown zooms
   the map, drag pans — there is intentionally no page-swiping (gesture conflict).
5. Compass button ("Switch to compass mode") toggles heading-up; simulators have
   no compass hardware, so the map stays north-up and no calibration hint shows.
6. **Browse** → rows: 📍 Nearby / 🏕️ Camps / 🎨 Art / 🚌 Vehicles / 🎪 Events.
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

Verify: city geometry renders (not a blank background); PlayaDB.sqlite exists in
the watch app container with 2026 counts
(`xcrun simctl get_app_container <WATCH_UDID> com.trailbehind.iBurn2010.watchkitapp data`);
favoriting writes `object_metadata` `camp|<uid>|1` etc.

### Phone↔watch favorites sync (`FavoritesSyncManager`)

Favorites sync bidirectionally over WatchConnectivity `applicationContext`
(best-effort, latest-state; LWW merge on the `favorite_updated_at` column via
`PlayaDB.applyFavoriteSync`). Both sims must be a booted **pair**
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

## Known quirks / expected noise

- Yap legacy import logs ("Marking event ... as all-day", "Duped dates for ...")
  appear at every fresh launch — legacy pipeline, unrelated to PlayaDB.
- "Error fetching updates: unsupported URL" in sim logs: the updates URL secret
  is empty in local builds. Expected.
- Walk/bike times show "? min" until a location is set
  (`xcrun simctl location <UDID> set 40.7864,-119.2065`).
- The app dual-writes favorites Yap→PlayaDB; PlayaDB object data comes from the
  bundled seed only (network updates still flow through YapDatabase).
