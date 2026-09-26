# 2026-09-26 — BRC time zone sweep

## High-Level Plan

**Problem.** PR #256 (`ci-xcode-27`) found that global search bucketed event times with the
device calendar (`Calendar.current`) while rows display Black Rock City time. On a UTC CI runner
a noon event landed in "Evening". The same bug existed elsewhere: the Events tab day buckets,
the day picker, "today" in Favorites and on the map, and more. People arrive on playa with
phones and watches still set to the zone they flew in from.

**Rule.** Anything that buckets, compares or constructs festival dates uses BRC time
(`America/Los_Angeles`), whatever the device zone. Genuinely device-local things (the user's own
viewing history, pure durations) may keep the device calendar.

**Solution.** Branch `brc-timezone`, stacked on `ci-xcode-27` (#256).
- One shared definition in `Packages/PlayaAPI/Sources/PlayaAPI/BlackRockCityTime.swift`:
  `public TimeZone.burningMan` (`TimeZone(identifier: "America/Los_Angeles")`) and
  `public Calendar.burningMan`. PlayaAPI is the lowest package that PlayaDB, the app and the
  watch all link, so PlayaDB can use it and the app reuses it instead of defining its own.
- The app's `TimeZone.burningManTimeZone` (`TimeZone(abbreviation: "PDT")!`) and #256's
  app-local `Calendar.burningMan` are removed. Every Swift use of `.burningManTimeZone` is now
  `.burningMan`. Obj-C keeps `+[NSTimeZone brc_burningManTimeZone]`, which now returns the
  shared zone.
- Ad-hoc BRC calendars are folded into `Calendar.burningMan`:
  - `SearchResultIndex.brcCalendar`
  - `TimeOfDay`, `RightNowViewModel`, `RightNowView`, `WorkflowUtilities`
  - PlayaDB's `PlayaDBImpl.playaCalendar` and `DateFormatter.playaTimeZone`

**`TimeZone(abbreviation: "PDT")`.** On Darwin it resolves to `America/Los_Angeles`
(identifier `America/Los_Angeles`, −25200s in September, −28800s in January). It is DST-aware,
not a fixed offset, so it was never wrong in practice. But it relies on
`TimeZone.abbreviationDictionary` and was force-unwrapped. The identifier states the intent. The
fallback chain (fixed −7h, then `.gmt`) is unreachable on Apple platforms.

## Per-site decisions

| Site | Decision | Why |
|---|---|---|
| `PlayaDBImpl.bucketByDayThenHour` | BRC | Day keys and hour sections for the Events tab (phone and watch). In Tokyo a 9 PM Thursday event was filed under Friday, in a 1 PM section. |
| `PlayaDBImpl.groupByHour` | BRC | Hour sections must match displayed times. |
| `PlayaDBImpl.fetchEvents(on:)` | BRC | Festival day bounds. |
| `EventFilter.forDay` | BRC | Festival day bounds. |
| `QueryInterfaceRequest.startingWithin(hours:)` | `addingTimeInterval` | Elapsed hours. Calendar `.hour` addition was already absolute, so this changes nothing except removing the calendar. |
| `PlayaDBImpl.playaCalendar`, `DateFormatter.playaTimeZone` | now alias the shared definitions | Single definition. |
| `YearSettings.festivalDays` | BRC, via new testable `festivalDays(from:to:calendar:)` | Festival day list. In practice the old code already produced BRC midnights (it added days to a BRC-midnight `eventStart`), but it now states that. |
| `EventListViewModel.browseSections` key | BRC | Looks up PlayaDB's BRC-midnight keys. In Honolulu every day tab was empty or wrong, because device `startOfDay` of a BRC midnight is the previous local midnight. |
| `EventListViewModel` initial `selectedDay` | BRC `startOfDay(dayWithinFestival(.present))` | Now equals a `festivalDays` entry, so the picker's `scrollTo(selectedDay)` also matches its `.id(day)`. |
| `EventDayPickerView` | BRC formatters and `isDate(inSameDayAs:)` | Chips were labelled in device time; in Honolulu "SUN 30" read "SAT 29". |
| `FavoritesViewModel` "today only" | BRC | "Today" during the event. The force unwrap was replaced with a fallback. |
| `PlayaDBAnnotationDataSource` `todayWindow` / `occurrenceIsToday` / `mapWindow` / `occurrenceBelongsOnMap` / `favoriteEventFilter` defaults | `.burningMan` | Map "today". Also added a one-shot timer at the next BRC midnight, because `NSCalendarDayChanged` fires at *device* midnight. That observer is kept. |
| `DetailViewModel.formatEventTimeAndDuration` | BRC "Today/Tomorrow", new `now: Date = .present` param | The labels sit beside BRC times. Also honours the mock date now (previously `Date()` via `isDateInToday`). |
| `TimeShiftViewModel` sunrise/noon/sunset | BRC, via new `static next(hour:after:calendar:)` | 7 AM means 7 AM on playa. Removed the `components.day! += 1` force unwrap. |
| `TimeShiftView` DatePicker and `formatDate`, `TimeShiftViewModel.dateRangeDescription`, `NearbyView` "Warped:" label | BRC | The warp target is a playa time. Showing it in device time next to BRC event times was confusing. |
| `FeatureFlagsView` (DEBUG mock-date presets) | BRC presets, picker and labels | The Temple Burn preset used device `dateComponents` and landed on the wrong day east of Pacific. The picker is shown in BRC so presets and picker agree. The footer says so. |
| `iBurnWatch/EventListScreen` | BRC "today" key and day/time formatters | Same buckets as the phone. |
| `iBurnWatch/DetailScreen` occurrence text | BRC weekday and interval formatters | Matches the phone. |
| `NSDate+iBurn.m` `brc_daysBetweenDate:andDate:`, `brc_nextDay`, `brc_dateWithinStartDate:endDate:` | **deleted** | No callers in Obj-C or Swift. Dead code that used `currentCalendar`. |
| `GlobalSearchFilterSheet` `#Preview` | BRC | Preview only; consistency. |
| `EmbargoPasscodeViewModel` countdown | **kept** `Calendar.current` | A duration (`dateComponents(from:to:)` between two absolute instants). The zone matters only if a DST change in the *device* zone falls in between. |
| `DetailViewHistoryCell` formatter (DetailView.swift) | **kept** device-local | The user's own first/last viewed timestamps, not festival dates. |
| `RecentlyViewedViewModel` `RelativeDateTimeFormatter` | kept | Relative ("5 min ago"), zone-neutral. |
| `DataUpdatesView` (`shortDateAndTime`) | unchanged (already BRC) | Out of scope; it was already explicit. |
| Calendar export (`EventCalendarService` / `EventStoreProviding`) | unchanged | EKEvent start/end are absolute `Date`s and the draft carries `TimeZone.burningMan`, so entries are correct in any zone. |
| Notifications / reminders | none exist | No `UNCalendarNotificationTrigger` or `EKAlarm` in the app. |
| "Happening now" / "starting soon" (`EventObjectOccurrence`, `MapEventRefreshBoundary`, `happeningNow()`) | unchanged | Pure instant comparisons, zone-neutral. |
| Formatters in `DateFormatter+iBurn.swift`, `NSDateFormatter+iBurn.m`, `DisplayableObject`, `SearchResultIndex`, `DetailView`, AI search | unchanged | Already set `timeZone` to BRC. |

## Tests

- `Packages/PlayaDB/Tests/PlayaDBTests/BlackRockCityTimeTests.swift` (process zone forced to
  Tokyo):
  - `bucketByDayThenHour` BRC day keys and hours;
  - `groupByHour`;
  - `EventFilter.forDay` bounds;
  - `fetchEvents(on:)`;
  - `startingWithin(hours:)` elapsed time;
  - the shared definition.
  - **Verified failing before the fix**, with the PlayaDB source changes stashed: 5 of 7 failed.
    For example `[4, 13] is not equal to [12, 21]`, and day key `2026-09-03 15:00 +0000` instead
    of the BRC midnights.
- `iBurnTests/BlackRockCityTimeTests.swift` (Honolulu, Tokyo and New York):
  - festival day list, both computed and shipped;
  - `EventListViewModel` selected day finds its BRC bucket;
  - day picker labels;
  - detail "Today/Tomorrow";
  - map today window;
  - time-shift quick times;
  - the shared zone reused by the app.
- Existing PlayaDB tests that built fixtures with `Calendar.current` now use
  `Calendar.burningMan`, so they pass in any host zone: `EventListBucketObservationTests`,
  `EventHourSectionTests`, `PlayaDBRealDataTests` and `QueryExtensionsTests`.

## User-visible changes

- Users whose device isn't on Pacific time now see:
  - the Events tab day picker, day buckets and hour strip in BRC days and hours, matching the
    row times;
  - Favorites "Today only" and the map's "today" favourites and happening-now layers using the
    BRC day;
  - detail "Today/Tomorrow" labels using BRC days;
  - the same on the watch's event list and detail.
- Time Shift: the date wheel and "Warped:" labels are now in BRC time, and the
  Sunrise/Noon/Sunset buttons jump to 7 AM, noon and 7 PM BRC.
- DEBUG feature-flags mock-date picker and presets are in BRC time.
- No change for anyone whose device is on Pacific time, which covers everyone on playa whose
  phone auto-sets its zone.

## Verification (local, 2026-09-26)
- iBurnTests on iPhone 18 Pro Max / iOS 27.0 sim:
  - Pacific: 708 tests, 0 failures.
  - `TEST_RUNNER_TZ=UTC`: 708 tests, 0 failures.
- `swift test --package-path Packages/PlayaDB`: 375 passed, both with the host on PDT and with
  `TZ=Asia/Tokyo`.
- `swift test --package-path Packages/PlayaAPI`: 74 passed.
- iBurnWatch build (watchOS Simulator): success. No `DEVELOPMENT_TEAM` pbxproj flip.
- Gotcha: `TimeZone(identifier: "UTC")` reports its identifier as `GMT` once set as
  `NSTimeZone.default`, so the zone-identity assertion in the app test uses New York instead.

## Commits (branch `brc-timezone`)
1. Share one Black Rock City time zone and calendar via PlayaAPI.
2. PlayaDB: bucket festival days and hours in Black Rock City time.
3. Remove unused NSDate day helpers that used the device calendar.
4. Use Black Rock City time for festival days across the app and watch.
5. Docs (this file).

## Cross-References
- `Docs/2026-09-26-ci-xcode-27.md`: #256, which found the bug in global search and added the
  original app-local `Calendar.burningMan`.
- `Docs/2026-08-10-per-occurrence-event-favorites.md`: PlayaDB's `playaTimeZone` formatters.
