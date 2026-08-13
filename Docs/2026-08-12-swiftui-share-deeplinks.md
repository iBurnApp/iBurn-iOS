# SwiftUI share sheet emits real iburnapp.com deep links

*Date: August 12, 2026*

## High-Level Plan

**Problem.** The SwiftUI detail screen's share button did not produce the `iburnapp.com`
universal links added in 2025. For PlayaDB-backed subjects it handed the share sheet a plain
string (`"Art: Temple of Direction\nID: a2Id…"`), so a shared item could not open the app,
had no web preview, and never touched the deep link format at all. Only the legacy
YapDB-backed path (`.legacy`) reached the QR/share screen and `generateShareURL()`.

**Root cause.** `iBurn/Detail/ViewModels/DetailViewModel.swift:675-690` (`shareObject()`)
switched on `DetailSubject` and, for every PlayaDB case, called
`coordinator.handle(.share([... text ...]))`. `BRCDataObject.generateShareURL()` — the only URL
generator — lived in `BRCDeepLinkRouter.swift` as an extension on the *legacy* Yap class, so it
was unreachable from `ArtObject` / `CampObject` / `EventObject` / `EventObjectOccurrence`.

**Fix.** Extracted the URL construction into a single reusable seam, `ShareURLBuilder`, and
routed both the legacy and the SwiftUI paths through it. The SwiftUI path now presents the same
QR/share screen the legacy path uses, with a pre-built, embargo-filtered URL.

## Files Changed

- **`iBurn/ShareURLBuilder.swift` (new)** — `ShareURLKind` (art/camp/event/pin, mirrors
  `DeepLinkObjectType`), `ShareURLHost`, `ShareURLPayload`, `protocol ShareURLBuilder` +
  `ShareURLBuilderImpl` + `ShareURLBuilderFactory`. Payload factories for `ArtObject`,
  `CampObject`, `EventObject`, `EventObjectOccurrence` and legacy `BRCDataObject`, each taking an
  explicit `canShowLocation: Bool` so the embargo rule is injected (and testable) rather than read
  implicitly. Emitted format is byte-compatible with what shipped in 2025: `/art/`, `/camp/`,
  `/event/` (trailing slash), `/pin`; params in order `uid, title, lat, lng, addr, desc,
  start, end, host, host_id, host_type, all_day, year`; coordinates `%.6f`; `desc` truncated to
  100 chars; dates in the compact `20260831T14:00:00` form that
  `iburnapp.github.io/assets/js/deeplink-handler.js:178-192` special-cases.
- **`iBurn/BRCDeepLinkRouter.swift`** — `BRCDataObject.generateShareURL()` and
  `BRCMapPoint.generateShareURL()` reduced to payload construction + one builder call. The legacy
  method still resolves the host camp/art name asynchronously through PlayaDB.
- **`iBurn/Detail/ViewModels/DetailViewModel.swift`** — `shareObject()` now builds a real deep
  link for art/camp/event/occurrence and presents the QR/share screen; mutant vehicles keep the
  text share (no `mutantvehicle` deep link type exists on the website). Added
  `shareURLPayload()` and `resolvedShareHost(for:)`.
- **`iBurn/Detail/Models/DetailCellType.swift`** — new
  `DetailAction.showShareURLScreen(title:locationText:url:themeColors:)`.
- **`iBurn/Detail/Services/DetailActionCoordinator.swift`** — handles the new action.
- **`iBurn/ShareQRCodeView.swift`** — new `init(title:locationText:shareURL:themeColors:)` plus a
  matching hosting-controller init. The "Custom Map Pin" subtitle is now an explicit
  `emptyLocationPlaceholder` (map-pin init only) instead of being inferred from `locationText == nil`,
  which would otherwise have mislabeled embargoed objects.
- **`iBurnTests/ShareURLBuilderTests.swift` (new)** — 12 tests.

## Embargo Handling

Share URLs carry placement (`lat`, `lng`, `addr`) only when the object's embargo tier is
unlocked. The gate is applied when the payload is built, per tier:

- art → `BRCEmbargo.canShowArtLocations()`
- camp → `BRCEmbargo.canShowCampLocations()`
- event / occurrence → `BRCEmbargo.canShowLocation(for:)` (art-hosted events ride the art tier)
- legacy objects → `BRCEmbargo.canShowLocation(for:)`, unchanged

