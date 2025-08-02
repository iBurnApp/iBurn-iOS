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

## Planning

When working in plan mode, we can consult Gemini 2.5 Pro with `gemini -p "example prompt"` command. This model has a large context window (1M tokens) and is especially helpful when iterating on architecture decisions and proposed code changes. After you've come up with a solid plan, consult Gemini for feedback (or at any time when prompted by the user).

## Source Control

IMPORTANT: After completing a task (and updating our documentation), we should always commit our changes. Only perform safe operations like `git add` and `git commit`. Never attempt to rewrite history, pull from remote, squash, merge or rebase.

## Project Overview

iBurn is an offline map and guide for the Burning Man art festival. It's a native iOS application built primarily with Swift and Objective-C, featuring offline map tiles, art/camp/event data management, and location tracking capabilities.

## Project Details

**Key Project Information**:
- **Workspace Path**: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace`
- **Main Scheme**: `iBurn` (for building the app)
- **Test Schemes**: `iBurnTests`, `PlayaKitTests` 
- **Default Destination**: iPhone 16 Pro (arm64 simulator)
- **Active Branch**: Check with `git status` as development happens on feature branches

### Project Discovery

Start new sessions by exploring the project structure:

```bash
# List available schemes
xcodebuild -workspace iBurn.xcworkspace -list

# List available simulators
xcrun simctl list devices available

# Check workspace structure
open iBurn.xcworkspace  # Opens in Xcode for scheme inspection
```

## Development Commands

### Building and Dependencies
- `pod install` - Install CocoaPods dependencies (required after cloning)
- `git submodule update --init` - Initialize git submodules (required after cloning)
- Build via Xcode: Open `iBurn.xcworkspace` (NOT the .xcodeproj file)

### Build Commands

**Preferred Build Command (quiet, arm64 simulator)**:
```bash
# Build for iOS Simulator with quiet output
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64' -quiet

# Build and show all output (for debugging)
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -destination 'platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64'
```

**Testing Commands**:
```bash
# Run tests on simulator with quiet output
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64' -quiet

# Run tests with full output (for debugging)
xcodebuild test -workspace iBurn.xcworkspace -scheme iBurnTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64'

# Run PlayaKit tests
xcodebuild test -workspace iBurn.xcworkspace -scheme PlayaKitTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro,arch=arm64' -quiet
```

**Utility Commands**:
```bash
# Clean build products
xcodebuild clean -workspace iBurn.xcworkspace -scheme iBurn

# Show build settings
xcodebuild -workspace iBurn.xcworkspace -scheme iBurn -showBuildSettings
```

### Simulator Management

Basic simulator control using standard tools:

```bash
# List available simulators
xcrun simctl list devices available

# Boot a simulator
xcrun simctl boot "iPhone 16 Pro"

# Open Simulator app
open -a Simulator

# Shutdown simulator
xcrun simctl shutdown "iPhone 16 Pro"

