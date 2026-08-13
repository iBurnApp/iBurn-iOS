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
