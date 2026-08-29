# App Store Metadata — Review Notes (2026.0, build 109)

Drafted 2026-08-11. **Nothing here is uploaded automatically.** The `beta` lane in
`fastlane/Fastfile` only runs `build_app` → `upload_to_testflight` → `upload_symbols_to_crashlytics`;
there is no `deliver` / `upload_to_app_store` step, so these files are drafts for copy-paste into
App Store Connect (or for a future `deliver` lane to pick up).

## Files

| File | Length | Limit |
|---|---|---|
| `en-US/release_notes.txt` | 991 chars / 178 words | 4000 |
| `en-US/description.txt` | 2085 chars / 366 words | 4000 |
| `en-US/keywords.txt` | 93 chars (excluding trailing newline) | 100 |

`en-US/` is the standard `deliver` layout. If a `deliver` lane is added later, note that it expects
the release-notes file to be named `release_notes.txt` (as here) and reads keywords with the
trailing newline stripped.

## What changed vs. prior metadata

There was no metadata checked into this repo before — prior years' copy lived only in App Store
Connect. So this is a **new baseline**, written from the marketing site
(`iburnapp.github.io/index.html`), `README.md`, and the 2026 feature set. Diff it against whatever
is live in App Store Connect today before replacing anything.

Substantive shifts from the historical positioning:

- **Apple Watch is now a headline feature.** It is new this year and deserves a section in the
  description, not just a release note. It also changes the App Store listing itself — see manual
  steps below.
- **"Walk and bike times"** replaces distance language throughout (the app no longer shows raw
  distances).
- **Per-occurrence event favorites**, **customizable tab bar**, **rebuilt search**, **Right Now**,
  and **drop-a-pin** are all new-in-2026 and are called out in both files.
- **Embargo framing softened.** Older copy (and the README) says locations are embargoed "until the
  gates open." That is no longer accurate: 2026 uses two tiers — camps unlock on their own at
  `CampLocationUnlock`, art at `EventStart`. The description says "camp locations first, then art
  when gates open" without naming dates, so the copy doesn't go stale mid-season. The release notes
  say the same thing without dates.
- **Privacy paragraph added.** Worth having next to the App Store privacy label.
- No specific event dates, no year-stamped claims beyond "2026", and no mention of the unlock
  passcode anywhere — deliberate, so the listing doesn't need editing during the event and doesn't
  advertise the existence of a bypass.

## Still needs manual entry / decisions in App Store Connect

1. **Screenshots.** Not generated here. Must be captured in the **embargo-locked state** — no real
   camp coordinates, no camp boundary outlines, no addresses on camp/art detail views. Also need
   fresh sizes for the current iPhone lineup, and a **separate Apple Watch screenshot set**, which
   this listing has never had.
2. **Apple Watch listing fields.** First year with a watch app: the App Store product page gains a
   watch section that needs its own screenshots, and the watch app's own name/subtitle come from the
   watch target's Info.plist — confirm they read the way you want.
3. **Subtitle (30 chars) and promotional text (170 chars)** — not drafted here, both are
   App Store Connect-only fields. Promotional text is editable without a new build, so it's the
   right place for anything time-sensitive (e.g. "camp locations now unlocked").
4. **App Review notes.** Add a note explaining that camp and art locations are embargoed by the
   event organizer and unlock on fixed dates — otherwise a reviewer sees a map with no camps and may
   read it as broken or incomplete. Mention the app is fully functional offline by design.
5. **What's New localization.** Only `en-US` is drafted. If other locales are live in App Store
   Connect, they'll need their own copy or will fall back.
6. **Age rating and privacy nutrition label** — re-confirm; the watch app adds a target but should
   not change the data collected.
7. **Release strategy** — manual vs. automatic vs. phased release, relative to gates opening
   2026-08-30. A phased rollout is a poor fit for an event app where everyone installs the same
   week; manual release timed just before gates is usually the right call.
8. **Marketing/support URLs** — verify `iburnapp.com` links are current.

## Cross-references

- `Docs/RELEASE_CHECKLIST.md` — sections 4 (Embargo) and 9 (App Store) gate this work.
- `Docs/2026-08-06-placement-data-embargo-and-passcode.md` — two-tier unlock behavior described in
  the copy.