# Erase simulator content
xcrun simctl erase "iPhone 16 Pro"
```




### Fastlane Commands
- `fastlane ios beta` - Build and upload to TestFlight
- `fastlane ios refresh_dsyms` - Download and upload crash symbols

### Testing
- **Command Line**: Use xcodebuild test commands shown above for automated testing
- **Xcode GUI**: Run tests through Xcode Test Navigator or `Cmd+U`  
- **Test targets**: `iBurnTests`, `PlayaKitTests`

## Architecture Overview

### Guidance

Protocolize dependencies and use dependency injection with factory pattern. For example `protocol FooService` and `class FooServiceImpl: FooService`, where the factory builds and returns a `FooService`, obscuring the underlying Impl.

### Core Components

**Database Layer (YapDatabase)**
- Primary data storage using YapDatabase (key-value database)
- Database manager: `BRCDatabaseManager` (Obj-C) with Swift extensions
- Data objects inherit from `BRCYapDatabaseObject` and conform to YAP protocols
- Background/UI connection separation for performance

**Data Models**
- `BRCDataObject` - Base class for all data objects (Art, Camps, Events)
- `BRCArtObject`, `BRCCampObject`, `BRCEventObject` - Specific data types
- `BRCUpdateInfo` - Manages data updates and versioning
- Data import handled by `BRCDataImporter` (both Obj-C and Swift versions)

**Map System (MapLibre)**
- Uses MapLibre for offline map rendering (migrated from Mapbox)
- `BaseMapViewController` - Base map functionality
- `MainMapViewController` - Primary map interface
- `MapViewAdapter` and `UserMapViewAdapter` - Map interaction handling
- Custom annotation views: `ImageAnnotationView`, `LabelAnnotationView`

**UI Architecture**
- Mix of UIKit (programmatic and Storyboard) with some SwiftUI adoption
- `TabController` - Root tab bar controller with theme management
- Table view adapters: `YapTableViewAdapter` for database-driven lists
- Custom table cells for different data types with corresponding XIB files

**Location Services**
- `BRCLocations` - Centralized location management
- `CLLocationManager+iBurn` - Location utilities
- User tracking with breadcrumb trail functionality

**Data Management**
- Year-based configuration via `YearSettings`
- Embargo system for restricted data access
- Background data downloads and updates
- Offline-first approach with optional data syncing

### Key Frameworks
- **YapDatabase** - Local database storage
- **MapLibre** - Map rendering and offline tiles  
- **Mantle** - Object serialization/deserialization
- **CocoaLumberjack** - Logging
- **Firebase** - Analytics and crash reporting
- **Anchorage** - Auto Layout helpers

### File Organization
- `/iBurn/` - Main application code
  - Core data objects and managers
  - View controllers and UI components
  - Map-related functionality
  - Utility extensions and helpers
- `/PlayaKit/` - Shared data models and protocols
- `/Submodules/` - Git submodules for custom dependencies
- `/Pods/` - CocoaPods dependencies

### Required Setup Files
Before building, create these files:
- `iBurn/BRCSecrets.m` - API keys and configuration constants
- `iBurn/InfoPlistSecrets.h` - Preprocessor defines for sensitive data
- `iBurn/crashlytics.sh` - Crashlytics build script (optional)

### Development Notes
- The app supports both light and dark themes via `Appearance` system
- Heavy use of Objective-C categories for extending system classes
- Mix of programmatic UI and Interface Builder (XIB files)
- Database views are used extensively for filtered/sorted data presentation
- Location data is embargoed by Burning Man organization until gates open each year

## Submodule Dependencies

### iBurn-Data (`/Submodules/iBurn-Data/`)
Data repository containing yearly festival datasets, geospatial data, and processing scripts for offline map tiles, art/camp/event data, and Black Rock City layout geometry.

**Key Features:**
- Year-based data structure (`data/YYYY/`) with APIData, geo/, layouts/, Map/, and MediaFiles/
- Burning Man's unique time-based addressing system (12:00, 1:00, etc.)
- GeoJSON generation for streets, plazas, toilets, and city boundaries
- Offline MBTiles for mobile map consumption
- Data embargo system (location data restricted until gates open)

**Common Commands:**
```bash
cd Submodules/iBurn-Data/scripts/BlackRockCityPlanner
npm install
node src/cli/generate_all.js -d ../../data/2024
```

### BlackRockCityPlanner (`/Submodules/iBurn-Data/scripts/BlackRockCityPlanner/`)
Node.js geospatial tool that generates GeoJSON files for Black Rock City's unique radial layout and provides geocoding for Burning Man addresses.

**Key Features:**
- Generates radial street grids based on clock positions (3:00 & 500')
- Geocodes user addresses to coordinates with fuzzy matching
- Creates city geometry: streets, polygons, fence, toilets
- Handles special locations (Center Camp Plaza, Man Base)
- Uses Turf.js v3.x and JSTS for geospatial operations

**Common Commands:**
```bash
npm test  # Run geocoding and geometry tests
node src/cli/api.js -l layout.json -f camp.json -k location_string -o camp-location.json
browserify src/geocoder/index.js -o bundle.js
```

**Address Formats Supported:**
- Time-based: "3:00 & 500'" (radial position + distance)
- Intersections: "Esplanade & 6:00" (named street + time)
- Special locations: "Center Camp Plaza", "9:00 Portal"

## CI/CD with GitHub Actions

The project uses GitHub Actions for continuous integration and deployment. This replaced the legacy Travis CI setup in July 2025 with modern macOS runners and enhanced security.

### Workflow Overview

**Three main workflows handle different aspects of CI/CD:**

1. **`.github/workflows/ci.yml`** - Main CI pipeline for master/develop branches
2. **`.github/workflows/pr.yml`** - Lightweight validation for pull requests  
3. **`.github/workflows/deploy.yml`** - Deployment to TestFlight

### Infrastructure Details

- **Runners:** macOS 14 with Xcode 16.4 (latest stable)
- **Simulators:** iPhone 15 Pro with latest iOS
- **Ruby:** Version 3.1 with bundler caching
- **Dependencies:** CocoaPods with intelligent caching
- **Parallel Execution:** Build and test schemes run concurrently

### Security & Secrets

All sensitive data is managed through GitHub Secrets:

```bash
# Required Secrets for CI
MAPBOX_ACCESS_TOKEN
CRASHLYTICS_API_TOKEN
HOCKEY_BETA_IDENTIFIER
HOCKEY_LIVE_IDENTIFIER
EMBARGO_PASSCODE_SHA256
UPDATES_URL
MAPBOX_STYLE_URL