`uid`, `title`, `desc`, `start`/`end` and `host_id`/`host_type` are not placement and are always
included. An embargoed event's *host identity* is shared but not its address. Events have no GPS
of their own in PlayaDB, so an occurrence falls back to its host camp/art coordinate — also
behind the same gate.

## Test Results

`xcodebuild test -scheme iBurnTests` — 549 passed, 0 failed. New tests:
`testArtShareURLUnlocked`, `testArtShareURLOmitsLocationWhenEmbargoed`,
`testCampShareURLUnlocked`, `testCampShareURLOmitsLocationWhenEmbargoed`,
`testEventShareURLWithCampHost`, `testEventShareURLWithArtHost`,
`testEventShareURLOmitsLocationWhenEmbargoed`, `testEventObjectShareURLWithoutOccurrenceOmitsDates`,
`testPinShareURL`, `testShareURLsRoundTripThroughRouter`, `testDescriptionIsTruncated`,
`testMissingUIDProducesNoURL`.

`testShareURLsRoundTripThroughRouter` feeds each generated URL back through
`BRCDeepLinkRouter.canHandleURL(_:)` and asserts the type path component and `uid` the router
requires are present.

## Cross-References

- `Docs/2025-08-07-deep-linking-ios.md`, `Docs/2025-08-08-deeplink-implementation.md`
- `Docs/2025-08-09-deeplink-url-format-fix.md` (URL format the router parses)

---

# Same-day: watch app embargo gating (ship blocker found and fixed)

**Problem.** The Aug 12 watch screenshot/audit pass found the watch app had *no* embargo
gating: `BRCEmbargo` is iOS-only Obj-C, never linked into iBurnWatch. On a fresh locked
install the watch showed camp/art distances in every list, a metre-precision Nearby ranking,
and a Navigate screen plotting any camp with live distance+bearing. The detail screen's
"Location hidden until gates open" only appeared for the ~7 camps with no GPS — a
data-presence check masquerading as a gate.

**Fix (`375e0399`).** New pure `LocationEmbargo` seam in `Packages/PlayaDB` (the one package
both targets link): two-tier date-driven unlock (`EmbargoSchedule.load` from
`YearSettings.plist`, now a shared watch resource; missing `CampLocationUnlock` falls back to
the stricter art date; camp unlock clamped to `min(camp, art)`). `iBurnWatch/WatchEmbargo.swift`
is the watch glue — `distance(for:from:)` is the single funnel for every distance label,
computed from `Date()` each call, failing closed if the plist can't load. Gated surfaces:
ObjectListScreen row distances, NearbyScreen (locked tiers never fetched), DetailScreen
Navigate, FavoritesScreen distance + sort (alphabetical while locked). Phone passcode unlock
latches to the watch via a publish-true-only `embargoUnlockedV1` key in `PeerSyncManager`'s
application context, pushed on `.BRCEmbargoDidClear`; absence never re-locks.

**Verification.** 20 new `LocationEmbargoTests` (boundary instants, tier riding, plist
fallbacks, live parse of the shipped plist); iBurnTests 549 green, PlayaDB 311 green; erased
Ultra 3 sim fresh install shows no distances/Navigate/Nearby rows, and a positive control
(setting the phone-unlock latch) restores them — proving the gate is date-driven, not
accidentally fail-closed. Evidence in `fastlane/screenshots/watch/_embargo-leak-evidence/`.

**Also today:** five locked-state watch App Store screenshots (410×502) in
`fastlane/screenshots/watch/en-US/` (422×514 natives kept alongside); watch seed restore
verified on-sim (331/1190/2587/5240); checklist §5 rewritten — OTA updates are not a 2026
feature (`a3587b00`); checklist §4 gained watch-audit and share-URL line items.

# Same-day: iOS adopts the strict embargo rule (policy change for 2026.0)

**Problem.** The watch shipped the strict rule earlier today; the phone was still on the old
date-only one. `BRCEmbargo.allowEmbargoedData` returned YES the moment `Date.present` passed
`EventStart` — and wrote the passcode flag while doing it — so dragging Settings ▸ Date &
Time forward for one minute published every camp and art coordinate for the rest of the
season, permanently, on any device anywhere. `canShowCampLocations` had the same shape for
the camp tier (date-only, no latch). The device clock is user input, not evidence.

