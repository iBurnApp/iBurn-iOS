# Phase A R*Tree seed fix (kept) + Nearby/Right Now merge prototype (reverted)

**Date:** 2026-05-30 (Pacific)
**Branch:** `ai-event-summary`
**Continues:** [2026-05-29-ai-guide-right-now-overhaul.md](2026-05-29-ai-guide-right-now-overhaul.md)
**Plan:** `~/.claude/plans/what-were-we-up-zippy-dongarra.md`

---

## Outcome summary

1. **Kept + committed (`a48ecc1`):** a fix for a production-breaking Phase A bug — the occurrence
   R*Tree's `minT/maxT` constraint failed the seed import on the real bundled dataset. The index is
   now **spatial-only**.
2. **Prototyped, then reverted (per user decision):** Phase B merged the AI "Right Now" flow into
   the Nearby tab. The user opted to **keep Nearby as it was before Phase B** and **keep the AI flow
   as the standalone "AI Guide" entry on the More screen** (i.e. the state from the 2026-05-29
   overhaul). All Phase B working-tree changes were reverted; only the rtree fix remains.

---

## Phase A bug fix — occurrence R*Tree made spatial-only (KEPT)

### Symptom
`iBurnTests/RightNowCandidateTests` (which seed the real bundled data via `DependencyContainer`)
failed at `BRCAppDelegate+Dependencies.swift:28`:

```
SQLite error 19: rtree constraint failed: event_occurrence_rtree.(minT<=maxT)
  - while executing `INSERT OR REPLACE INTO event_occurrence_rtree (id, minLat, maxLat, minLon, maxLon, minT, maxT)`
```

### Root cause
`event_occurrences.start_time`/`end_time` are `TEXT NOT NULL`. The insert trigger computed
`minT = strftime('%s', start_time)`, `maxT = strftime('%s', end_time)`, each `COALESCE(..., 0)`.
For occurrences whose stored date strings don't parse via SQLite `strftime` (or whose end precedes
start), one bound resolved to a large epoch and the other to `0` → `minT > maxT` → constraint
failure → seed transaction rollback → `DependencyContainer` init failure (app ran on an empty DB).
In-memory test fixtures were clean, so it never tripped in tests; on device the failure was
caught/logged while the process still launched, so the prior session's "launch succeeded" was a
false positive on a broken/empty DB.

The time columns are **never queried** — `occurrenceIDsInRegion` filters spatially only — so the
temporal dimension was dead weight and the sole source of the fragility.

### Fix (`Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift`, commit `a48ecc1`)
Convert the occurrence rtree to **purely spatial** `rtree(id, minLat, maxLat, minLon, maxLon)`:
- `setupRTreeIndex(_:)`: detect the old 7-column schema via `PRAGMA table_info` → if `minT` present,
  drop the two triggers + the table, then recreate spatial-only. The rtree is derived data, so
  dropping is safe; this **self-heals the broken install** (the never-completed seed re-runs on next
  launch, since `update_info` is still empty).
- Insert trigger + `rebuildOccurrenceRTree(_:)`: index lat/lon only (no `strftime`, no date
  decoding, no constraint risk).

### Verification
- `swift test` in `Packages/PlayaDB`: **145/145** (~148s).
- `iBurnTests/RightNowCandidateTests`: **4/4** (previously errored on DB init).
- Device build/install/launch on BigPhone 17 (iOS 26.5): **SUCCEEDED** — bundled data now seeds.
- App build after revert (sim, iPhone 17 Pro Max, iOS 26.2): **success**, 0 errors, 6 pre-existing
  warnings.

---

## Phase B — merge prototype (REVERTED)

Implemented and verified, then reverted at the user's request. Recorded here for context.

The merge folded the standalone Right Now screen into the SwiftUI Nearby tab:
- `NearbyViewModel` gained a unified time/place model (`PlaceScope` near-me/area + `selectedDay` +
  `TimeOfDay`); events used the Phase-A occurrence R*Tree for region + client-side overlap for the
  time window. Replaced the "Warp" time-shift model.
- New `NearbyAISection.swift` (iOS 26+) added the vibe chips / "ask" / "Show me" + curated Now/Next
  on top, scoped to the same region+window.
- `RightNowViewModel` was slimmed (region+window passed in), owned by `NearbyListHostingController`;
  `RightNowView.swift` deleted; the More-tab "AI Guide" row + `pushAIGuideView` removed; new shared
  `PlaceScope.swift`.

### Why reverted
The merge lives on the `useSwiftUILists` (DEBUG) Nearby path, so removing the release-visible
More-tab entry would have dropped AI Guide for release users; and the user preferred to keep Nearby
unchanged for now. Decision: **revert Nearby to pre-Phase-B; keep the AI flow as the standalone
"AI Guide" on More** (the 2026-05-29 state).

### Revert mechanics
`git checkout HEAD --` on `NearbyView.swift`, `NearbyViewModel.swift`,
`NearbyListHostingController.swift`, `RightNowViewModel.swift`, `RightNowView.swift`,
`MoreViewController.swift`; `rm` of `NearbyAISection.swift` + `PlaceScope.swift`. Working tree now
matches the rtree-fix commit (`a48ecc1`) for all code.

---

## Notes for a future merge attempt
- The base Nearby still fetches `EventFilter(region:, includeExpired: true)` and filters
  "happening now" client-side. Region filtering benefits from the (now spatial-only) occurrence
  R*Tree; that path works and seeds correctly post-fix.
- The clean way to drop `RightNowWorkflow`'s camp→event expansion needs an **overlap-aware**
  region+window event query (the current DB time filter is start-time-based:
  `startTime >= start AND startTime < end`, which drops already-running events). Add that first.
- If a merge is revisited, decide the DEBUG/release gating for AI Guide up front.
