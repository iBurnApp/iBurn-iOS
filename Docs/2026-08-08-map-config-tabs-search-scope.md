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
- ~~Consequence worth knowing: putting Events back gives 6 tab items, and iOS spills
  the last two (Events + Search) into its own `•••` overflow tab. Honest UIKit
  behavior, and exactly why the default exists — screenshot 31.~~ **Superseded in
  round 7:** the native overflow is now designed away by a hard capacity rule; the
  bar can never reach six items. See "Round 7" below.

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

## Round 7 — Customize Tabs: missing drag handle / reorder crash + duplicate More tab

Two user-reported bugs against the round-6 build, both in More → Customize Tabs under
the `.searchTab` layout. Fixed on this branch (build clean, **275 tests / 0 failures**,
267 baseline + 8); runtime validation pending (separate agent).

### Bug 1 — un-hidden Events row has no reorder handle; dragging then crashes

Root cause (view layer, not data): `TabConfiguration` provably keeps `visible`/`hidden`
a strict partition (`movingToHidden` + `sanitized` both partition; the setter re-reads
through them), but `CustomizeTabsView` rendered both sections' ForEach with
`id: \.self` over the same `TabIdentifier` values. Un-hiding moved the *same List
identity* from the hidden ForEach into the visible ForEach inside one `withAnimation`
update; the permanently-editing List recycled the cell across the section boundary with
its hidden-section edit chrome (no reorder handle — visible in round-6 screenshot 31,
where Events is the only Tab Bar row without a handle) and left the `.onMove`
bookkeeping inconsistent, so the next drag committed bad indices and trapped. The
reverse move (hide, screenshot 12) looked fine only because hidden rows have no handle
to miss.

Fix (`CustomizeTabsView.swift`):
- Section-scoped row identities (`bar.<id>` / `more.<id>` via a private
  `TabIdentifier` extension), so a show/hide is a plain delete + insert, never a
  cross-section identity move.
- `.id(configuration.hidden)` on the List: any partition change rebuilds the list so
  every cell is configured fresh in edit mode (initial render provably gets handles
  right). Reorders don't change `hidden`, so a drag never rebuilds mid-gesture.
- Regression test `testEditSequenceKeepsVisibleAndHiddenAStrictPartition` walks the
  reported crash sequence (hide Favorites → show Events → reorder → layout switches)
  asserting the partition invariant and capacity after every write.

### Bug 2 — duplicate More tab (app More + native `•••`) designed away by capacity

Product rule change: **the bar never exceeds 5 items including the search tab**, so
UIKit's native More overflow can never trigger.

- `TabConfiguration.searchTabOccupiesBarSlot` (`.searchTab` + iOS 26) and
  `visibleCapacity` (5, or 4 while search holds a slot).
- `TabConfiguration.limited(toCapacity:)`: excess comes off the *right end* of the bar,
  never-hideable tabs keep their slots (deterministic: last hideable tabs give way
  first). Applied in the `current` **getter** (after layout-default folding) and in
  `layoutDefault` — never persisted, and never recorded in `visibilityOverrides`. So a
  5-visible config met by a capacity-4 layout switch loses its last hideable tab as
  layout pressure only, and gets it back the moment capacity returns
  (`testCapacityClampOnLayoutSwitchIsNotAUserChoice`).
- Customize Tabs: plus buttons grey out and no-op at capacity (`show()` also guards);
  the "In More" footer explains ("The tab bar is full — hide another tab to add one
  back", mentioning the search tab when it's the reason and the Events sentence hasn't
  already said so). The Events-default footer sentence now only appears while Events is
  actually hidden.
- `TabController.rebuildTabs()`: defensive
  `arrangedRoots(...).prefix(TabConfiguration.visibleCapacity)` on both paths — a
  future bug can cost an unrecognized trailing root, never a native overflow tab.
