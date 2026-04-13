# AI Summary of Hosted Events on Detail Pages

## Problem
Camp and art detail pages display hosted events (next event + "See all N events" link), but there's no quick summary of what the events collectively offer. Users have to tap through individual events to understand a camp/art's programming.

## Solution
Added AI-generated event collection summaries using Apple Foundation Models (iOS 26+) with the existing workflow pipeline for guardrail/context handling.

## Key Changes

### New Generable Type
- **`iBurn/AISearch/AIAssistantModels.swift`**: Added `GenerableEventCollectionSummary` with single `summary` field

### Reusable Summary Generator
- **`iBurn/AISearch/Workflows/WorkflowUtilities.swift`**: Added `generateEventCollectionSummary(events:hostName:) async -> String?`
  - Wraps `withContextWindowRetry` (halves event count on context overflow)
  - Inside uses `retryWithCandidateFiltering` (filters individual events that trigger guardrails)
  - Formats events with name, type code display name, and truncated description (120 chars)
  - Returns `nil` on complete failure for graceful degradation
  - Slightly snarky tone per user preference

### New Detail Cell Types
- **`iBurn/Detail/Models/DetailCellType.swift`**: Added `.eventSummaryLoading(hostName:)` and `.eventSummary(String, hostName:)` cases

### Cell Rendering
- **`iBurn/Detail/Views/DetailView.swift`**: 
  - Added `EventSummaryHeaderView` (shared between detail cells and events list)
  - Uses sparkles icon + "AI SUMMARY" header + ProgressView for loading state
  - Added rendering cases in `cellContent` switch and `isCellTappable`

### ViewModel Integration
- **`iBurn/Detail/ViewModels/DetailViewModel.swift`**:
  - New state: `resolvedEventSummary: String?`, `isGeneratingEventSummary: Bool`
  - `generateEventSummaryIfNeeded()` triggers after deferred data loads (Phase 3)
  - `generateEventSummaryCells(hostName:)` returns loading/summary/empty cells
  - Wired into `generateHostedEventCells` (camp/art), `generatePlayaEventCellTypes`, `generatePlayaEventOccurrenceCellTypes`

### Events List Integration
- **`iBurn/Detail/Controllers/PlayaHostedEventsViewController.swift`**: Added summary header above event list via `.task` modifier

## Three-Phase Loading
1. **Phase 1** (existing): Metadata loads, cells render immediately
2. **Phase 2** (existing): Deferred data loads (host events, images), cells refresh
3. **Phase 3** (new): AI summary generates from resolved events, cells refresh again

## Graceful Degradation
- Pre-iOS 26: `#if canImport(FoundationModels)` + `@available(iOS 26, *)` guards
- All events trigger guardrails: `retryWithCandidateFiltering` tries halves then individuals, returns nil if <2 safe
- Context overflow: `withContextWindowRetry` halves event count down to minimum 2
- Complete LLM failure: Returns nil, no summary cell shown

## Build Verification
- Build succeeds: 0 errors, 6 pre-existing warnings (none from new code)
