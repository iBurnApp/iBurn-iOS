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

## Round 6 — user feedback on the round-5 screenshots

Four fixes, all on the same branch, no commit yet.

### 1. Nearby card location line — embargo (`NearbyCardView.swift`, `EmbargoTierTests.swift`)

- `Label(address, systemImage: "mappin.and.ellipse")` → plain `Text(address)`.
- **Investigation result: no leak.** "The Hitchin' Post — Open Playa" in screenshot
  08 is `ArtObject.locationString` (`address` = `locationString ?? timeBasedAddress`)
  surfaced through `NearbyItem.address`, which *does* gate on
  `BRCEmbargo.canShowArtLocations()`. It rendered because the simulator's prefs had
  `kBRCEntered2026EmbargoPasscodeKey = true` left over from an earlier passcode unlock,
  so `allowEmbargoedData` was legitimately YES. Deleting that key from the container
  plist and relaunching hides the line (the card falls back to the description) —
  screenshot 21.
- Tiers as of 2026-08-08: `campLocationUnlock` 2026-08-23 00:01 PDT, `eventStart`
  (art tier) 2026-08-30 00:01 PDT — so today both are locked without the passcode.
- Nearby *screen* agrees by construction: `NearbyView`'s art/camp rows use
  `ObjectRowView`, which renders no address at all for art/camps, and its event rows
  already gate `hostAddress` on `BRCEmbargo.canShowLocation(for:)`.
- Testable after all — `EmbargoTierTests` already owns the mock-date
  (`BRCMockDateEnabled`/`BRCMockDateValue`) + passcode harness, so 7 new cases there
  drive `NearbyItem.address` across all three tiers, blank strings, and the
  event-follows-its-host / free-text-fallback rules.

### 2. Nearby card layout (`NearbyCardView.swift`)

- X overlay deleted; footer is now `Hide | dots | See all` (Hide has the same weight
  as See all and does exactly what X did).
- Heart moved to the card's top-trailing overlay, *outside* the `TabView` — same
  trick the X used, so it can't eat a page swipe — and it retargets to
  `selectedItem` as pages change. `NearbyCardContentView` lost `isFavorite` /
  `onFavoriteTap` entirely.
- Audio-tour button **stayed in the row**, now bottom-aligned in a 60 pt column so it
  clears the heart. The content's `.padding(.trailing, 34)` also stayed: it's still
  clearance for a corner control, just a different one (without it a long name runs
  under the heart).

### 3. Search: pinned scope bar + real nav bar (`GlobalSearchView/ViewModel/HostingController`, `GlobalSearchTabFactory`)

Two independent causes:

1. **Bar floating mid-screen**: `results` is a `ZStack` whose only child in the empty
   states is a fixed-size glyph + label, so it sized to its content and the hosting
   controller centered the whole view. Diagnostic `NSLog` proved the safe area was
   already right (`{116,0,83,0}` = nav bar bottom). Fixed with an explicit
   `.frame(maxWidth: .infinity, maxHeight: .infinity)` plus
   `safeAreaInset(edge: .top)` for the bar (overlay mode keeps its bottom `VStack`).
2. **No nav bar**: `UISearchTab.automaticallyActivatesSearch` arrives with search
   active, and `UISearchController.hidesNavigationBarDuringPresentation` defaults to
   `true` → the bar (and its title/items) was hidden the whole time. Set to `false`.

Filter affordance is now one per layout: `.searchTab` gets a
`UIBarButtonItem` (via `GlobalSearchHostingController.installFilterBarButtonItem()`,
which also clears `showsInlineFilterButton` and subscribes to `viewModel.$filter` to
swap the `.fill` variant); `.navigationBar` and `.bottomAccessory` keep the inline
icon. Sheet presentation moved from `@State` to `viewModel.isShowingFilters` so UIKit
can open it.

### 4. Events default + placeability (`TabConfiguration.swift`, `TabController.swift`, `CustomizeTabsView.swift`)

Root cause: `rebuildTabs()` removed the Events root unconditionally on the
`.searchTab` path, independent of `TabConfiguration` — so the customization screen
and the More rows described a bar that wasn't on screen, and un-hiding Events did
nothing. That removal is gone; visibility is `TabConfiguration.current` alone (the
`tabCache` stays — rebuilds still crash without it).

