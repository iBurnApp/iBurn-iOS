# 2026 Art Audio Tour Integration

## High-Level Plan

**Problem:** BMorg published the 2026 Art Discovery Audio Guide on 2026-08-18/20. The app ships
the audio tour as media files in the `iBurn-Data` submodule; without them the Audio Tour list is
empty (or falls back to the intro only).

**Solution:** Drop the UID-named AAC tracks (plus a converted intro) into
`Submodules/iBurn-Data/data/2026/MediaFiles/MediaFiles.bundle/`, commit them in the submodule, and
bump the parent-repo pointer. **No app code changes required** — the pickup path is purely
filename-based.

**Key changes:**
- 87 `.m4a` files added to the 2026 media bundle (86 `<art-uid>.m4a` + `intro.m4a`).
- Submodule pointer bumped in the parent repo.
- PlayaDB seed zips regenerated locally (gitignored, not committed).

## Source

- Dataset page: https://innovate.burningman.org/dataset/2026-art-discovery-audio-guide/
  (released 2026-08-18/20)
- UID-named AAC zip: https://bm-innovate.s3.amazonaws.com/2026/2026-audio-tour-art-uid-aac.zip
- The titled (human-readable filename) zip from the same dataset page was used only to source the
  introduction track.

## How the app picks up audio (no code changes)

Filename is the entire contract:

1. `<uid>.m4a` files inside `Submodules/iBurn-Data/data/2026/MediaFiles/MediaFiles.bundle/` ship
   via the `iBurn2026MediaFiles` SwiftPM target.
2. `BRCMediaDownloader` copies the bundle's contents to `Documents/MediaFiles` on launch.
3. `iBurn/ListView/AudioTourViewModel.swift` unions the locally present `.m4a` uids to build the
   tour list.
4. The intro track uses the reserved uid `intro`, matched by
   `+[BRCArtObject introObject]` in `iBurn/BRCArtObject.m` — verified this year's synthetic
   record has `@"year": @(2026)` (already correct, no edit needed).

2025 precedent: iBurn-Data commit `7f5a3be` "add audio tour".

## Verification performed

**UID match (86/86):** every non-intro filename stem was checked against the `uid` field of
`data/2026/APIData/APIData.bundle/art.json`:

```
m4a total: 87 intro present: True
matched: 86 unmatched: []
```

**No overwrites:** the bundle contained only `.jpg` files before the copy (1610 files, 1610 jpg).
A per-file collision check found none, and `cp -n` was used as a second guard.

| | Before | After |
|---|---|---|
| Files in `MediaFiles.bundle/` | 1610 (all `.jpg`) | 1697 |
| `.m4a` files | 0 | 87 |

**Intro conversion:** BMorg ships track "0. Introduction" as MP3 only. Converted to AAC/m4a with
`afconvert` (200 s duration) and named `intro.m4a` to match the reserved uid.

**Intentional exclusion:** track "87. The Theme … by Stewart Mangrum" exists in BMorg's titled zip
but has **no art uid**, so it cannot be attached to an art object. Past years did not ship it
either — excluded deliberately.

## Seed rebuild

```
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

Result: success.

```
art 334 · camps 1187 · events 5300 · mutant vehicles 494
thumbnail colours: 1580
archives: 2 × 3048 KB
  iBurn/PlayaDB-2026.zip
  iBurnWatch/PlayaDB-2026.zip
