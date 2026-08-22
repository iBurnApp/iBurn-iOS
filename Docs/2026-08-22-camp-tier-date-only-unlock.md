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
