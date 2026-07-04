# 2026-07-04: Events List Empty on Device — Stale PlayaDB Seed

## High-Level Plan

**Problem:** After building the `2026-updates` branch to a physical phone, the Events list is empty while Art/Camps/MVs display fine.

**Root cause:** Both `PlayaDBSeeder` (iOS) and `WatchSeeder` (watchOS) only imported bundled data when the database had *never* been seeded:

```swift
let updateInfo = try await playaDB.getUpdateInfo()
guard updateInfo.isEmpty else { return }
```

A device that installed a dev build earlier in the year had PlayaDB seeded with **2025 data**. When the 2026 APIData bundle landed (`iBurn-Data` commit `3947cfb`, Jul 3 2026), the seeder saw a non-empty `update_info` table and skipped the import entirely. The result:

- **Art/Camps/MVs:** stale 2025 rows, but they display fine (no time filtering) → "other data types work".
- **Events:** all 2025 occurrences ended Sep 2025, so the default `EventFilter(includeExpired: false)` (`EventListViewModel.swift:85`) → `notExpired()` (`endTime > now`) filters out *every* row → empty list.

Fresh simulator installs (erased regularly) seeded 2026 data from scratch, masking the bug.

**Solution:** Make seeding version-aware using the bundle's `update.json` per-type timestamps:

1. `PlayaDB.importFromData` gained an `updateData: Data?` parameter. When provided, the per-type `updated` timestamps from `update.json` are stored as each type's `UpdateInfo.lastUpdated` (previously always import wall-clock time). Falls back to `Date()` when absent.
2. New protocol method `PlayaDB.needsImport(bundleUpdateData:) -> Bool` — true when the DB has never been seeded, when a bundle data type has no imported counterpart (e.g. `mv` added later), or when the bundle's timestamp for any type is newer than the stored `lastUpdated`.
3. `PlayaDBSeeder` and `WatchSeeder` call `needsImport` instead of `isEmpty`, and pass `updateData` through to the import.
4. `PlayaAPI.UpdateInfo` model gained the missing `mv: FileUpdateInfo?` field (2026 `update.json` includes an `mv` entry).
5. `DataUpdatesView.reimportPlayaDB()` also passes `updateData` now.

Wall-clock fallback comparison stays correct: import time is always ≥ the data's publish time, so a legacy row (wall-clock `lastUpdated`) is re-imported iff the bundle ships genuinely newer data.

## Technical Details

### Files Modified

- `Packages/PlayaAPI/Sources/PlayaAPI/Models/UpdateInfo.swift` — added `mv` field; included in `lastUpdated`/`hasUpdates`.
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` — protocol: `importFromData(...updateData:)` + `needsImport(bundleUpdateData:)`; convenience overload preserves the old 4-arg signature.
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` — `needsImport` implementation; import stores `update.json` timestamps as `lastUpdated`; `importFromPlayaAPI` loads `update.json` too.
- `iBurn/PlayaDBSeeder.swift` — staleness-aware seed gate.
- `iBurnWatch/WatchSeeder.swift` — same fix for the watch.
- `iBurn/DataUpdatesView.swift` — manual re-import passes `updateData`.
- `Packages/PlayaDB/Tests/PlayaDBTests/PlayaDBImportTests.swift` — 5 new tests: empty DB → needs import; same data → no re-import; newer events timestamp → re-import; new data type (mv) in bundle → re-import; `lastUpdated` stores bundle timestamp not wall-clock.

### needsImport comparison logic (PlayaDBImpl)

```swift
func needsImport(bundleUpdateData: Data) async throws -> Bool {
    let bundleInfo = try APIParserFactory.create().parseUpdateInfo(from: bundleUpdateData)
    let storedInfo = try await getUpdateInfo()
    guard !storedInfo.isEmpty else { return true }
    let storedByType = Dictionary(uniqueKeysWithValues: storedInfo.map { ($0.dataType, $0) })
    let bundleByType: [(DataObjectType, FileUpdateInfo?)] = [
        (.art, bundleInfo.art), (.camp, bundleInfo.camps),
        (.event, bundleInfo.events), (.mutantVehicle, bundleInfo.mv)
    ]
    for (type, fileInfo) in bundleByType {
        guard let fileInfo else { continue }
        guard let stored = storedByType[type.rawValue] else { return true }
        if fileInfo.updated > stored.lastUpdated { return true }
    }
    return false
}
```

Gotcha: inside PlayaDB, `PlayaAPI.FileUpdateInfo` fails to compile — `PlayaAPI` resolves to the public enum, not the module. Use the unqualified name.

## Debugging Path (Context Preservation)

Approaches ruled out along the way:

- `EventFilter(includeExpired: false)` default with 2026 data — bundled occurrences span Aug 30–Sep 6 2026, all future, `notExpired` keeps them.
- Day-bucket key mismatch (`bucketByDayThenHour` vs `EventListViewModel.browseSections`) — both use `Calendar.current.startOfDay`, consistent per device.
- 2026 `event.json` format/type codes — 2,140 events / 4,526 occurrences, standard `event_type.abbr` codes, `update.json` includes an `events` entry.
- Legacy Yap path (`eventsFilteredByExpirationAndType`) — passes non-ended events; the legacy `BRCDataImporter` has its own update.json timestamp comparison so it self-heals on upgrade. The SwiftUI/PlayaDB path did not — hence this fix.
- Atomicity red herring: `importFromData` is one GRDB transaction, so "camps imported but events failed" is impossible; a *skipped* import (stale DB) explains the partial-looking symptom instead.

## Expected Outcomes

- Rebuilding to the phone reseeds PlayaDB with 2026 data on next launch (bundle events timestamp `2026-07-03T12:40:06-07:00` > stored 2025-era `lastUpdated`), and Events populate.
- Same auto-heal on the watch.
- Future data drops (new `update.json` timestamps) auto-import on devices with existing databases.
- Immediate manual workaround (pre-fix builds): More → Data Updates → "Reset to Bundled Data".

## Verification

- `swift test` in `Packages/PlayaDB` — all suites pass (incl. 5 new tests); `Packages/PlayaAPI` — all pass.
- `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn` (iPhone 17 Pro Max sim) — build succeeds; watch target builds as embedded companion.

## Cross-References

- `Docs/2026-07-03-2026-year-update-plan.md` — the 2026 data drop that exposed this.
- `Docs/2026-07-03-watchos-mvp-plan.md` — WatchSeeder origin.