```

Pre-existing, unrelated warning (thumbnail, not audio — the tool then reports the bundle has every
referenced thumbnail, so it is emitted by the pre-fetch check):

```
warning: 1 object(s) reference a thumbnail that is not in the media bundle; re-run with
--fetch-media. First few: a1XVI00000FN9rZ2AT
```

The seed zips are gitignored; they were regenerated only so local dev bundles stay consistent.

## Build validation

```
DEST='platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination "$DEST" 2>&1 | xcsift -f toon -w
```

```
status: success
errors: 0 · warnings: 0 · failed_tests: 0 · linker_errors: 0
```

No `DEVELOPMENT_TEAM` flip in the pbxproj; `git status` showed only the submodule pointer.

## Commits

- `Submodules/iBurn-Data` @ `6dff0e8` — "Add 2026 audio tour (86 tracks + intro)"
  (parent was `7979d35`, branch `2026-updates`)
- `iBurn-iOS` — "Bump iBurn-Data: 2026 art audio tour (86 tracks + intro)" (submodule pointer +
  this document)

Nothing was pushed.

## Release checklist

`Docs/RELEASE_CHECKLIST.md` line 154 — "Media/thumbnails downloaded for new records; audio tour
present if released." — the audio-tour half is now satisfied for 2026.

## Cross-References

- `Docs/2026-08-17-api-refresh-and-release-prep.md` — the API data refresh this audio drop sits on
  top of.
- `Docs/2026-08-11-release-prep-2026.md` — broader 2026 release prep.

## Expected Outcomes

On a fresh launch the Audio Tour list should show the intro plus 86 art tracks, each attached to
its art object via uid, playable offline from `Documents/MediaFiles`.

## Follow-up (same day): the "missing thumbnail" seed warning

`playa-seed` warned: `1 object(s) reference a thumbnail that is not in the media bundle … a1XVI00000FN9rZ2AT`.

**Root cause:** that uid is the camp "Fantastica Music Healing Camp", whose
`images[0].thumbnail_url` is the literal string `"processing"` — bmorg's image pipeline
never produced the thumbnail. Verified live against `api.burningman.org/api/camp?year=2026`
(still `"processing"`, the only such record). There is no image to download.

**Fix:** decode non-web `thumbnail_url` values as `nil` instead of a schemeless relative
`URL`, reusing the existing `LenientURL` salvage helper:

- `Packages/PlayaAPI/Sources/PlayaAPI/Models/Shared/Image.swift` — custom `init(from:)` on
  `ArtImage` / `CampImage` using `decodeLenientURLIfPresent(forKey: .thumbnailUrl)`.
- `Packages/PlayaAPI/Sources/PlayaAPI/Models/MutantVehicle.swift` — same for
  `MutantVehicleImage`.
- `Packages/PlayaAPI/Tests/PlayaAPITests/LenientURLTests.swift` — 3 new tests
  (`processing` → nil for camp/art/MV; a real widencdn URL still decodes).

**Validation:** PlayaAPI `swift test` 74/74 pass; `playa-seed --fetch-media` rebuilt both
zips with the warning gone (1580 colours, no missing-thumbnail message); `iBurn` scheme
builds clean. `RELEASE_CHECKLIST.md` media/audio checkbox now ticked with a note.

## Follow-up (same day): fresh API fetch — event uid dedup

BMorg fixed API bugs causing event ID issues, so we re-fetched:

```bash
node src/cli/fetch_and_geocode.js -y 2026 -l ../../data/2026/layouts/layout.json \
  -o ../../data/2026/APIData/APIData.bundle
```

**Verified:** event uids now unique — 2884 events / 2884 unique uids (previous snapshot had
6 duplicate uids that `playa-seed` skipped on import; the skip message is gone). Counts:
art 332 (−2), camps 1185 (−2), mv 492 (−2), event occurrences 5791 (+491 vs the Aug 17 seed).
No uid dupes in art/camp/mv; no null-island camps/mv. The 20 null-island art rows (incl.
"deputy test"/"WG Test" upstream test entries) are unchanged from the Aug 17 snapshot —
still an open checklist item, display-clamped in the app.

**Validation:** seed rebuilt clean (1574 thumbnail colours, both zips 3124 KB, no warnings),
PlayaAPI tests 74/74, `iBurn` scheme builds clean, no pbxproj team flip.

**Commits:** iBurn-Data `7295d21` "2026 API refresh (Aug 19): upstream event-uid dedup fix";
parent repo submodule pointer bump.
