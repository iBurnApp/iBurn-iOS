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

## 2. Enable the SwiftUI + PlayaDB stack

DEBUG builds only. The flag gates Favorites/Nearby/Events SwiftUI screens and
PlayaDB creation/seeding.

- CLI (preferred for automation): terminate app →
  `xcrun simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 featureFlag.lists.useSwiftUI -bool YES`
  → relaunch.
- In-app: More tab → Feature Flags → toggle "Use SwiftUI Lists".

Verify: after navigating to any tab post-launch,
`<app container>/Documents/PlayaDB.sqlite` exists, `PRAGMA journal_mode` = wal,
and `grdb_migrations` contains `v1-initial-schema`. Seeded counts (2026 data):
321 art / 1201 camps / 2101 events / 4431 occurrences; `object_metadata` stays
empty until the user favorites/views something.

## 3. Events browsing + day tabs

Preconditions: flow 2 done (SwiftUI stack on).

1. Tap the **Events** tab.
2. Day strip shows SUN 30 → SUN 6 (festival week). Tap another day (e.g.
   "WED, 2").

Verify: rows swap instantly to that day's events (day slicing is in-memory —
no spinner, no reload flash). Row content: name, type emoji, host camp,
description, "Wed 12:00am (12h)"-style time label.

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
- "List" button (top-left) opens the map list view; search field "Search" is in
  the map header.

## 7. Detail screen

From any list row (event/camp/art):
- Title + description, host section (tap navigates to host detail),
  "NEXT EVENT" section, "See all N events from <host>".
- Top bar: Share, favorite heart, back.
- Viewing a detail writes `last_viewed`/`first_viewed` metadata (this must NOT
  cause list observations to re-emit — the metadata region excludes those
  columns; regression-tested in FilterObservationTests).

## 8. Feature Flags screen

More tab → scroll to Feature Flags (DEBUG only) → toggles including
"Use SwiftUI Lists". Toggling takes effect on next relaunch for tab
construction.

## 9. watchOS app (iBurnWatch)

Standalone watch app (not embedded in the iOS app; separate install). Scheme
`iBurnWatch`, bundle id `com.trailbehind.iBurn2010.watchkitapp`. Use a watchOS 26
simulator (e.g. Apple Watch Ultra 3 49mm). Set XcodeBuildMCP session defaults to
the watch sim UDID + `simulatorPlatform: "watchOS Simulator"` before snapshot/tap.

1. Build: `xcodebuild -workspace iBurn.xcworkspace -scheme iBurnWatch
   -destination 'id=<WATCH_UDID>' build` (or `generic/platform=watchOS Simulator`).
2. Set a BRC location first: `xcrun simctl location <WATCH_UDID> set 40.7864,-119.2065`.
3. Install + launch via simctl. First launch shows the **location permission
   alert** — swipe the alert scroll-view up twice to reveal the buttons, then tap
   **"Allow While Using App"**.
4. Root is a **NavigationStack with the Map fullscreen** (Canvas-rendered BRC:
   dashed pentagon fence, radial street grid, plazas, user dot, The Man /
   Center Camp markers; compass + recenter buttons bottom-right). Toolbar:
   top-left "Nearby", top-right "Favorites". Digital Crown zooms the map,
   drag pans — there is intentionally no page-swiping (gesture conflict).
5. Compass button ("Switch to compass mode") toggles heading-up; simulators have
   no compass hardware, so the map stays north-up and no calibration hint shows.
6. Nearby → tap a row → Detail (favorite toggle, description, **Navigate** when
   the object has GPS) → Navigate shows target marker + user dot + live
   "<distance> · <bearing>°" readout.

Verify: city geometry renders (not a blank background); PlayaDB.sqlite exists in
the watch app container with 2026 counts
(`xcrun simctl get_app_container <WATCH_UDID> com.trailbehind.iBurn2010.watchkitapp data`);
favoriting writes `object_metadata` `camp|<uid>|1` etc.

Pre-embargo note: the bundled data has **zero GPS rows**, so Nearby shows an
explanatory empty state and Detail hides Navigate. To exercise those flows,
inject GPS into a few `camp_objects` rows AND insert matching
`spatial_objects`/`spatial_index` rows (UPDATEs alone don't maintain the R*Tree),
then uninstall the app afterward so the DB reseeds clean.

## Known quirks / expected noise

- Yap legacy import logs ("Marking event ... as all-day", "Duped dates for ...")
  appear at every fresh launch — legacy pipeline, unrelated to PlayaDB.
- "Error fetching updates: unsupported URL" in sim logs: the updates URL secret
  is empty in local builds. Expected.
- Walk/bike times show "? min" until a location is set
  (`xcrun simctl location <UDID> set 40.7864,-119.2065`).
- The app dual-writes favorites Yap→PlayaDB; PlayaDB object data comes from the
  bundled seed only (network updates still flow through YapDatabase).