- `TabConfiguration.layoutHiddenByDefault` = `[.events]` while `.searchTab` is active
  on iOS 26+, folded into `current`'s getter → a user who never customized sees
  Events under "In More" and gets the same 4-tab bar as before.
- **Events-default mechanism chosen**: a third preference,
  `userInterface.tabBar.visibilityOverrides`, holding ids whose visibility the user
  set by hand. The `current` *setter* derives it — it diffs the incoming config's
  hidden set against the effective one and marks whatever flipped — so
  `CustomizeTabsView` needed no changes, and reordering or hiding *another* tab never
  marks Events. The setter also strips layout-default hiding out of what it persists,
  so an unrelated edit can't freeze the default into the user's prefs.
- Layout switches therefore behave as specified: untouched Events follows the active
  layout; an explicit choice sticks until `resetToDefault()` (which bypasses the
  setter and clears the overrides).
- `isDisplacedFromTabBar(_:)` collapses to
  `!TabConfiguration.current.visible.contains(identifier)`.
- `Reset` compares against `TabConfiguration.layoutDefault`, and is enabled whenever
  `!TabConfiguration.isUntouched` — an explicit "Events hidden" under `.searchTab`
  looks identical to the default but still needs undoing. "In More" footer explains
  why Events starts there.
- Consequence worth knowing: putting Events back gives 6 tab items, and iOS spills
  the last two (Events + Search) into its own `•••` overflow tab. Honest UIKit
  behavior, and exactly why the default exists — screenshot 31.

### Round-6 verification

- Build clean, **267 tests / 0 failures** (249 → +7 embargo/nearby-address,
  +11 tab-config).
- Screenshots `21`–`34` in `Docs/images/2026-08-08-config-features/`: card without pin
  glyph and with the location line withheld under embargo (21), heart filled (22),
  heart following a page swipe (23), card hidden via "Hide" (24), search tab with nav
  bar + pinned scope bar (25), filled nav filter icon (26), results (27) and results
  scrolled under the bar (28), More with a single Events row (29), Customize Tabs at
  the `.searchTab` default (30), Events dragged onto the bar with the iOS overflow tab
  (31), Events hidden again with Reset live (32), overlay layout keeping its inline
  filter icon (33), nav-bar layout keeping its inline filter icon (34).
- Tooltip after "Hide" confirmed via the AX snapshot returned by the tap (its 4 s life
  is shorter than a screenshot round-trip, as flows.md warns).

## Known warts / follow-ups (not blocking)

- Un-hiding a tab appends it to the end of the bar rather than restoring its
  original slot (consistent with the list UI; draggable; maybe not expected).
- ~~Customize Tabs lists Events under "Tab Bar" even when the `.searchTab`
  layout has displaced it into More~~ — fixed in round 6.
- Scope bar was tight in round 5 because the inline filter button shared its row.
  Under `.searchTab` that button moved to the navigation bar, so the segmented
  control has the full width; the other two layouts still carry the inline icon —
  check for compression there on 6.1"/SE-class widths.
- Two search VM instances (map layout vs search tab) each load the persisted
  filter at init and don't observe each other's changes.
- Camp rows show "🚶🏽 ? min" — pre-existing (2026 camps lack GPS), not a
  regression.
- Round-1 leftovers still parked: delete `BRCUserTrackingBarButtonItem.{h,m}`
  + bridging-header import + `UserTracking.xcassets`. (The stale `.searchTab`
  summary string, "Nearby moves onto the map card", was corrected in round 6 to
  "Events moves into More by default".)
- The embargo alert only appears in the launch that finishes onboarding
  (`setupNormalRootViewController`), not on subsequent locked launches —
  pre-existing, noticed while validating round 6.

## Cross-References

- `Docs/2026-08-06-bottom-search-liquid-glass-prototype.md` — rounds 1–4.
- PR #253 (draft, into `2026-updates`).
- `.claude/skills/drive-app/references/flows.md` — updated flow scripts.
