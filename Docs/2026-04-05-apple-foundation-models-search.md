# Apple Foundation Models: AI-Powered Search

## High-Level Plan

Add on-device AI-powered semantic search using Apple's Foundation Models framework (iOS 26+). The on-device LLM acts as a natural language router, calling PlayaDB search tools to find results that keyword-based FTS5 would miss (e.g., "art that shoots flames" finding items tagged "fire").

**Approach:** Tool calling pattern -- expose PlayaDB fetch/search operations as `Tool` protocol conformances. The model decides which tools to call based on the user's natural language query, then returns structured results via guided generation (`@Generable`).

**Fallback:** FTS5 keyword search remains the baseline. AI search is an enhancement that runs in parallel and augments FTS5 results. Gracefully absent on older devices.

## Architecture

```
User query
    |
    v
GlobalSearchViewModel
    |
    +-- FTS5 (immediate) --> results displayed
    |
    +-- AI Search (parallel, if available)
        |
        v
    FoundationModelSearchService
        |
        v
    LanguageModelSession + Tools
        - SearchByKeywordTool (wraps playaDB.searchObjects)
        - FetchArtTool (wraps playaDB.fetchArt with filter)
        - FetchCampsTool (wraps playaDB.fetchCamps with filter)
        - FetchMutantVehiclesTool (wraps playaDB.fetchMutantVehicles with filter)
        |
        v
    Guided generation -> [AISearchResultItem] (uid + reason)
        |
        v
    Fetch actual objects by UID -> merge into existing sections
    AI-only results get sparkle badge in UI
```

## Technical Details

### New Files

#### `iBurn/AISearch/AISearchService.swift`
- `AISearchResult` struct (uid + reason)
- `AISearchService` protocol (`isAvailable`, `search(_:)`)
- `FoundationModelSearchService` class (iOS 26+ only, `#if canImport(FoundationModels)`)
- `AISearchServiceFactory` for conditional creation
- `@Generable` structs: `AISearchResultItem`, `AISearchResponse`

#### `iBurn/AISearch/PlayaSearchTools.swift`
- `SearchByKeywordTool` -- wraps `playaDB.searchObjects()` (FTS5)
- `FetchArtTool` -- wraps `playaDB.fetchArt(filter:)`
- `FetchCampsTool` -- wraps `playaDB.fetchCamps(filter:)`
- `FetchMutantVehiclesTool` -- wraps `playaDB.fetchMutantVehicles(filter:)`
- All behind `#if canImport(FoundationModels)` and `@available(iOS 26, *)`
- Uses `@preconcurrency import PlayaDB` for Sendable compatibility

### Modified Files

#### `iBurn/DependencyContainer.swift`
- Added `aiSearchService` lazy property using `AISearchServiceFactory`
- `makeGlobalSearchViewModel()` now passes `aiSearchService`

#### `iBurn/ListView/GlobalSearchViewModel.swift`
- Added `aiSearchService` dependency (optional)
- Added `aiSuggestedUIDs` published set (tracks which results came from AI)
- Added `isAISearching` published bool
- After FTS5 results display, kicks off `runAISearch()` if AI is available
- `mergeAIResults()` adds AI-discovered items into existing sections

#### `iBurn/ListView/GlobalSearchView.swift`
- Added sparkle icon overlay on AI-suggested result rows
- Added "Finding more with AI..." progress indicator at bottom of results list

## Key Decisions

1. **App target, not PlayaDB package** -- PlayaDB targets iOS 16+, FoundationModels requires iOS 26+. AI search lives in the iBurn app target with availability guards.
2. **`#if canImport` + `@available`** -- Compile-time gating (SDK availability) plus runtime gating (device capability). Builds on any Xcode, runs AI features only on capable devices.
3. **4 tools** -- Stays within Apple's 3-5 tool recommendation for context window efficiency.
4. **Parallel search** -- FTS5 results appear immediately; AI results augment after a brief delay. No degradation for non-AI devices.
5. **Sparkle badge** -- Subtle `Image(systemName: "sparkles")` overlay to indicate AI-discovered results.

## Build & Test Results

- **Build:** 0 errors, 2 pre-existing warnings (not from this change)
- **Tests:** All iBurnTests pass
- **Xcode version:** 26.4

## Remaining Work

- Test on physical device with Apple Intelligence enabled
- Consider adding AI search to individual list views (not just global search)
- When mv-tag-search branch merges, add `tagsText` to `FetchMutantVehiclesTool` output
- Consider custom adapter training with Burning Man-specific vocabulary
- Add error handling UI if AI search times out
