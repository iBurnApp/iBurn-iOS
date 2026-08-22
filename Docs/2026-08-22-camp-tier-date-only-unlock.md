# Camp tier: relaxed to a date-only unlock

**Date:** 2026-08-22
**Branch:** `2026-updates`
**Cross-references:**
- `Docs/2026-08-16-camp-boundary-embargo-tier.md` — the session that moved bulk camp
  placement (pins, `camp-labels-big`, `camp-boundaries`, viewport fetch, bulk event pins)
  off the camp tier and onto the gates tier, and introduced `MapEmbargo`. That split is
  the precondition for this change: without it, relaxing the camp tier would have
  published the whole city's placement a week early.
- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — the strict
  `passcodeUnlocked || (inRegion && now >= unlock)` rule this narrows.

## High-Level Plan

### Problem

The camp tier exists because the BMorg API ToS lets theme camp **addresses** be published
at 12:01 am on the Sunday of the week before the event (`YearSettings.CampLocationUnlock`,
Aug 23 2026 00:01 PDT) — a week before art placement opens at gates.

Under the strict rule, that early window was unreachable for the people it is for. A
device only satisfied the rule with `inRegion` — a GPS fix inside the 5-mile Burning Man
region, latched into `UserDefaults.enteredBurningManRegion`. But the point of releasing
camp addresses a week early is that burners can **plan before they travel**. Requiring
them to already be standing on the playa made the week-early release worth nothing: by the
time you satisfied it, gates were open anyway and everything unlocked.

### Policy decision (user)

> "Implement a relaxed unlock behavior for the camp playa address locations that are set to
> unlock 1 week before gates open. We can relax that to just a device date based unlock and
> not require GPS as well. For the art / camp map layer unlock, we'll still use the same
> unlock logic requiring GPS and time for now."

So the rule becomes tier-aware:

```
.camp: passcodeUnlocked || now >= campLocationUnlock
.art:  passcodeUnlocked || (inRegion && now >= eventStart)
```

The clock-spoofing exposure the strict rule was written against is bounded by what the
camp tier actually releases, which the Aug 16 session already narrowed to:

- a camp's **address text** (lists, detail, search, Nearby, distance strings), and
- the **single pin** for a camp the user navigated to (detail map, pushed map),
- plus favourite camp pins (user-curated, one at a time).

Everything that is placement *in bulk* stays on `.art` and still needs region + gates:
browse-map camp pins, `camp-labels-big`, `camp-boundaries`, the viewport region fetch,
bulk event pins. A rolled-forward clock therefore buys camp addresses, not the city map.

### Solution

Change the **pure rule** in `LocationEmbargo` so it is tier-aware, rather than forking a
second predicate per surface. Every existing call site that already evaluates `.camp`
(camp address text, distance strings, single-camp pin, favourites camp pins, watch
surfaces) inherits the relaxed behaviour with no edit, and every `.art` call site is
untouched. API shape is unchanged — `canShowLocations(tier:now:passcodeUnlocked:inRegion:)`
still takes all four inputs; `inRegion` is simply ignored for `.camp`.

## Technical Details

### `Packages/PlayaDB/Sources/PlayaDB/LocationEmbargo.swift`

New explicit predicate for which half of the rule a tier needs:

```swift
/// Does this tier need a Burning Man GPS fix on top of its date?
///
/// `.art` does: full placement is the data the strict rule exists to
/// protect, and a user-settable clock is not evidence on its own.
/// `.camp` does not: the week-early camp-address release is meant to be
/// usable while planning from home (see the type doc).
/// `.unrestricted` has no date to pair a region with.
public func requiresRegion(for tier: EmbargoTier) -> Bool {
    switch tier {
    case .art: return true
    case .camp, .unrestricted: return false
    }
}
```

and the verdict itself:

```swift
public func canShowLocations(
    tier: EmbargoTier,
    now: Date,
    passcodeUnlocked: Bool,
    inRegion: Bool
) -> Bool {
    guard let unlock = unlockDate(for: tier) else { return true }
    if passcodeUnlocked { return true }
    guard now >= unlock else { return false }
    return inRegion || !requiresRegion(for: tier)
}
```

