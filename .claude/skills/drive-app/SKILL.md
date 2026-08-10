---
name: drive-app
description: Build, launch, and drive the iBurn app in the iOS Simulator via XcodeBuildMCP UI automation — for verifying flows end-to-end, taking screenshots, and sanity-passing changes. Use when asked to run the app, exercise/verify a user flow, reproduce a UI bug, or validate database behavior on-device. Flow-by-flow steps live in references/flows.md.
---

# Driving the iBurn app in the Simulator

## Prerequisites

1. **XcodeBuildMCP** must be connected with the `simulator` and `ui-automation`
   workflows. `.xcodebuildmcp/config.yaml` in this repo already enables
   `["simulator", "device", "ui-automation"]`. If `tap` / `type_text` / `swipe`
   tools are missing from ToolSearch, the server predates the config — ask the
   user to run `/mcp` → reconnect XcodeBuildMCP.
2. Call `session_show_defaults` first. If workspace/scheme/simulator/bundleId are
   not set, set them:
   - workspacePath: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace`
   - scheme: `iBurn`
   - simulator: iPhone 17 Pro Max (look up the UDID with `list_sims`)
   - bundleId: `com.trailbehind.iBurn2010`

## Critical setup facts (learned the hard way)

- **The SwiftUI/PlayaDB stack is ON by default.** The flag
  `featureFlag.lists.useSwiftUI` (all builds, default true) acts as a
  kill-switch: set it to NO and you get legacy UIKit/YapDatabase screens and
  `PlayaDB.sqlite` is never created. To exercise the legacy stack, set before
  (re)launching:
  ```bash
  xcrun simctl spawn <UDID> defaults write com.trailbehind.iBurn2010 featureFlag.lists.useSwiftUI -bool NO
  ```
- **PlayaDB seeds lazily**, when the DependencyContainer is first built (tab
  construction after onboarding) — not at app launch. Don't conclude seeding is
  broken because the DB file doesn't exist yet; navigate into the main UI first.
- **`print()` output is not captured** in build_run_sim runtime logs (NSLog only).
  Verify database state by querying the on-sim SQLite file directly (below)
  instead of hunting for log lines.
- For **first-launch flows**, erase the simulator first:
  `xcrun simctl shutdown <UDID>; xcrun simctl erase <UDID>`.
- For **Nearby/location flows**, set a Black Rock City location:
  `xcrun simctl location <UDID> set 40.7864,-119.2065`.

## Interaction workflow

Observe with `snapshot_ui`, act with `tap`/`swipe`/`type_text` on elementRefs
from the latest snapshot, re-snapshot after navigation. Gotchas specific to this
app:

- **Onboarding carousel pages advance by swiping LEFT** on the page scroll-view.
  The action button only works on pages that request permissions; on info-only
  pages (Search, Nearby) tapping it does nothing — swipe instead.
- **Permission alerts arrive in this order** on a fresh install: notifications
  (springboard alert), then in onboarding: location → notifications
  (PermissionScope buttons) → calendar full-access. See flows.md for exact steps.
- After onboarding, an **embargo alert** ("Locations Are Hidden") appears over the
  map — dismiss via "Ok cool whatever".
- **Favorite hearts are not in the accessibility tree** as state, but the *button* is:
  match on its label, which flips between `"Favorite <name>"` and `"Unfavorite <name>"`
  (and the sibling image reports `heart` vs `heart.fill`). For a visual check take a
  `screenshot` and inspect the image.
- **Transient UI needs a screenshot in the same beat.** Anything that auto-dismisses - the
  favorite-series toast is up for 5s - will be gone by the time a separate `screenshot`
  tool call lands, because each round trip costs seconds. The AX snapshot returned *by the
  tap itself* still shows it, which makes it look like the view exists but never renders.
  To photograph it, temporarily raise its duration, rebuild, then screenshot.
- **SwiftUI searchable fields flicker in and out of the AX tree** (the
  "Search events" field may not be listed after scrolling). Prefer validating
  search at the database layer (FTS MATCH query below) unless the search UI
  itself is under test.

## Verifying database state directly

```bash
APP_DATA=$(xcrun simctl get_app_container <UDID> com.trailbehind.iBurn2010 data)
sqlite3 "file:$APP_DATA/Documents/PlayaDB.sqlite?mode=ro" "
  PRAGMA journal_mode;                          -- expect: wal
  SELECT COUNT(*) FROM art_objects;             -- ~332 (2026 data, Aug 9 refresh)
  SELECT COUNT(*) FROM camp_objects;            -- ~1191 (placed; GPS non-null for ~1184)
  SELECT COUNT(*) FROM event_objects;           -- ~2538
  SELECT COUNT(*) FROM event_occurrences;       -- ~5032
  SELECT identifier FROM grdb_migrations;       -- v1-initial-schema
  SELECT object_type, object_id, is_favorite FROM object_metadata;"
```

Invariants worth asserting after UI actions:
- Favoriting one **event occurrence** writes exactly one `object_metadata` row keyed
  `"<eventUID>#<ISO-8601 UTC start>"` (e.g. `pZKm9hfs...#2026-08-31T00:00:00Z`) - the
  `EventFavoriteKey` composite. Its left half must be a real uid from `event_objects` and
  its right half must match one of that event's `event_occurrences.start_time` values
  rendered as `strftime('%Y-%m-%dT%H:%M:%SZ', ...)`. **Never** the synthesized
  `"<uid>_<rowid>"` form (rowids are reissued by every import), and - since favorites
  became per occurrence - never the bare parent uid alone for a heart tapped on a row.
  Siblings of that occurrence must have **no** row.
- **"Favorite all N"** (the series toast, and a bare-`EventObject` heart) writes one row
  per occurrence *plus* a row on the bare parent uid.
- A **bare parent-uid row** from before this change is still honored: every occurrence with
  no row of its own reads as favorited from it. On the next app open,
  `foldLegacyEventFavorites` promotes it into explicit per-occurrence rows and leaves the
  parent row favorited as the fallback - so after a relaunch expect *N + 1* rows for such
  an event, all sharing the parent's `favorite_updated_at`.
- **Calendar entries follow occurrences**: `event_calendar_entries` must hold exactly one
  row per *favorited* occurrence, not per occurrence of a favorited event.
- Plain browsing/fetching must **not** create `object_metadata` rows (reads are
  write-free).
- FTS health: `INSERT INTO event_objects_fts(event_objects_fts)
  VALUES('integrity-check')` must not error; `MATCH` is stemmed and
  case-insensitive.

These `sqlite3`/`simctl` commands need the Bash sandbox disabled (simulator
container paths are outside the sandbox allowlist).

## Flow catalog

Step-by-step scripts for the critical flows (onboarding, events browsing,
favoriting, search, map/embargo, detail, feature flags) live in
[references/flows.md](references/flows.md). Read it before driving a flow.

## Physical devices

Running on real hardware (enabling the `device` workflow, discovery, code
signing) is covered in
[references/device-deploy.md](references/device-deploy.md).

## Keeping the flow docs current

These docs are maintained by whoever notices drift, in the session where they
notice it:

- If a flow in `references/flows.md` doesn't match what the app actually does
  (renamed screens, reordered onboarding, moved buttons, new permission prompts),
  **update the doc in the same session** and commit it with your other changes.
- If you add or materially change a user-facing flow, add/update its entry in
  `references/flows.md` as part of that change.
- Record data-shape drift too (seeded row counts change every festival year).
