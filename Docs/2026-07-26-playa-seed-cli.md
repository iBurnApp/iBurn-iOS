# 2026-07-26 — `playa-seed`: automated pre-baked PlayaDB seed with precomputed colors

Continues the same day's release prep; see also
[2026-07-26-archive-cycle-and-onboarding-video.md](2026-07-26-archive-cycle-and-onboarding-video.md).

## High-Level Plan

**Problem.** `iBurn/PlayaDB-<year>.zip` ships a pre-populated database so a fresh install
doesn't sit through a JSON import. It was produced **by hand** — run the app in the
simulator, wait, pull `PlayaDB.sqlite` out of the container, zip it. That is slow,
unrepeatable, and easy to forget. Worse, the zip in the tree had
`thumbnail_colors` **empty** (0 rows), so every new user still paid for on-device colour
extraction across ~1,570 thumbnails on first launch.

**Solution.** A macOS Swift CLI, `playa-seed`, that builds the seed offline:

```bash
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

It imports the year's API JSON into a fresh PlayaDB, extracts thumbnail colours for every
bundled image, compacts the database, and zips it — in **~2.3 s**.

Two supporting pieces made that possible:

1. **`Packages/PlayaColors`** — a CoreGraphics-only port of the `UIImageColors` CocoaPod,
   usable from macOS. The app now uses it too, so a colour baked at build time is identical
   to one the device would compute.
2. **Media fetching** — `--fetch-media` downloads thumbnails the API references but the
   media bundle lacks, replacing iBurn-Data's `art_image_download.js` (art-only, and
   `http`-only, so it has been unusable since the org moved images to HTTPS).

---

## Why a shared colour module

`UIImageColors` is a CocoaPod compiled into the app target; SwiftPM can't reach it, so the
CLI needed its own implementation. Two copies of a colour algorithm in one codebase drift,
so the port lives in a package **both** consume, and the pod was removed from the `Podfile`.

### Validating the port

The pod's macOS path is not a usable reference: `NSImage.size` is DPI-derived rather than
pixel-derived, so its resize step produces a different bitmap than iOS. A naive end-to-end
comparison across all 1,574 thumbnails showed a median background delta of 0.64 — an
artifact of that resize, not of the scoring.

The scoring logic was instead compared on **identical pixels**: downscale each thumbnail
once, then run the pod's algorithm verbatim against `ImageColorExtractor.extract(_, .highest)`.

| Slot | Agreement |
| --- | --- |
| background | 1553 / 1574 (**98.67 %**) |
| primary | 73.5 % |
| secondary | 52.1 % |
| detail | 33.0 % |

The background number is the meaningful one — the other three are dominated by a quirk in
the pod, described below. Of the 21 background disagreements, all but ~3 are shifts of
≤4/255 (e.g. `177,108,049` vs `173,104,045`), i.e. exact count ties broken differently.

### Three deliberate deviations from the pod

1. **Fixed 1x resize.** `UIImageColors` resizes via
   `UIGraphicsBeginImageContextWithOptions(newSize, false, 0)` — scale `0` means *device*
   scale, so a 3x phone histogrammed 9x as many interpolated pixels as a 1x one and could
   land on a different colour. The port always downscales in pixels, so every platform
   (and the CLI) agrees.

2. **Deterministic ordering.** The pod ranks candidates with an `NSCountedSet`
   `objectEnumerator()` whose order is hash-dependent, and its comparator returns
   `.orderedSame` for equal counts — so tied candidates came out in arbitrary order. The
   port uses a total order: count → source count → saturation → packed RGB.

3. **A meaningful tie-break for the foreground slots.** In the pod's second pass:

   ```swift
   while var K = enumerator.nextObject() as? Double {
       K = K.with(minSaturation: 0.15)
       if K.isDarkColor == findDarkTextColor {
           let C = imageColors.count(for: K)   // K was just reassigned
           sortedColors.add(UIImageColorsCounter(color: K, count: C))
       }
   }
   ```

   `count(for:)` is looked up on the **saturation-boosted** colour. `with(minSaturation:)`
   returns `self` untouched when a colour is already saturated enough, so vivid colours keep
   real counts and rank correctly — but boosted (washed-out) ones almost never occur
   verbatim in the image and all tie at `0`. That is why primary/secondary/detail agreement
   is low: among the zero-count group the pod was effectively picking at random.

   The port keeps the same primary ranking (bug-compatible) but breaks the zero ties by the
   frequency of the colour *before* boosting, then by saturation. The saturation step
   matters: without it a muddy near-grey can beat a vivid colour purely on having a lower
   packed RGB value. It fixed the one visually significant background divergence
   (`a6BVI000000ODgr2AG`: near-black `26,30,29` → tan `226,181,152`).

**Continuity is not a concern this season.** `thumbnail_colors` starts empty for every user
on the 2026 release, so nobody sees a colour change relative to a cached value.

---

## What was built

### `Packages/PlayaColors` (new)

| File | Purpose |
| --- | --- |
| `Sources/PlayaColors/ExtractedColors.swift` | `PlayaRGB`, `ExtractedColors`, `ColorQuality` — platform-free value types |
| `Sources/PlayaColors/ImageColorExtractor.swift` | `extract(from: CGImage, quality:)` — rasterize + histogram + score |
| `Tests/PlayaColorsTests/ImageColorExtractorTests.swift` | 11 tests: background selection, black/white skipping, fallbacks, determinism, aspect ratio |

Rasterization draws into a `premultipliedFirst | byteOrder32Little` sRGB context — the same
B,G,R,A memory order UIKit's bitmap contexts use, which is what the algorithm's
`data[pixel+2] == red` indexing assumes.

### `Packages/PlayaSeed` (new)

| File | Purpose |
| --- | --- |
| `SeedOptions.swift` | Flag parsing; infers the repo root by walking up to `iBurn.xcworkspace` |
| `APIDataFiles.swift` | Reads `art/camp/event/mv/update.json` straight off disk |
| `MediaCatalog.swift` | Indexes `MediaFiles.bundle` by uid |
| `MediaFetcher.swift` | Bounded-concurrency (6) downloader for missing thumbnails |
| `ColorBaker.swift` | Parallel decode + extraction, `ThumbnailColors` rows |
| `SeedBuilder.swift` | Orchestration: fetch → import → bake → compact → archive |
| `Archiver.swift` | `/usr/bin/zip -j -q -X`, so the entry is a bare `PlayaDB.sqlite` |
| `Tests/PlayaSeedTests/` | 19 tests across options, JSON parsing, catalog |

Paths are derived from `--year`, **not** from the year-stamped SwiftPM products
(`iBurn2026APIData` etc.), so 2027 needs a flag rather than a code change.

### PlayaDB additions

```swift
/// Create a PlayaDB backed by a database file at an explicit path…
public func createPlayaDB(atPath path: String) throws -> PlayaDB