**Policy (user-decided).** One rule on both platforms:

```
passcodeUnlocked || (inRegion && now >= unlockDate(tier))
```

The accepted cost is explicit: off-playa users stay locked past the unlock dates unless they
enter the BMorg passcode. "We will keep it strict and release an app update that relaxes it";
a 2027 server-side design covers no-GPS auto-unlock.

**Implementation.** No new rule — the phone adopts the seam the watch already uses.

- `iBurn/EmbargoService.swift` (new, `@objc(BRCEmbargoService)`): builds
  `PlayaDB.LocationEmbargo` from `YearSettings.campLocationUnlock` / `.eventStart`, sources
  `passcodeUnlocked` from the existing defaults flag and `inRegion` from the region latch,
  evaluates the date live against `Date.present`. Also exposes the pure
  `canShowLocations(tier:now:passcodeUnlocked:inRegion:)` as the test seam, plus
  `noteEnteredBurningManRegion()` / `noteLocationFix(_:)`.
- `iBurn/BRCEmbargo.m`: kept as the Obj-C façade (dozens of call sites unchanged), now three
  one-line forwards. The date-only branches and the self-latching passcode write are gone;
  `canShowLocationForObject:` keeps its tier mapping (art → art, art-hosted events → art,
  everything else → camp) unchanged.
- Region latch persisted: `kBRCEntered2026BurningManRegionKey` in `NSUserDefaults+iBurn`
  (year-stamped like the passcode key, so next season re-arms), surfaced as
  `UserDefaults.enteredBurningManRegion`. `EmbargoService.hasSeenBurningManRegion` ORs it with
  the in-memory `BRCLocations.hasEnteredBurningManRegion`, which other features
  (`EventListViewModel`, `RegionStatusService`, `BRCDatabaseManager`) still read as before.
  Persisting a *visit* is safe in a way persisting a date check is not — no clock change can
  manufacture a past trip to Black Rock City.
- `BRCAppDelegate -enteredBurningManRegion` latches, then posts `.BRCEmbargoDidClear` only
  when a tier's verdict actually flipped, and shows the "Data Unlocked" alert only on the
  first latch that unlocks something. Region entry is now the live unlock trigger.
- `DependencyContainer.embargoUnlockedProvider` publishes the phone's *full* verdict
  (`BRCEmbargo.allowEmbargoedData()`) rather than the bare passcode flag. The watch treats
  that latch as `passcodeUnlocked` and skips its own region check — correct: a phone that
  legitimately unlocked, either way, should unlock the watch on the wrist next to it.
- Copy: the passcode screen and the "Locations Are Hidden" alert no longer promise a date
  unlock ("the app unlocks itself once you're on playa and those dates have passed …
  until you arrive, locations stay hidden unless you enter the passcode"), and the countdown
  no longer claims "Location Data Unlocked!" once gates open on a still-locked device — it
  says gates are open and locations unlock on arrival.

**Verification.** New `iBurnTests/EmbargoStrictUnlockTests.swift` (12 cases): date-alone
never unlocks any tier at any instant; asking past gates-open writes neither defaults flag
(the regression that mattered); region+camp-date opens camps only; region+gates opens
everything; passcode alone unlocks with no visit; the latch survives a defaults round-trip
with the in-memory flag cleared; fixes outside the region don't latch; and a full truth table
of the pure rule. `EmbargoTierTests` now runs as a device that has been to BRC (its subject
is which date opens which tier), which is the only change it needed. iBurn build clean,
iBurnTests 561 green, iBurnWatch build clean, PlayaDB 324 green. Sim sanity on an erased
iPhone 17 Pro Max at the real date: locked with no fix; a BRC fix latches
`kBRCEntered2026BurningManRegionKey` and the app *stays* locked, because Aug 12 is before
`CampLocationUnlock` — which is the pass condition.

**Call sites whose behaviour changes:** everything gated on `BRCEmbargo` — list rows and
addresses, nearby surfaces, map annotations and camp boundary layers, detail views, share
URLs, calendar entries — now stays locked for remote users past `CampLocationUnlock` and
`EventStart`. Previously those surfaces lit up for everyone on the calendar date. App Review
consequently always sees a locked map; review notes must carry unlock instructions and the
passcode (private ASC field only).
