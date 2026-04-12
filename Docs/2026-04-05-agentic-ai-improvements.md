# Agentic AI Improvements

## Problem Statement
The existing AI assistant uses single-shot LLM calls via Apple Foundation Models — one request, one response, no iteration. Tool outputs are truncated to 60-80 chars. There's no conversational interface, no multi-step reasoning, and no creative Burning Man-specific workflows.

## Solution Overview
Transform the AI into a multi-step agentic system with:
- **Structured workflow browser** — a List-based UI where each AI workflow is discoverable with its own detail screen, configuration knobs, and transparent step-by-step progress
- **Whimsical playa-themed progress messages** — "Rolling the cosmic dice...", "Following the glow of neon in the dust...", etc.
- **Multi-step workflows** where Swift handles orchestration + computation, LLM handles reasoning
- **8 workflows**: For You, Surprise Me, What Did I Miss, Day Planner, Adventure Generator, Camp Crawl, Golden Hour Art, Schedule Optimizer
- **Unified AI Guide** — merged the old separate AI Assistant and AI Chat into a single "AI Guide" entry
- **7 new tools** + `detailLevel` parameter on existing tools for context budget management
- **Intent classification** for automatic workflow routing

## Architecture: "Thin LLM, Thick Orchestrator"
```
User Input -> ChatViewModel -> IntentClassifier (LLM) -> AgentOrchestrator
    -> [Step 1: Swift data fetch]
    -> [Step 2: LLM reasoning with focused context]
    -> [Step 3: Swift computation (distances, conflicts)]
    -> [Step 4: LLM final generation]
    -> ChatMessage stream -> ChatView UI
```

Each workflow step gets its own `LanguageModelSession` with only 2-4 relevant tools, keeping within ~4K token budget.

## UI Architecture

The AI Guide uses a **workflow browser → detail view** pattern:

1. **AIGuideView** — `List` with sections (Discover / Plan / Optimize), each workflow is a row
2. **WorkflowDetailView** — Per-workflow screen with:
   - Header with description
   - Configuration knobs (theme text field, hours slider, sunrise/sunset toggle, etc.)
   - "Generate" button
   - Live progress section with animated step checkmarks + whimsical messages
   - Rich results (object cards, schedules, adventure routes)

### Workflow-Specific Controls
| Workflow | Knobs |
|----------|-------|
| Adventure Generator | Theme text field |
| Camp Crawl | Theme text field |
| What Did I Miss? | Hours lookback slider (6-48h) |
| Golden Hour Art | Sunrise/Sunset toggle |
| For You, Surprise Me, Day Planner, Schedule Optimizer | No config needed |

### Progress Transparency
Each workflow shows real-time step progress with playa-themed messages:
```
 Channeling your inner burner...
 Sending scouts across the playa...
⟳ Separating the sparkle from the dust...
○ Crafting your playa story...
```

## Key Changes

### New Files (22)
| File | Purpose |
|------|---------|
| `iBurn/AISearch/AgentOrchestrator.swift` | Multi-step workflow engine |
| `iBurn/AISearch/ContextBudget.swift` | Token budget tracking |
| `iBurn/AISearch/ConversationManager.swift` | Session lifecycle + history |
| `iBurn/AISearch/IntentClassifier.swift` | LLM intent routing |
| `iBurn/AISearch/ChatMessage.swift` | Message + card models |
| `iBurn/AISearch/ChatViewModel.swift` | Chat state + workflow routing |
| `iBurn/AISearch/ChatView.swift` | SwiftUI chat interface |
| `iBurn/AISearch/ChatBubble.swift` | Message rendering components |
| `iBurn/AISearch/Workflows/WorkflowProtocol.swift` | Workflow protocol + utilities |
| `iBurn/AISearch/Workflows/DayPlanWorkflow.swift` | Enhanced day planner |
| `iBurn/AISearch/Workflows/AdventureWorkflow.swift` | Themed adventures |
| `iBurn/AISearch/Workflows/ScheduleOptimizerWorkflow.swift` | Conflict resolution |
| `iBurn/AISearch/Workflows/GeneralChatWorkflow.swift` | Freeform Q&A |
| `iBurn/AISearch/Workflows/SerendipityWorkflow.swift` | Surprise me |
| `iBurn/AISearch/Workflows/CampCrawlWorkflow.swift` | Camp hopping |
| `iBurn/AISearch/Workflows/WhatDidIMissWorkflow.swift` | Location history discovery |
| `iBurn/AISearch/Workflows/GoldenHourWorkflow.swift` | Sunrise/sunset art |
| `Docs/2026-04-05-agentic-ai-improvements.md` | This doc |

