# Fix Audio Toggle Tests - 2025-10-25

## Problem Statement

The `testCellTapAudioTogglesPlayback` test was failing with:
```
XCTAssertTrue(viewModel.isAudioPlaying) failed
```

## Root Cause Analysis

The test failure had two issues:

1. **MockAudioService wasn't posting notifications**: The real `BRCAudioPlayer` posts `BRCAudioPlayerChangeNotification` when audio state changes, but the mock service wasn't doing this. The `DetailViewModel` depends on this notification to update its `isAudioPlaying` state.

2. **Test using wrong art object**: The tests were creating audio cells with `artObjectWithAudio`, but using the default `viewModel` which was initialized with a regular `artObject` (without audio URL). When the notification arrived, `updateAudioPlayingState()` would check if the viewModel's `dataObject` had an audio URL, and it didn't.

## Solution

### 1. Updated MockAudioService (`MockServices.swift`)

Added notification posting in `playAudio()` and `pauseAudio()`:

```swift
func playAudio(artObjects: [BRCArtObject]) {
    playAudioCalled = true
    currentlyPlaying = artObjects.first

    // Post notification synchronously for simpler testing
    NotificationCenter.default.post(
        name: Notification.Name(BRCAudioPlayer.BRCAudioPlayerChangeNotification),
        object: nil
    )
}
```

**Note**: Used synchronous posting (no `DispatchQueue.main.async`) for simpler test flow, as we're already on the main thread in tests.

### 2. Fixed Test Setup (`DetailViewModelTests.swift`)

Updated both audio tests to create a `DetailViewModel` with `artObjectWithAudio`:

```swift
func testCellTapAudioTogglesPlayback() {
    let artObject = MockDataObjects.artObjectWithAudio

    // Create a viewModel with the art object that has audio
    let audioViewModel = DetailViewModel(
        dataObject: artObject,
        dataService: mockDataService,
        audioService: mockAudioService,
        locationService: mockLocationService,
        coordinator: mockCoordinator
    )

    let audioCellType = DetailCellType.audio(artObject, isPlaying: false)
    let audioCell = DetailCell(audioCellType)

    audioViewModel.handleCellTap(audioCell)

    XCTAssertTrue(mockAudioService.playAudioCalled)
    XCTAssertTrue(audioViewModel.isAudioPlaying)
}
```

## Technical Details

### Files Modified

- `iBurn/Detail/Services/MockServices.swift`: Added notification posting to MockAudioService
- `iBurnTests/DetailViewModelTests.swift`: Fixed test setup for both audio toggle tests

### Notification Flow

1. User taps audio cell → `handleCellTap()` called
2. `handleCellTap()` calls `audioService.playAudio()`
3. Audio service posts `BRCAudioPlayerChangeNotification` (async on main queue in production, sync in tests)
4. `DetailViewModel` notification observer receives notification
5. `updateAudioPlayingState()` called, checks if `dataObject` has audio
6. Updates `isAudioPlaying` based on `audioService.isPlaying(artObject:)`

### Design Considerations

**Option 1 vs Option 2**: We chose Option 2 (synchronous notification posting in mock) over Option 1 (XCTestExpectation with async) because:
- Simpler test code - no need for expectations and waits
- Tests are already running on main thread
- Don't need to match threading behavior in unit tests
- Faster test execution

## Test Results

Both tests now pass:
- `testCellTapAudioTogglesPlayback` ✅
- `testCellTapAudioPausesWhenPlaying` ✅

## Commit

```
60a6389 Fix audio toggle tests by posting notification in MockAudioService
```
