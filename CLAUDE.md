# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overall Guidance

### Documentation Workflow
* When you exit plan mode (or complete a task), you should always first write (or update) your plan to a file in the Docs/ directory. The plan should include both our high level plan at the top of the file, as well as the entire conversation context, file snippets, etc. The high level plan document title should be in the format `YYYY-MM-dd-summarized-title.md`. Ensure that we are always keeping the documents up-to-date with our latest findings. If there is already a document for the current day (Pacific Time), let's continue updating the existing document instead of creating a new one.
* When resuming work, utilize these files to gather additional context about what we were working on. 

### Documentation Structure
Each document should include:
1. **High-Level Plan** - Problem statement, solution overview, key changes
2. **Technical Details** - File modifications, code snippets, command outputs
3. **Context Preservation** - Error messages, debugging steps, decision rationale
4. **Cross-References** - Links to related work sessions or files
5. **Expected Outcomes** - What should work after implementation

### Content Guidelines
* Include full file paths for all modifications
* Preserve exact code snippets and command outputs
* Document both successful and failed approaches
* Capture the reasoning behind technical decisions
* Note any dependencies or prerequisites discovered

### Update Workflow
* **New Session**: Create new document for distinct features/fixes
* **Continuing Work**: Update existing document with latest progress
* **Related Work**: Reference previous documents and build upon them
* **Completion**: Mark final outcomes and any remaining work

## Driving the App / Flow Verification

* To run the app in the simulator and exercise user flows (sanity passes, screenshots, UI bug repro), use the **`drive-app` skill** (`.claude/skills/drive-app/SKILL.md`). It covers XcodeBuildMCP setup, the SwiftUI/PlayaDB feature flag, onboarding automation, and on-device database verification. Physical-device deployment lives in `.claude/skills/drive-app/references/device-deploy.md`.
* Critical-flow scripts live in `.claude/skills/drive-app/references/flows.md`. **Keep them current:** when a change adds or alters a user-facing flow (screens, onboarding steps, permissions, navigation), update the corresponding flow entry in the same change. When driving the app, if reality diverges from the doc, fix the doc in that session.

## Source Control

* **Commit after finishing a validated chunk of work.** Once a coherent unit of work is complete and verified (tests passing, plus an app build when the change could affect the app target), commit it without waiting to be asked. Keep each commit scoped to one logical change with a descriptive message.
* Before committing, check `git status` for unintended changes (e.g. xcodebuild flipping `DEVELOPMENT_TEAM` in the pbxproj — revert those rather than committing them).
* Do NOT push to remotes unless the user asks. Never rewrite history, pull from remote, squash, merge or rebase unless authorized.
* Read-only operations (`git show`, `git log`, `git diff`, etc.) are always fine.

## Development Commands

### Building and Dependencies
- `pod install` - Install CocoaPods dependencies (required after cloning)
- `git submodule update --init` - Initialize git submodules (required after cloning)
- Build via Xcode: Open `iBurn.xcworkspace` (NOT the .xcodeproj file)

### Build/Test Output Parsing (xcsift)

This repo uses `xcsift` to parse and format `xcodebuild` and SwiftPM `swift test` output for coding agents.
Key rule: always redirect stderr to stdout (`2>&1`) before piping into `xcsift`.

Default destination: **iPhone 17 Pro Max, iOS 26.5, arm64 simulator**. Schemes: `iBurn` (app), `iBurnTests`, `PlayaKitTests`.

```bash
DEST='platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5,arch=arm64'

xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination "$DEST" -quiet 2>&1 | xcsift -f toon -w
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination "$DEST" -quiet 2>&1 | xcsift -f toon -w
swift test 2>&1 | xcsift -f toon -w   # SwiftPM targets (PlayaDB, PlayaAPI); may need elevated permissions when sandboxed
```

If xcsift prints "Error: No input provided", xcodebuild likely produced no output (e.g. a fully incremental build with `-quiet`). Re-run without `-quiet`.

### Pre-baked database seed (`playa-seed`)

`iBurn/PlayaDB-<year>.zip` ships a pre-populated PlayaDB so first launch doesn't import
JSON or compute thumbnail colors on device. It is gitignored — regenerate it whenever the
API data or media files change:

```bash
swift run --package-path Packages/PlayaSeed playa-seed --fetch-media
```

`--fetch-media` also downloads any thumbnails the API references but
`Submodules/iBurn-Data/data/<year>/MediaFiles/MediaFiles.bundle` is missing; commit those
in the submodule. `--help` lists the rest (`--year`, `--data-root`, `--output`,
`--skip-colors`). Without a seed the app still works — it falls back to the on-device JSON
import — so a missing zip shows up as a slow first launch, not a build failure.

Colors come from `Packages/PlayaColors`, which the app also uses at runtime, so a baked
color is identical to one the device would compute.

### Testing

When adding new functionality, make sure to plan for testability. When your feature is complete, add tests to validate your business logic, and then ensure they are passing.

## Architecture Overview

### Guidance

Protocolize dependencies and use dependency injection with factory pattern. For example `protocol FooService` and `class FooServiceImpl: FooService`, where the factory builds and returns a `FooService`, obscuring the underlying Impl.

### Required Setup Files
Before building, create these files (they are gitignored, so they won't exist in a fresh clone):
- `iBurn/BRCSecrets.m` - API keys and configuration constants
- `iBurn/InfoPlistSecrets.h` - Preprocessor defines for sensitive data
- `iBurn/crashlytics.sh` - Crashlytics build script (optional)

### Domain Notes
- Location data is embargoed by the Burning Man organization until gates open each year; year-based configuration lives in `YearSettings`.

## Submodule Dependencies

`Submodules/iBurn-Data/` (festival datasets, geospatial data, offline tiles) and its
`scripts/BlackRockCityPlanner/` (GeoJSON generation + Burning Man address geocoding) each
have their own `CLAUDE.md`, which loads automatically when you work in those directories.
Read those for the current data-generation and geocoder-build pipelines.

## CI/CD

GitHub Actions workflows live in `.github/workflows/` (`ci.yml`, `pr.yml`, `deploy.yml`, plus the
Claude review workflows). Secrets are managed through GitHub Secrets — the workflow files list the
exact names required. Deployment is triggered by git tags starting with `v`.

For the Travis → GitHub Actions migration history, see `Docs/2025-07-23-github-actions-migration.md`.

### Fastlane
`fastlane lanes` lists the available lanes (`fastlane/Fastfile`); `beta` uploads to TestFlight.