### Modified Files (5)
| File | Changes |
|------|---------|
| `iBurn/AISearch/PlayaSearchTools.swift` | 7 new tools, `detailLevel` on existing, `Any`-based formatters |
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDB.swift` | Added `fetchRecentlyViewed`, `fetchFavoriteEvents` |
| `Packages/PlayaDB/Sources/PlayaDB/PlayaDBImpl.swift` | Implemented new protocol methods |
| `iBurn/DependencyContainer.swift` | Added `makeChatViewModel()` factory |
| `iBurn/MoreViewController.swift` | Added "AI Guide" chat entry point |

### New Tools
1. `FetchEventsByCampTool` — events hosted by a camp
2. `FetchEventsAtArtTool` — events at an art installation
3. `FetchEventsByTypeTool` — events by type code with optional time window
4. `FetchObjectDetailsTool` — full details for any object by UID
5. `GetViewHistoryTool` — recently viewed objects
6. `GetLocationHistoryTool` — GPS breadcrumb trail
7. `CalculateDistanceTool` — walking distance + time between coordinates

### Tool Detail Levels
- `brief`: name + uid only (~15 tokens/item) — exploration steps
- `normal`: name + short desc + uid (~30 tokens) — default
- `full`: name + full desc + location + metadata + uid (~80 tokens) — final selection

## Technical Decisions

### DataObject Name Conflict
iBurn has a legacy `class DataObject` (Obj-C bridge) that shadows PlayaDB's `protocol DataObject`. Resolved by using `Any` type with concrete casts instead of generic constraints, and helper functions `objectUID()` / `objectName()` in WorkflowProtocol.swift.

### Context Window Strategy
Each LLM call stays within ~3500 tokens by:
- Using `detailLevel: "brief"` in exploration steps
- Giving each step only 2-4 relevant tools
- Fetching full details only for selected items
- Using Swift for all computation (distance, conflict detection, clustering)

### Backward Compatibility
- Existing `AIAssistantView` and `AIAssistantViewModel` untouched
- Chat requires iOS 26+ with Apple Intelligence (same as existing AI features)
- `DependencyContainer.makeChatViewModel()` returns nil on unsupported devices

## Verification
- Build: `xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2,arch=arm64' -quiet 2>&1 | xcsift -f toon -w` -- **PASS**
- All pre-existing warnings unchanged
- No new warnings in added code

## Expected Outcomes
Users will see a new "AI Guide" option in the More screen that provides:
- Chat-based natural language interaction about Burning Man
- Quick-start cards for one-tap workflows (Surprise Me, Plan Adventure, etc.)
- Multi-step results with walking routes, schedule optimization, themed adventures
- Object cards that navigate to detail views
- Follow-up suggestion chips for conversation flow

## Bug Fixes Applied (session 2)

### FTS5 SQL Injection (`PlayaDBImpl.swift`)
- **Bug**: Special characters like `&` in LLM-generated search queries caused FTS5 syntax errors
- **Fix**: Wrap all FTS5 queries in double quotes to treat as phrase search, strip internal quotes

### Workflow Retry Logic (`AIGuideViewModel.swift`)
- **Bug**: Guardrail violations and unsupported language errors crashed the workflow
- **Fix**: Added `executeWithRetry()` with up to 2 retries. On guardrail violation, retries with a "safe" theme. On language error, shows helpful message about English requirement.
- Recoverable errors: guardrailViolation, unsupportedLanguage, fts5 syntax, resourceExhausted

### State Preservation on Navigation
- **Bug**: Navigating to detail view and back cleared all workflow results
- **Fix**: Removed `onDisappear { reset() }`. Added per-workflow state cache (`workflowStates` dictionary). `loadWorkflow()` restores cached results when re-entering a workflow.

### Auto-Start Workflows
- Workflows without user input (For You, Surprise Me, Day Planner, etc.) now auto-start via `.task` on appear
- Workflows requiring input (Adventure, Camp Crawl) wait for the user to type a theme

### Native Detail Cells
- Replaced custom `ObjectCardRow` with `MediaObjectRowView` — the same cells used in Art, Camp, MV, and Event lists
- Results now show thumbnails, full names, subtitles, and favorite buttons matching the rest of the app

### Fixed Invalid SF Symbol
- Replaced "tumbleweed" (doesn't exist) with "wind" for empty states

## Remaining Work
- Unit tests for ContextBudget, conflict detection, distance calculation, clustering
- Integration tests with mock PlayaDB for each workflow
- Device testing on iOS 26 simulator with real Foundation Models
- "Show on Map" action for adventure/crawl routes
