# Show Tab Bar on All Navigation Pushes

## Problem
Several view controllers set `hidesBottomBarWhenPushed = true`, causing the tab bar to disappear when navigating to detail screens, tracks, AI guide, recently viewed, and feature flags. With the iOS 26 Liquid Glass UI, the tab bar should remain visible throughout navigation for a consistent experience.

## Solution
Removed all 5 instances of `hidesBottomBarWhenPushed = true` across 2 files.

## Changes

### `iBurn/Detail/Controllers/DetailHostingController.swift`
- Removed `self.hidesBottomBarWhenPushed = true` from init (line 67) — this affected all detail screens (art, camps, events, mutant vehicles)

### `iBurn/MoreViewController.swift`
- Removed `tracksVC.hidesBottomBarWhenPushed = true` from `pushTracksView()` (line 343)
- Removed `hostingVC.hidesBottomBarWhenPushed = true` from `pushAIGuideView()` (line 392)
- Removed `recentVC.hidesBottomBarWhenPushed = true` from `pushRecentlyViewedView()` (line 416)
- Removed `featureFlagsVC.hidesBottomBarWhenPushed = true` from `pushFeatureFlagsView()` (line 501, DEBUG only)

### Not changed
- `MainMapViewController.swift:183-184` — explicitly re-shows tab bar in `viewWillDisappear`, harmless safety net kept as-is

## Verification
- Build succeeds with 0 errors, 0 warnings
- Test by navigating to detail views, tracks, recently viewed, AI guide — tab bar should remain visible

## Branch
`show-tab-bar-on-push` from `origin/master`