# Additional Secrets for Deployment
APP_STORE_CONNECT_API_KEY
APP_STORE_CONNECT_API_KEY_ID
APP_STORE_CONNECT_API_ISSUER_ID
GOOGLE_SERVICE_INFO_PLIST
BUILD_CERTIFICATE_BASE64
P12_PASSWORD
BUILD_PROVISION_PROFILE_BASE64
KEYCHAIN_PASSWORD
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
FASTLANE_SESSION
MATCH_PASSWORD
```

### Workflow Triggers

**Automatic Triggers:**
- **CI:** All pushes to master/develop, all pull requests
- **PR:** Pull request open/sync/reopen (lightweight validation only)
- **Deploy:** Git tags starting with 'v' (e.g., v1.2.3)

**Manual Triggers:**
- All workflows support manual dispatch via "Run workflow" button
- Deploy workflow allows choosing Fastlane lane (beta, refresh_dsyms)

### Performance Optimizations

- **Intelligent Caching:** Ruby gems and CocoaPods cached across runs
- **Parallel Execution:** Build matrix allows concurrent scheme testing
- **Artifact Storage:** Test results and build logs preserved for debugging
- **Optimized Dependencies:** Concurrent installation with retry logic

### Monitoring & Debugging

**Workflow Monitoring:**
- View all workflows in repository Actions tab
- Real-time logs with timestamps and step-by-step execution
- Build artifacts and test results preserved (30 days for CI, 7 days for PRs)

**Test Analysis:**
- XCResult files uploaded as artifacts for detailed analysis
- Test failures include full logs and error context
- PR workflows automatically comment build status

**Common Debugging Steps:**
1. Check workflow logs in GitHub Actions tab
2. Download test result artifacts for detailed analysis
3. Verify GitHub Secrets are properly configured
4. Check for CocoaPods or dependency issues in setup steps

### Migration Notes

**Replaced:** Legacy `.travis.yml` configuration (Xcode 12.3, basic security)
**Enhanced:** Modern infrastructure (Xcode 16.4), secure secrets, parallel execution, comprehensive testing
**Added:** PR validation, automated deployment, intelligent caching, detailed reporting

For complete migration details, see `Docs/2025-07-23-github-actions-migration.md`.