/// Compacts the database and folds the write-ahead log back into the main file…
func compactForDistribution() async throws
```

`compactForDistribution` runs `VACUUM` then `PRAGMA wal_checkpoint(TRUNCATE)` so the
`.sqlite` stands alone without its `-wal`/`-shm` sidecars.

### App migration off UIImageColors

New `iBurn/ImageColorExtraction.swift` provides the UIKit adapter:

```swift
extension UIImage {
    func brc_extractColors(quality: ColorQuality = .high) -> BRCImageColors? {
        guard let cgImage else { return nil }
        return ImageColorExtractor.extract(from: cgImage, quality: quality)?.brc_ImageColors
    }
}
```

Call sites updated: `ColorPrefetcher.swift`, `ListView/RowAssetsLoader.swift`,
`ColorCache.swift`, `ArtImageCell.swift`. The pod was dropped from `Podfile` and
`pod install` re-run (LicensePlist regenerated accordingly). `PlayaColors` was wired into
the `iBurn` target in `project.pbxproj` (local package reference + product dependency +
Frameworks phase), mirroring how `PlayaDB` is attached.

---

## Media files

The user asked whether the API import script fetches this year's media. It does not:
`scripts/BlackRockCityPlanner/src/cli/fetch_and_geocode.js` has no image handling, and the
only downloader in iBurn-Data, `src/art_image_download.js`, uses Node's `http` module — it
cannot fetch 2026's `https://burningman.widen.net/...` URLs.

Coverage before this session:

| Type | With `thumbnail_url` | Present in bundle | Missing |
| --- | --- | --- | --- |
| art | 317 | 309 | 8 |
| camp | 762 | 759 | 3 |
| mv | 495 | 495 | 0 |

`--fetch-media` downloaded 10 of the 11. The last one is a data issue, not a fetch failure:
camp `a1XVI00000FN9rZ2AT` ("Fantastica Music Healing Camp") has
`"thumbnail_url": "processing"` — the org's placeholder while an upload converts.
`APIDataFiles` now accepts only `http`/`https` URLs so placeholders are treated as "no
thumbnail" instead of being queued for a download that must fail.

The 10 new `.jpg` files are committed **in the iBurn-Data submodule**.

---

## Results

```
==> Building the 2026 PlayaDB seed
==> Importing 2026 API data…
    Imported 321 art, 1201 camps, 4697 event occurrences, 496 mutant vehicles.
==> Extracting colours for 1574 thumbnail(s)…
    Cached 1573 colour rows.
==> Compacting database…
==> Writing PlayaDB-2026.zip…
==> Done
    art 321 · camps 1201 · events 4697 · mutant vehicles 496
    thumbnail colours: 1573
    archive: 1653 KB
```

2.3 s wall clock. Seed contents vs. the old hand-made zip:

| | old (2026-07-18, manual) | new |
| --- | --- | --- |
| `thumbnail_colors` | **0** | **1573** |
| migrations applied | v1–v4 | v1–v6 (incl. `v5-calendar-entries`, `v6-pin-sync`) |
| `object_metadata` | 0 | 0 (no user data) |
| size | 1655 KB | 1653 KB |

## Verification