- Rewritten tests that assumed 5-app-tabs + search was legal: putting Events back now
  requires freeing a slot first (`testUserCanPutEventsBackAfterFreeingABarSlot`,
  `testExplicitEventsChoiceSurvivesLayoutSwitches`,
  `testResetRestoresTheActiveLayoutsDefault`).

Files: `iBurn/Tabs/TabConfiguration.swift`, `iBurn/Tabs/CustomizeTabsView.swift`,
`iBurn/TabController.swift`, `iBurnTests/TabConfigurationTests.swift`.

Runtime validation to exercise: searchTab layout → Customize Tabs: plus on Events is
greyed at the 4-tab default; hide Favorites → plus enables → show Events → row appears
*with* a working drag handle; reorder several times (no crash); bar shows
Map/Nearby/More/Events + search, exactly one More; hide Events again → returns under
"In More" and More screen row reappears; Reset restores the layout default; switch
layouts in Advanced and confirm capacity 4↔5 behavior and that a clamped-off tab
returns on the 5-slot layouts.

### Round 7 runtime validation (simulator, iPhone 17 Pro Max / iOS 26.5) — all pass

Driven end-to-end after a clean `build_run_sim` and a prefs reset (deleted
`userInterface.tabBar.{order,hidden,visibilityOverrides}` from the container plist).
Screenshots in `Docs/images/2026-08-08-config-features/`:

| # | Check | Result | Shot |
|---|---|---|---|
| 1 | `searchTab` default: Tab Bar = Map/Nearby/Favorites/More, Events "In More", Events plus greyed + footer explains | pass (plus is disabled — it drops out of the AX targets) | `36-customize-default-capacity.jpg` |
| 2 | Hide Favorites → Events plus enables | pass | `37-favorites-hidden-plus-enabled.jpg` |
| 3 | Show Events → row lands in Tab Bar **with** a drag handle (bug 1) | pass — handle matches every other row's trailing edge | `38-events-unhidden-drag-handle.jpg` |
| 4 | 4 consecutive drags (Events twice, Nearby, then Events again) | pass — no crash, order sticks, live bar matches each time | `39-after-four-reorders.jpg` |
| 5 | Exactly one "More", no native `•••`, ≤5 bar items throughout | pass in every state captured | all |
| 6 | Hide Events again → back "In More", one Events row on More screen, Favorites plus re-enables | pass | `40-…`, `41-…` |
| 7 | Reset → layout default | pass — screen hash identical to the item-1 state, Reset re-disables | `42-after-reset.jpg` |
| 8 | Layout switch `searchTab`→`navigationBar` (capacity 5) and back | pass — all five tabs return; back to `searchTab` drops Events again with `visibilityOverrides` still empty | `43-…`, `44-…`, `45-…`, `46-…` |
| 8b | Bug-2 core case: record an explicit "Events visible" override under `navigationBar` (hide then show), switch to `searchTab` | pass — clamp yields Map/Nearby/Favorites/More + Search (5 items, one More); plist keeps `order` = 5 entries and `visibilityOverrides` = [events], i.e. the clamp is not persisted | `47-override-visible-clamped-under-searchtab.jpg` |
| 9 | ~10 `rebuildTabs()` passes in one process (pid stable, runtime log clean); cold relaunch preserves both the customized order and the un-persisted clamp | pass | `48-relaunch-clamp-persists.jpg` |

No code changes were needed. Cosmetic notes only:

- The disabled plus uses `.secondary`, which in light mode reads nearly as dark as the
  `lock.fill` glyphs — legible as "not green", but not obviously disabled.
- After a live layout switch no tab item is highlighted until you tap one (the pushed
  screen stays put). Pre-existing `UITab` selection behavior, unrelated to these fixes.

## Round 9 — nearby card: vertical compaction + uniform edge padding

**Feedback:** "theres a ton of empty space in this nearby card, and the padding around the
edges is not uniform. at least for the favorite button. lets make it more vertically
compact." Screenshot showed a 2-line art row with ~40 pt of dead space between the text and
the footer, and a heart that hugged the corner tighter (6 pt) than the row's 12/14 pt inset.

