# Fix Corrupted Event Occurrence Times During Import

## Problem

The Burning Man PlayaEvents API returns corrupted event occurrence data with two patterns:
- **Negative duration** (252 occurrences in 2025 data): `endTime` before `startTime` -- wrong date, correct time-of-day
- **Excessively long duration** (41 occurrences): `endTime` days after `startTime` -- same root cause

Example: "Bikini Armor Workshop" showed "Mon 9:00am (122h 45m)" instead of the correct 2h 45m.

The old ObjC code in `BRCRecurringEventObject.m` fixed this, but the new Swift importer in `PlayaDBImpl.swift` inserted occurrences verbatim.

## Solution

Added `correctedOccurrenceTimes(startTime:endTime:calendar:)` static method to `PlayaDBImpl`:
1. If duration is normal (0..24h), pass through unchanged
2. Otherwise, extract time-of-day from `endTime`, apply to `startTime`'s calendar date
3. If result is still before `startTime`, add 1 day (midnight crossing)

Uses a fixed Playa timezone calendar (America/Los_Angeles) for correct time-of-day extraction.

## Files Modified

- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` -- Added correction function, updated both occurrence insertion sites (primary + duplicate UID path), added correction counter logging
- `Packages/PlayaDB/Tests/PlayaDBTests/EventOccurrenceCorrectionTests.swift` -- New: 9 unit tests covering normal, negative, excessive, and midnight-crossing cases
- `Packages/PlayaDB/Tests/PlayaDBTests/PlayaDBRealDataTests.swift` -- Added integration test verifying no negative or >24h durations after real data import

## Verification

- 9 unit tests pass (EventOccurrenceCorrectionTests)
- Real data integration test passes (validates all 2025 occurrences have reasonable durations)
- Full app builds successfully

## Technical Details

### Correction Algorithm
```swift
static func correctedOccurrenceTimes(startTime:endTime:calendar:) -> (startTime: Date, endTime: Date)
```
- Threshold: 24 hours (no legitimate single occurrence spans more than a day)
- Calendar: Gregorian with America/Los_Angeles timezone
- Handles both negative duration and excessive duration with same algorithm

### Data Impact (2025 dataset)
- 252 negative-duration occurrences corrected
- 41 excessive-duration occurrences corrected
- ~293 total corrections out of ~4567 events

## Data Updates Screen: Dual Database Support

### Problem
1. The Data Updates screen only updated YapDatabase; PlayaDB was seeded once at startup and never re-imported
2. "Reset to Bundled Data" silently failed for PlayaDB because `importFromData` never cleared `update_info` before re-inserting — duplicate primary key rolled back the entire transaction
3. PlayaDB's `UpdateInfo` model only had 5 fields vs BRCUpdateInfo's 7 properties
4. PlayaDB stats section showed minimal info and required manual refresh

### Solution
1. **Root cause fix**: Added `UpdateInfo.deleteAll(db)` at the top of `importFromData`'s write transaction, before any other deletions
2. **Schema expansion**: Added 5 new columns to `UpdateInfo` (fileName, fetchStatus, lastCheckedDate, fetchDate, ingestionDate) via ALTER TABLE migration, matching BRCUpdateInfo's fields
3. **Reactive observation**: Added `observeUpdateInfo()` to PlayaDB protocol/impl using `ValueObservation.tracking`, so the UI updates automatically during re-import without manual refresh
4. **Expanded nerdy stats**: PlayaDB section now shows count, status, last updated, fetch date, check date, and ingestion date — same detail as the Yap section
5. **Proper reset flow**: Both "Check for Updates" and "Reset to Bundled Data" trigger PlayaDB re-import; spinner stays active until both DBs finish; user metadata and favorites are preserved (only API data tables are cleared)

### Files Modified
- `Packages/PlayaDB/Sources/PlayaDB/Models/UpdateInfo.swift` -- Added 5 new fields (fileName, fetchStatus, lastCheckedDate, fetchDate, ingestionDate)
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` -- Schema migration for new columns, fix importFromData to clear update_info, populate new fields on insert, add observeUpdateInfo
- `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` -- Added observeUpdateInfo to protocol
- `iBurn/DataUpdatesView.swift` -- GRDB observation replaces polling, expanded nerdy stats, proper reset flow with isLoading lifecycle
