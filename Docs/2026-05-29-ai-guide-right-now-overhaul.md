# 2026-05-29 — AI Guide Overhaul: Single "Right Now" Flow

## High-Level Plan

### Problem
The AI Guide (More tab → "AI Guide") shipped on the `ai-event-summary` branch as 8 duplicative workflows
(catalog → per-workflow config screen) + a separate Chat surface + an orphaned "assistant" path. The flows
overlap heavily (For You and Surprise Me are the *same* `SerendipityWorkflow`; Adventure/Camp Crawl/Golden
Hour all return a `RouteResult`; Day Planner/Schedule Optimizer both produce schedules) and the top-level
input is thin. The user judged it "pretty rough."

### Direction (from the user, locked)
Collapse everything into **one flow** focused on **immediacy**: *"discover what's near you happening now,
and what to do next."* Route planning, day/schedule planning, the retrospective "What did I miss," the
chat, and the dead assistant path are all **cut**. Entry is a single "ask" screen: free-text + suggestion
chips ("Coffee", …) + a compact filter bar (time-of-day picker + place, including a **map-area picker**).
Place defaults to current location. Tone concise / no-snark.

### Decision trail (how we got here)
1. "Improve the AI guide, it's rough" → explored; surface is huge.
2. Focus = top-level UX; flows are duplicative; want suggestion chips + structured inputs (time of day,
   start location, region of city). Scope = comprehensive overhaul; AI Guide workflows first.
3. "Route planning is useless… same with time planning. Needs immediacy." → single ask screen; fold chat;
   region = map-area picker.
4. "Don't keep What did I miss." "Delete the dropped code." Time-of-day = sunrise/morning/midday/
   afternoon/evening/night/late-night.
5. "One flow" → discover what's near you happening now + what to do next. → 8 workflows collapse to **1**.

## Architecture

### One workflow: `RightNowWorkflow`
Given a vibe (+ time-of-day window + place), returns `RightNowResult { intro, now, next }`:
- **Now near you** = currently-happening events + nearby art/camps/MVs matching the vibe.
- **What to do next** = upcoming events (starting within the window) matching the vibe.
Steps: read taste (favorites, honor `lean`) → gather now/next candidates (place + time aware) →
one LLM curation+pitch call (wrapped in `withContextWindowRetry` + `retryWithCandidateFiltering`) →
resolve UIDs. Non-LLM steps kept as pure functions for tests. Walk time annotated via `playaWalkMinutes`.

### Engine changes
- `WorkflowContext` (`WorkflowProtocol.swift`) gains `region: MKCoordinateRegion?`, `windowStart/End`,
  `vibe`, `lean: DiscoveryLean`.
- `AgentOrchestrator.execute` threads `region/window/vibe/lean`; "now" anchored on `Date.present`.
- `TimeOfDay` + `dateWindow(for:now:)` (pure Swift, ungated): `.now` (default) → (now, now+2h); named
  periods (sunrise … lateNight) → BRC-local windows, lateNight spans into next-day early AM; clamped to
  `YearSettings.eventStart…eventEnd`.
- `Vibe`/`SuggestionChip` (ungated): chip catalog + `eventTypeCodes(forVibe:)`. Chips map to `(vibe, lean)`.
- `DiscoveryLean` (ungated): `.personalized/.surprise/.balanced`.

### UI
- `RightNowView` (new) replaces `AIGuideView` + `WorkflowDetailView` and folds chat. Free-text + chips +
  time-of-day Picker + place ("Near me" / "Pick area on map…") + Go + Now/Next results.
- `AIGuideViewModel` rewritten into the single-screen VM (concise honest error copy).
- `AreaPickerView` + `AreaPickerRepresentable` (new) on the `TimeShiftMapView` pattern; visible bounds →
  `MKCoordinateRegion`.
- `MoreViewController.pushAIGuideView()` pushes `RightNowView`.

### Must-keep (verified)
- `WorkflowUtilities.swift` + `GenerableEventCollectionSummary`/`GenerableFactCheck` → used by
  `DetailViewModel` for camp/art event summaries (a non-AI-Guide feature).
- `AISearchService.search` + `AISearchServiceFactory.create` → used by `GlobalSearchViewModel`.
- `playaWalkMinutes`.

### Delete (Phase 4)
7 dropped workflows + `WhatDidIMissWorkflow` + `GeneralChatWorkflow`; chat (`ChatView`/`Bubble`/`ViewModel`,
`ConversationManager`, `IntentClassifier`); catalog (`AIGuideView`/`WorkflowDetailView`/`WorkflowCatalog`);
assistant path (`AIAssistantView`/`AIAssistantViewModel`, `AIAssistantService` methods + `…createAssistant`).
Trim dead types from `AIAssistantModels`/`AISearchService`/`DependencyContainer`/`PlayaProgressMessages`/
`WorkflowProtocol`. Move `AIAssistantViewModel.ResolvedObject` → `AIResolvedObject`.