**Single file touched:** `iBurn/Map/NearbyCard/NearbyCardView.swift`.

### Geometry, before → after

| | before | after |
|---|---|---|
| edge inset (thumbnail leading) | 14 | **10** (`contentInset`) |
| edge inset (row top) | 12 | **10** (`contentInset`) |
| edge inset (heart top/trailing) | 6 | **10** (`contentInset`) |
| row trailing clearance | 34 | **38** (`contentInset + 24 + 4`) |
| gap above footer | 6 | **2** (`rowFooterGap`) |
| text VStack spacing | 3 | **2** |
| worst-case text block | 74 | **72** (20 + 2 + 16 + 2 + 32) |
| `pageHeight` | 100 | **84** (10 + 72 + 2) |
| `footerHeight` | 30 | **28** (== the footer buttons' own height) |
| `cardHeight` | 130 | **112** |

Card is 18 pt shorter (−14%). Dead space under a 60 pt thumbnail-governed row (every art /
camp / 3-line event row in the 2026 data) went from 28 pt to 14 pt.

The four corners now share one constant. The footer gets `contentInset − 6` horizontal
padding so that, added to each button's own 6 pt label inset, "Hide" and "See all" land on
the same 10 pt line as the thumbnail and the heart.

`pageHeight` is still sized to the *unwrapped-address* worst case (72 pt of text) rather
than to the 60 pt thumbnail, so a wrapped two-line address can't clip even though the 2026
dataset never produces one. That costs 12 pt of slack on the common row; sizing to the
thumbnail instead would have got the card to ~102 pt but made a data change able to clip it.

### Validation (iPhone 17 Pro Max, iOS 26.5 sim)

Build clean; `iBurnTests` 275/275 (baseline). Screenshots in
`Docs/images/2026-08-08-config-features/`:

- `59-card-compact-art-2line.jpg` / `60-card-uniform-insets-crop.jpg` — 2-line art row.
  Measured off the @3x capture: card 335 px ≈ 112 pt; thumbnail leading/top and heart
  top/trailing all 30 px = 10 pt; "Hide"/"See all" on the same line.
- `61-card-heart-favorited-new-inset.jpg` — heart toggles at the new inset (tap landed at
  x=388 on a 410 pt card trailing edge = 10 + 12, exactly as designed).
- `62-card-heart-follows-page.jpg` — heart retargets on swipe; title y unchanged across pages.
- `63-card-audio-button-clears-footer.jpg` — audio button (fixture `.m4a`) sits above the
  footer with the 2 pt gap; no overlap.
- `64-card-event-3line-no-clip.jpg` — mock date 2026-09-04T11:00 at 40.77546,-119.20512,
  "Morning Yoga Flow" name + time + address, well clear of the footer.
- `65-card-long-title-truncates-before-heart.jpg` — "Erotic Photo Session with Razorba…"
  truncates inside the 38 pt trailing inset.
- `66-card-xxxl-dynamic-type.jpg` — 3-row event still clears the footer at XXXL.
- `67-card-accessibility-medium.jpg` — at `accessibility-medium` the third line now
  *overlaps* the footer band (previously it merely touched). Known limit of the fixed
  height; recorded in flows.md rather than fixed.
- `68-card-hidden-tooltip.jpg` — Hide → glass tooltip in the card's place (extracted from
  `simctl recordVideo`; `-ss` seeking on that file lands on stale frames, dumping with
  `-vf fps=3` works).
- `69-card-reenabled-via-map-filter.jpg` — re-enabled from Map Filter, clean at 112 pt.

Sim state restored afterwards: mock-date keys deleted, `kBRCEntered2026Embargo…Key` back to
NO, audio fixture removed, the art item favorited during the pass un-favorited, content size
back to `large`. The MapLibre AX crash on Map Filter → Done fired again even via
`touch down/up`; relaunching recovers and the preference had already been written.

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