- `Packages/PlayaColors`: 11 tests pass.
- `Packages/PlayaSeed`: 19 tests pass.
- `Packages/PlayaDB`: 253 tests pass.
- `iBurnTests`: 202 tests pass.
- App builds clean for the simulator (0 errors, 0 warnings).
- **Fresh-install simulator run** (erased device, full onboarding): after reaching the
  tabs, the app container's `Documents/PlayaDB.sqlite` held 321/1201/2208/4697/496 rows,
  all six migrations, `object_metadata` empty, and **`thumbnail_colors` = 1573** — proving
  the seed restored rather than being rebuilt on device. More → Art rendered every row
  themed from its thumbnail immediately, with no colour pop-in.

---

## Follow-up: wiring the seed into watchOS

The first pass shipped the seed to the **iOS target only**. The watch was still importing
3.4 MB of JSON on first launch via `WatchSeeder.seedIfNeeded`, which is slow on watch
hardware. Three things kept it out:

1. The zip lived in `iBurn/`, the iOS target's synchronized folder group.
2. `iBurnWatchApp` called `createPlayaDB()` directly and never ran a restore.
3. `Zip` wasn't linked into the watch target.

### Shared restore logic

`PlayaDBSeeder.restoreBundledSeedIfNeeded` was app-target code, so the watch couldn't call
it. Rather than duplicate ~40 lines of careful failure handling, the rules moved into
PlayaDB as `PlayaDBSeedRestore` (`Packages/PlayaDB/Sources/PlayaDB/SeedRestore.swift`).

PlayaDB does **not** gain a compression dependency — the unzip step is injected:

```swift
public static func restoreIfNeeded(
    documentsURL: URL = PlayaDBSeedRestore.defaultDocumentsURL,
    seedZipURL: URL?,
    unzip: (_ archive: URL, _ destination: URL) throws -> Void
) -> Outcome
```

`Outcome` is `.restored` / `.skippedDatabaseExists` / `.skippedNoSeed` / `.failed(String)`,
so each app logs through its own facility (CocoaLumberjack on iOS, `print` on watch) while
the decisions stay in one place. Both `PlayaDBSeeder` and `WatchSeeder` are now thin
wrappers that resolve the bundle resource and pass `Zip.unzipFile`.

Nine tests in `Packages/PlayaDB/Tests/PlayaDBTests/SeedRestoreTests.swift` cover every
outcome plus "the restored file actually opens as a working database".

### Ordering matters

The restore must run **before** the database is opened — once `PlayaDB.sqlite` exists the
restore is a deliberate no-op. On the watch that meant putting it at the top of
`iBurnWatchApp.init()`, ahead of `createPlayaDB()`; `WatchSeeder.seedIfNeeded` continues
to run later in the root `.task`.

### Why the JSON stays bundled

Per the user: the seed can go stale relative to a build's data. The seed carries
`update_info` rows baked from `update.json`, and `needsImport(bundleUpdateData:)` compares
the bundled JSON against them — so shipping refreshed JSON on top of an older baked
database still triggers a re-import. Dropping the JSON would have saved 3.4 MB and broken
that. Watch install size is not a concern here.

### Seed placement

The zip goes in `iBurnWatch/PlayaDB-<year>.zip`, picked up by that target's synchronized
folder group. Deliberately *not* an explicit `PBXFileReference` pointing at the iOS copy:
an explicit reference to a gitignored file breaks the build on a clone that hasn't run
`playa-seed`, whereas a synchronized group just omits it — preserving "missing seed = slow
launch, not build failure" on both targets.

`playa-seed` now writes both copies in one run; `--output` became repeatable, defaulting to
one zip per app target.

### watchOS verification

Erased Apple Watch Ultra 3 sim, direct install of the `iBurnWatch` scheme:

```
art 321 · camps 1201 · events 2208 · occurrences 4697 · mv 496
thumbnail_colors 1573 · object_metadata 0
```

`update_info.created_at` reads `2026-07-26 17:26:09` — the *bake* timestamp — and still
does after a second launch, confirming the restore was used and the JSON import never ran.
(`thumbnail_colors` is unused on watch, which renders SF Symbols rather than thumbnails,
but rides along in the shared seed.)

## Expected Outcomes

- First launch on a fresh install is near-instant on **both** phone and watch: no JSON
  import, no colour extraction.
- Regenerating both seeds is one command instead of a manual simulator round-trip.
- One colour algorithm and one seed-restore implementation in the codebase.

## Remaining Work

- `a1XVI00000FN9rZ2AT`'s thumbnail is `"processing"` upstream; re-run `--fetch-media` once
  the org finishes converting it.
- `iBurn/iBurn-2026.zip` (the **YapDatabase** seed) is still produced by hand. Yap is being
  retired — only bridges and the boot import remain — so it was deliberately left alone.
- CI does not build the seeds (the zips are gitignored), so TestFlight/App Store builds need
  the tool run locally beforehand. A `fastlane seed` lane was offered and deferred.

## Cross-References

- `Docs/2026-04-12-persistent-color-cache-list-rows.md` — where `thumbnail_colors` came from
- `Docs/2026-07-25-playadb-default-yap-audit-and-migration.md` — the PlayaDB-by-default work
- `.claude/skills/drive-app/references/flows.md` §2 — updated with seeded row counts and how
  to tell a restored seed from an on-device import
