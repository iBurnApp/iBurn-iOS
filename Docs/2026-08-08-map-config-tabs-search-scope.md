# 2026-08-08 — Nearby card config, tab customization, search scope

Round 5 of the bottom-search / Liquid Glass prototype (branch
`prototype/bottom-search-liquid-glass`, draft PR #253 into `2026-updates`).
Continues `Docs/2026-08-06-bottom-search-liquid-glass-prototype.md`.

## High-Level Plan

Three user-requested features, built by three parallel Opus 5 implementation
agents (scoped to disjoint file sets), integrated/validated by a fourth agent,
orchestrated from the main session:

1. **Nearby card becomes config-toggled; the collapsed FAB is gone.**
   Original round-5 idea was "move the FAB to a screen edge + X to minimize";
   user pivoted mid-planning: no on-map collapsed button at all. The X (card
   top-right) now *hides* the card by preference; a ~4 s tooltip points at the
   re-enable path; Map Filter gains a "Nearby Card" section with an on/off
   toggle and per-type toggles (a friend wants an art-only card).
2. **Tab order customization** (More → Customize Tabs): drag-to-reorder, hide
   Nearby/Favorites/Events (hidden tabs surface as rows in More), Map and More
   never hideable ("otherwise you could end up in a real pickle"). Persisted,
   sanitized, live-rebuilds the bar.
3. **Global search drill-down**: segmented scope bar (All/Art/Camps/Events/
   Vehicles) at the top of the search screen — the priority — plus a filter
   icon presenting a sheet (Only Favorites; Happening Now for events).

## Technical Details

### Feature 1 — Nearby card (`iBurn/Map/NearbyCard/`, `MainMapViewController.swift`, `MapFilterView.swift`)

- **Deleted** the entire minimize/morph machinery: `isMinimized`,
  `setMinimized`, the pin cross-fade, `countBadge`, `CollapsedAccessibility`,
  `fabDiameter`, the chevron button, and all the morph-workaround comments.
  This also retires the round-3 VoiceOver wart (the collapsed card's buttons
  lingering in the AX tree) — there is no collapsed state anymore.
- New `iBurn/Map/NearbyCard/NearbyCardPreferences.swift`:
  - `userInterface.nearbyCard.enabled` (Bool, default true)
  - `userInterface.nearbyCard.showArt` / `showCamps` / `showEvents` (Bool,
    default true), wrapped in a `NearbyCardTypes` OptionSet.
- `NearbyCardViewModel` observes all four preferences (Combine publisher from
  `PreferenceService`, hopped to the main actor) so Map Filter changes apply
  live. `orderedItems(...)` gained a `types: NearbyCardTypes` parameter
  (no default — call sites are the VM and the tests).
- X button sets the preference false; `MainMapViewController` shows a
  `UIVisualEffectView` tooltip ("Nearby card hidden — turn it back on in Map
  Filter"), auto-dismissing after 4 s, tap-to-dismiss, top-center where the
  card was.
- Map Filter's "Nearby Card" section sits second (after "Show on Map"); the
  type rows are `.disabled` while the card is off; saved via the screen's
  existing Cancel/Done idiom.
- `interactiveRect(in:)` simplifies to `items.isEmpty ? .zero : bounds`; the
  touch container survives (the hosting box is still bigger than the fade).

### Feature 2 — Tabs (`iBurn/Tabs/`, `TabController.swift`, `MoreViewController.swift`, `BRCDeepLinkRouter.swift`)

- `TabIdentifier` (map/nearby/favorites/events/more; stable raw values;
  `isHideable` false for map/more; leaf-VC-type resolver following the
  `displacedRootIndex` precedent).
- `TabConfiguration` + two prefs: `userInterface.tabBar.order` and
  `userInterface.tabBar.hidden` (`Preference<[String]>`). Sanitizer: unknown
  ids dropped, duplicates collapsed, missing ids appended canonically,
  non-hideable ids forced visible. Setter posts `.tabConfigurationDidChange`.
- `TabController.applySearchLayout()` → `rebuildTabs()`, observing both the
  search-layout and tab-config notifications; roots are ordered/filtered
  before either build path, so the iOS 26 search-tab path inherits custom
  order for free. iOS 26 `UITab`s now carry stable identifiers
  (`iBurn.tab.map` …). Hidden + search-displaced Events collapses to a single
  More row (`isDisplacedFromTabBar` is an OR).
- Both hardcoded `selectedIndex = 0` sites replaced with identifier-based
  `selectMapTab()` (TabController fallback + deep-link "View on Map").
- More: `DetailViewsRow` gains `.nearby`/`.favorites` shown only when hidden;
  `CustomizationRow.tabs` → `CustomizeTabsHostingController` (FeatureFlags
  hosting pattern). Customize Tabs view: permanent `EditMode.active` list,
  "Tab Bar" + "In More" sections, minus/plus to hide/show, lock glyphs on
  Map/More, Reset toolbar button. Writes go through the sanitizer and are
  re-read, so the config struct is the single source of truth.

### Feature 3 — Search (`iBurn/ListView/GlobalSearch*`, `MapBottomSearchController.swift`)

- `GlobalSearchScope` enum + segmented `Picker` and filter icon button at the
  top of `GlobalSearchView` — inside the SwiftUI view, so all three
  `MapSearchLayout`s get it (no `scopeButtonTitles`). Overlay mode gets a
  material chip behind the bar only when no result list is showing.
- Pipeline refactor: monolithic `searchObjects()` (quoted-phrase FTS, no
  filters) → per-type `fetchArt/fetchCamps/fetchEvents/fetchMutantVehicles`
  with filter structs. Semantic changes, all deliberate:
  - phrase-match → **AND-of-tokens** (`FTS5Pattern(matchingAllTokensIn:)`) —
    "questions burning" now matches "Burning Questions";
  - ordering is alphabetical (art/camps/vehicles) and chronological (events)
    instead of FTS rank;
  - events come from the occurrence-level query (deduped to earliest matching
    occurrence per event), so Happening Now shows the *matching* occurrence.
  - scoped searches skip the other tables entirely (free perf win).
- `GlobalSearchFilter` (`onlyFavorites`, `happeningNow`): sheet modeled on
  `EventFilterSheet`; Happening Now only rendered when the scope allows
  events. Filter persists (`globalSearchFilter` UserDefaults key, the
  `ObjectListViewModel` convention); scope is session-only and resets on
  bottom-overlay deactivation.
- AI search: skipped when Only Favorites is on; AI results filtered by scope
  at resolve time. Bonus fix: the AI sparkles badge never matched event rows
  (composite `uid_occurrenceId` vs object uid) — now keyed by object uid.

### Integration fixes (first compile of all three features together)

1. `GlobalSearchViewModelTests.swift` — `XCTUnwrap(try await …)` doesn't
   compile (autoclosure can't await); hoisted the fetch.
2. **Ghost card bug**: hiding the card via `.frame(0,0)` + `.opacity(0)`
   inside `GlassEffectContainer` left a permanently compositing glass ghost
   over the tooltip. A `.glassEffect` surface keeps rendering its last frame
   when merely sized to zero — the card must leave the hierarchy
   (`if isHidden { Color.clear } else { … .transition(.opacity) }`).
   Screenshots 02/03 (before) vs 06 (after).
3. Tooltip label was pinned to the effect view's `contentView` (UIKit lays
   that out itself → no intrinsic size). Pinned to the effect view's own
   anchors + `bringSubviewToFront`/`zPosition` over the map's glass chrome.
4. **Crash**: second `rebuildTabs()` on the search-tab path threw
   `UIViewController cannot be shared between multiple UITab` — every rebuild
   wrapped roots in *new* `UITab`s while the old tabs still owned them. Fixed
   with a `tabCache` keyed by root `ObjectIdentifier` (+ cached `UISearchTab`),
   cleared when falling back to the `viewControllers` path. Any tab-hide would
   have crashed the shipped feature; flows.md now says to always exercise a
   second rebuild when testing here.
5. `questionmark.magnifyingglass` is not an SF Symbol (empty circle in the
   no-results state since round 3); → `exclamationmark.magnifyingglass`.

### Verification

- Build: clean (0 warnings). Tests: **249 passed / 0 failed** (217 baseline
  + 5 nearby-card + 16 tab-config + ~11 search).
- Simulator pass with screenshots in `Docs/images/2026-08-08-config-features/`
  (01–20): card hide/tooltip/re-enable/art-only; Customize Tabs reorder-live,
  hide-Favorites → More row, locks on Map/More, Reset; search scope bar,
  Camps+"yoga", filter sheet per scope, Only Favorites icon fill, scoped
  empty states; hidden+displaced Events shows exactly one More row.
- `.claude/skills/drive-app/references/flows.md` updated (search subsection,
  nearby-card subsection, new §10 Customize Tabs, §1/§8 touch-ups).

## Decision Rationale

- **No on-map collapsed button** (user pivot): kills the whole morph/touch
  carving complexity that rounds 2–4 fought; discoverability handled by the
  tooltip + Map Filter section.
- **Hide-tabs included** (not just reorder) because the "pickle" concern only
  exists if hiding exists; Map/More unhideable makes the pickle impossible;
  hidden tabs degrade to More rows via the round-3 Events-displacement
  mechanism, generalized.
- **Per-type fetch refactor** over bolting filters onto `searchObjects()`:
  the filtered request builders already combine FTS + knobs at SQL level, and
  scoped search gets cheaper instead of dearer.

## Known warts / follow-ups (not blocking)

- Un-hiding a tab appends it to the end of the bar rather than restoring its
  original slot (consistent with the list UI; draggable; maybe not expected).
- Customize Tabs lists Events under "Tab Bar" even when the `.searchTab`
  layout has displaced it into More — presentation is out of step with
  `MapSearchLayout` (the More-row logic itself is correct).
- Scope bar is tight on iPhone 17 Pro Max (~x358/400 + filter button at 375);
  expect compression on 6.1"/SE-class widths.
- Two search VM instances (map layout vs search tab) each load the persisted
  filter at init and don't observe each other's changes.
- Camp rows show "🚶🏽 ? min" — pre-existing (2026 camps lack GPS), not a
  regression.
- Round-1 leftovers still parked: delete `BRCUserTrackingBarButtonItem.{h,m}`
  + bridging-header import + `UserTracking.xcassets`; `MapSearchLayout`
  `.searchTab` summary string still says "Nearby moves onto the map card"
  (stale since round 3).

## Cross-References

- `Docs/2026-08-06-bottom-search-liquid-glass-prototype.md` — rounds 1–4.
- PR #253 (draft, into `2026-updates`).
- `.claude/skills/drive-app/references/flows.md` — updated flow scripts.