## Key Facts Discovered
- **Xcode 16 synchronized file groups** (`PBXFileSystemSynchronizedRootGroup`): `iBurn/` and `iBurnTests/`
  auto-include new files / auto-drop deleted ones. No `project.pbxproj` edits needed. (Only `iBurn-Info.plist`
  + `DetailActionCoordinatorTests.swift`/`Info.plist` are membership exceptions.)
- PlayaDB query API: `fetchEvents(filter: EventFilter(region:startDate:endDate:happeningNow:startingWithinHours:eventTypeCodes:includeExpired:))`,
  `fetchCurrentEvents(_ now:)`, `fetchUpcomingEvents(within:from:)`, `fetchObjects(in: MKCoordinateRegion) -> [any DataObject]`,
  `searchObjects(_) -> [any DataObject]`, `getFavorites() -> [any DataObject]`, `ArtFilter`/`CampFilter` have `region`
  (MutantVehicleFilter does not — MVs have no GPS).
- `[any DataObject]` exposes `uid`/`name`/`objectType`; concrete casts (`as? ArtObject`) needed for GPS.
- `Date.present` (`Date+iBurn.swift`) is the app-wide injectable "now". `TimeZone.burningManTimeZone` exists.
- Result-resolution helper `resolveObject(uid:playaDB:)` / `resolveDiscoveryItems` in `WorkflowUtilities.swift`.

## Progress — COMPLETE (pending review/commit)
- [x] Exploration + plan approved (`~/.claude/plans/what-were-we-up-zippy-dongarra.md`).
- [x] Phase 1: engine (`WorkflowContext`/orchestrator), `TimeOfDay`, `Vibe`, `RightNowWorkflow`, `AIResolvedObject`.
- [x] Phase 2: `RightNowView` + new `RightNowViewModel` + `MoreViewController`/`DependencyContainer` rewire.
- [x] Phase 3: `AreaPickerView` + `AreaPickerMapRepresentable` + sheet wiring.
- [x] Phase 4: deleted 21 files; trimmed `AISearchService`/`AIAssistantModels`/`DependencyContainer`/
      `WorkflowProtocol`/`WorkflowUtilities`; preserved progress types in `WorkflowProgressTypes.swift`.
      No `project.pbxproj` edits needed (synchronized groups).
- [x] Phase 5: tests — `TimeOfDayTests` (6), `VibeTests` (8), `AreaRegionTests` (2),
      `RightNowCandidateTests` (4); pruned dead assistant tests from `AISearchToolTests`.

### Files added
`TimeOfDay.swift`, `Vibe.swift`, `AIResolvedObject.swift`, `WorkflowProgressTypes.swift`,
`Workflows/RightNowWorkflow.swift`, `RightNowViewModel.swift`, `RightNowView.swift`, `AreaPickerView.swift`;
tests `TimeOfDayTests.swift`, `VibeTests.swift`, `AreaRegionTests.swift`, `RightNowCandidateTests.swift`.

### Results
- App builds clean (`iBurn` scheme): **0 errors**. Remaining warnings are all pre-existing files
  (MainMapViewController, DataUpdatesView, DetailViewModel, NearbyListHostingController) — none from this work.
- Full `iBurnTests`: **87 run, 86 pass, 1 fail**. All AI tests pass; `GlobalSearchViewModelTests` (10) pass,
  confirming the kept semantic-search path. The one failure —
  `ObjectListViewModelTests.testToggleFavoriteCallsProvider` (line 212, ~1.05s timeout) — is a
  **pre-existing, deterministic** failure in `ListView/ObjectListViewModel` (generic VM + mock provider,
  observation stream not reflecting a favorite toggle in the harness). It is outside the AI Guide surface
  (no files I changed touch it) and fails identically in isolation. Not caused by this work; left as-is.

### Decisions worth remembering
- `RightNowWorkflow` deliberately does NOT set `EventFilter.includeExpired = false` for the "next" pool —
  `startDate = max(windowStart, now)` already excludes started/ended events, and `includeExpired` filters
  against the *real* current date (breaks past-window queries / tests / off-season).
- Event type codes follow `EventTypeInfo` (DB codes: `tea`, `live`, `medt`, `prde`, `sprt`, …), NOT the
  PlayaAPI `EventType` raw values.
- Pure helpers (`TimeOfDay`/`dateWindow`, `Vibe`/`eventTypeCodes`, `coordinateRegion`,
  `gatherRightNowCandidates`) are kept LLM-free so they're unit-testable on any simulator.

## Verification
- Build per phase: `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' 2>&1 | xcsift -f toon -w`.
- Tests: `iBurnTests`, `PlayaKitTests`.
- Regression: global semantic search; camp/art detail event summaries.