Note what did **not** change: `unlockDate(for:)` still returns
`min(campLocationUnlock, artLocationUnlock)` for `.camp`, so a year whose plist omits
`CampLocationUnlock` still has its camp tier fall back to gates-open — it is then a
date-only unlock *at gates*, which is no earlier than the old behaviour reached anyway.
The type doc now states both rules and the reasoning for each half.

### `iBurn/EmbargoService.swift`

Doc comment only — the verdict methods already forward to the shared rule. Rewrote the
header block to state the two rules separately (art keeps the full clock-spoofing
rationale; camp records the 2026-08-22 relaxation and why), and updated the `MapEmbargo`
doc so "waits for gates" reads "waits for gates *and* a playa GPS fix".

### `iBurn/BRCEmbargo.h` / `iBurn/BRCEmbargo.m`

Façade only, no logic. The `.m` comment asserting

> A date alone never unlocks anything

was the stalest statement of the old policy in the codebase; it now reads as the two-rule
form, scoped to the art tier. The header doc for `+canShowCampLocations` says date-only,
`+canShowArtLocations` says gates **and** region.

### `iBurnWatch/WatchEmbargo.swift`

Verified: the watch has **no logic of its own** — `canShowLocations(tier:now:)` sources the
three inputs (`isUnlockedFromPhone`, `hasSeenBurningManRegion`, `now`) and hands them to
the shared `LocationEmbargo`, failing closed to `tier == .unrestricted` when
`YearSettings.plist` can't be read. So the watch picked up the relaxed camp tier for free;
only its doc comment needed the two-rule rewrite (plus a note on `noteLocationFix` that the
latch it writes is the art tier's half).

## Tests

### `Packages/PlayaDB/Tests/PlayaDBTests/LocationEmbargoTests.swift`

- `testDateAloneNeverUnlocksWithoutTheRegion` → `testDateAloneNeverUnlocksArtWithoutTheRegion`
  (art only; the loop over `campUnlock`, `artUnlock`, mid-event and 2030 is kept).
- New `testDateAloneUnlocksCampsOffPlayaFromTheCampDate` — the mirror: camps visible
  off-playa at every one of those instants, and still locked one second before
  `campUnlock` and at 2026-08-10.
- New `testOnlyTheArtTierRequiresTheRegion` — pins `requiresRegion(for:)` directly.
- `testCanShowLocationForObjectFollowsTheObjectsTier` — the off-playa tail now expects
  camp **visible**, art hidden.
- `testRegionFixDrivesTheInRegionHalf` — the Reno case now asserts art hidden and camps
  visible.
- `testRegionAloneNeverUnlocksBeforeTheDates` unchanged (neither tier opens in July).

Result: `swift test --package-path Packages/PlayaDB --filter LocationEmbargoTests`
→ **35 passed, 0 failed**.

(The full `swift test` run for the package aborts in another agent's in-progress
`ZZScratchRepro`/`TaskCancellationTransactionTests` GRDB scratch case — unrelated to this
change, which is why the run was filtered.)

### `iBurnTests/EmbargoStrictUnlockTests.swift`

- `testDateAloneNeverUnlocksAnyTier` → `testDateAloneUnlocksTheCampTierOnly`: before either
  date nothing; at `insideCampWindow` and `afterGatesOpen`, camps yes, art no,
  `allowEmbargoedData()` no.
- New `testDateAloneDoesNotUnlockBulkCampPlacement` — the guard rail for the policy:
  inside the camp window `MapEmbargo.allowsSingleCampLocation()` is true while
  `allowsBulkCampPlacement()` and `allowsArtLocation()` are false, and both stay false
  after gates open with no region latch.
- New `testCampTierIgnoresTheRegion` — same verdict with and without the latch.
- `testTruthTableOfThePureRule` — the "no passcode, not in region: never" row became
  `XCTAssertEqual(..., tier == .camp && now >= campOpen)`, plus explicit off-playa rows.
- Unchanged and still passing: region+camp-date, region+gates, passcode-alone,
  the latch round-trip, and the "asking doesn't latch the passcode flag" regression.

### `iBurnTests/NearbyEmbargoGatingTests.swift`

Assertions unchanged (they were already tier-shaped). It was the only embargo suite that
never set `UserDefaults.enteredBurningManRegion`, so its art-tier cases were passing on
state leaked from `EmbargoTierTests` running earlier in the alphabet. Added the same
explicit `setUp`/`tearDown` region latch `EmbargoTierTests` uses, so the suite is
deterministic in isolation.

`iBurnTests/EmbargoTierTests.swift` needed no change — it already runs with
`enteredBurningManRegion = true` (it is about *which date* opens a tier, not which inputs),
and every one of its expectations is unchanged under the relaxed rule.

## Docs updated

- `.claude/skills/drive-app/references/flows.md` §6 (Map + embargo): the "the rule is
  strict — a date alone never unlocks anything" block now states both tier rules, spells
  out that camp addresses need no GPS while bulk placement does, and corrects the driving
  guidance ("a sim off the playa with a post-camp-date clock showing camp addresses but an
  empty map is the correct behaviour"). The nearby-card section's "the mock date no longer
  lifts the embargo on its own" note is now scoped to the art tier.

## Expected Outcomes

- From 2026-08-23 00:01 PDT, any device — at home, in Reno, anywhere — shows theme camp
  addresses and distances in lists, search, detail and Nearby, and the single camp pin on a
  camp's detail map. No GPS fix, no passcode.
- Art placement, and every bulk camp placement surface, is unchanged: still passcode, or
  gates-open **and** a fix inside the Burning Man region.
- The watch follows the phone automatically (shared rule, no watch-side logic).
- A rolled-forward device clock now buys camp address text and nothing else — no art, no
  camp pins on the browse map, no boundaries or labels.

---

# Date-rollover refresh (same day, follow-up)

## Problem

Making the camp tier date-only introduced a delivery problem the strict rule had hidden:
`.BRCEmbargoDidClear` was posted from exactly two places, both of them *events* —
`BRCAppDelegate -enteredBurningManRegion` and `EmbargoPasscodeViewModel`. Nothing posted it
when a tier's **date** arrived. While every tier needed a GPS fix that was harmless (the
fix was always the last thing to happen); now the clock alone unlocks camps at
`YearSettings.campLocationUnlock` (2026-08-23 00:01 PDT), and iOS keeps apps suspended for
days. An app that was alive or suspended across midnight would keep saying "Location
Restricted" until the user killed and relaunched it.

Every live surface refreshes off that notification: `PlayaDBAnnotationDataSource`,
`UserMapViewAdapter`, `BaseMapViewController`, `NearbyViewModel`, `NearbyCardViewModel`,
the six SwiftUI list hosting controllers, and the watch bridge in
`DependencyContainer` (line ~174). One correct post fixes all of them.

## Solution

New `iBurn/EmbargoUnlockScheduler.swift`:

- `EmbargoUnlockState` — `{ canShowCampLocations, canShowArtLocations }`, plus
  `didUnlock(comparedTo:)`, which is true **only** for the locked → unlocked direction.
  Nothing in the app re-locks, and a spurious post reloads every map data source and list,
  so the transition is spelled out rather than a plain `!=`.
- `EmbargoUnlockScheduling` protocol / `EmbargoUnlockSchedulerImpl` /
  `EmbargoUnlockSchedulerFactory.makeScheduler()`, per the repo's protocolize-and-inject
  guidance. `DependencyContainer` takes it as an init parameter (defaulted) and calls
  `start()` alongside its other app-wide listeners.
- Triggers, deliberately overlapping (a missed unlock is user-visible, a redundant check is
  free):
  1. `start()` at launch — records the baseline, posts nothing (every surface is about to
     read the live state anyway).
  2. `UIApplication.didBecomeActiveNotification` and
     `UIApplication.significantTimeChangeNotification` — the latter is what iOS sends at
     day rollover and on any clock/timezone edit. This pair covers the
     suspended-across-midnight case, which is the common one.
  3. One non-repeating `Timer` armed for the next unlock instant still in the future
     (`campLocationUnlock` or `eventStart`), fired one second past it so the `now >= unlock`
     comparison holds. Re-armed after every evaluation, so the second tier gets a timer once
     the first has passed; invalidated first, so only one is ever live. Skipped when nothing
     is pending or the interval exceeds `maximumScheduledInterval` (400 days — a device with
     a wildly wrong clock shouldn't hold an absurd fire date; the foreground triggers pick it
     up later). Tolerance `min(max(5%, 1s), 60s)`.
- The clock is `Date.present`, the same source `EmbargoService` uses, so the
  **iBurn (Mock Date)** scheme moves the scheduler too.

## Watch

`iBurnWatch` caches no embargo verdict — every `WatchEmbargo` accessor is computed live —
but `NearbyScreen` and `FavoritesScreen` hold their rows in `@State` and only recompute
when something tells them to. Added `WatchEmbargo.refreshUnlockState()`: one snapshot of
the two tiers, compared and posting the existing `.embargoDidUnlock` on a locked → unlocked
transition. `iBurnWatchApp` calls it on every `.active` scene phase — a watch app is woken
far more often than launched, and watchOS suspends between glances, so a timer would rarely
be the thing that fires. `NearbyScreen` now also re-runs its query on `.embargoDidUnlock`
(it fetches per tier, so a re-render alone would not repopulate it); `FavoritesScreen`
already listened.

## Tests

`iBurnTests/EmbargoUnlockSchedulerTests.swift` (17 cases). Everything is injected — `now`
is a variable the test moves, the post is a counter, the timer is a `FakeTimer` the test
fires by hand, and the notification center is private to the test — so nothing sleeps.
Covers: camp date arriving posts once; repeated refreshes stay silent; starting past an
unlock posts nothing; each tier posts as it opens; a backwards clock re-locks without
posting and re-posts on the way forward; passcode state is already-unlocked at start; the
`didUnlock` direction rule; timer armed for the next instant only, re-armed on fire and on
foreground, none when everything has passed or the interval is absurd; `stop()` invalidates
and unregisters; `didBecomeActive` / `significantTimeChange` posting; and that the default
`stateProvider` (`liveState(at:)`) agrees with `EmbargoService`.

## Files

- `iBurn/EmbargoUnlockScheduler.swift` (new)
- `iBurn/DependencyContainer.swift` (owns + starts it, injectable)
- `iBurnWatch/WatchEmbargo.swift`, `iBurnWatch/iBurnWatchApp.swift`,
  `iBurnWatch/NearbyScreen.swift`
- `iBurnTests/EmbargoUnlockSchedulerTests.swift` (new)
- `.claude/skills/drive-app/references/flows.md` §6 and §8a
- `Docs/2026-08-16-camp-boundary-embargo-tier.md` (known gap marked resolved)

## Verification

- `xcodebuild -scheme iBurn` (iPhone 17 Pro Max, iOS 26.5): success, 0 warnings.
- `xcodebuild -scheme iBurnWatch` (Apple Watch Series 11 46mm): success, 0 warnings.
- `xcodebuild test -scheme iBurnTests -only-testing:` EmbargoUnlockSchedulerTests,
  EmbargoStrictUnlockTests, EmbargoTierTests, NearbyEmbargoGatingTests: **104 passed, 0
  failures**.

## Expected outcome

At 2026-08-23 00:01 PDT an app that is running, or that iOS resumes any time after, posts
`.BRCEmbargoDidClear` once and every camp address, camp distance and single camp pin
appears — no relaunch. Foregrounding repeatedly after that posts nothing further. Art is
untouched: still passcode, or gates-open plus a Burning Man fix.
