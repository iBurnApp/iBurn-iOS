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

## XcodeBuildMCP Integration

This project uses XcodeBuildMCP for comprehensive Xcode build automation and iOS development workflows. The MCP provides 84 tools covering project management, building, testing, simulator control, and UI automation.

**Key Project Details**:
- **Workspace Path**: `/Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace`
- **Main Scheme**: `iBurn` (for building the app)
- **Test Schemes**: `iBurnTests`, `PlayaKitTests` 
- **Default Destination**: iPhone 16 Pro (arm64 simulator)
- **Active Branch**: Check with `git status` as development happens on feature branches

### Project Discovery

Start new sessions by discovering available projects and schemes:

```bash
# Discover Xcode projects and workspaces
mcp__XcodeBuildMCP__discover_projs --workspaceRoot /Users/chrisbal/Documents/Code/iBurn-iOS

# List available schemes in workspace
mcp__XcodeBuildMCP__list_schems_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace

# List available iOS simulators
mcp__XcodeBuildMCP__list_sims --enabled true

# List connected physical devices
mcp__XcodeBuildMCP__list_devices
```

## Development Commands

### Building and Dependencies
- `pod install` - Install CocoaPods dependencies (required after cloning)
- `git submodule update --init` - Initialize git submodules (required after cloning)
- Build via Xcode: Open `iBurn.xcworkspace` (NOT the .xcodeproj file)

### Building with XcodeBuildMCP
XcodeBuildMCP provides comprehensive build automation with better error reporting and simplified syntax compared to raw xcodebuild commands.

**Build Commands**:
```bash
# Build for macOS
mcp__XcodeBuildMCP__build_mac_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn

# Build for iOS Simulator (by name)
mcp__XcodeBuildMCP__build_sim_name_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn --simulatorName "iPhone 16 Pro"

# Build for iOS Simulator (by UUID)
mcp__XcodeBuildMCP__build_sim_id_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn --simulatorId "SIMULATOR_UUID"

# Build for physical device
mcp__XcodeBuildMCP__build_dev_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn

# Build and run in one command
mcp__XcodeBuildMCP__build_run_sim_name_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn --simulatorName "iPhone 16 Pro"
```

**Testing Commands**:
```bash
# Run tests on simulator (by name)
mcp__XcodeBuildMCP__test_sim_name_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurnTests --simulatorName "iPhone 16 Pro"

# Run tests on simulator (by UUID)
mcp__XcodeBuildMCP__test_sim_id_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurnTests --simulatorId "SIMULATOR_UUID"

# Run tests on physical device
mcp__XcodeBuildMCP__test_device_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurnTests --deviceId "DEVICE_UUID"

# Run macOS tests
mcp__XcodeBuildMCP__test_macos_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurnTests
```

**Utility Commands**:
```bash
# Clean build products
mcp__XcodeBuildMCP__clean_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn

# Show build settings
mcp__XcodeBuildMCP__show_build_set_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn
```

### Simulator Management

XcodeBuildMCP provides comprehensive simulator control:

```bash
# Boot a simulator
mcp__XcodeBuildMCP__boot_sim --simulatorUuid "SIMULATOR_UUID"

# Open Simulator app
mcp__XcodeBuildMCP__open_sim --enabled true

# Set appearance mode (dark/light)
mcp__XcodeBuildMCP__set_sim_appearance --simulatorUuid "SIMULATOR_UUID" --mode dark

# Set custom GPS location
mcp__XcodeBuildMCP__set_simulator_location --simulatorUuid "SIMULATOR_UUID" --latitude 37.7749 --longitude -122.4194

# Reset location to default
mcp__XcodeBuildMCP__reset_simulator_location --simulatorUuid "SIMULATOR_UUID"

# Simulate network conditions
mcp__XcodeBuildMCP__set_network_condition --simulatorUuid "SIMULATOR_UUID" --profile "3g"

# Reset network conditions
mcp__XcodeBuildMCP__reset_network_condition --simulatorUuid "SIMULATOR_UUID"
```

### Swift Package Manager Integration

XcodeBuildMCP includes comprehensive Swift Package Manager support:

```bash
# Build a Swift package
mcp__XcodeBuildMCP__swift_package_build --packagePath /path/to/package --configuration debug

# Run Swift package tests
mcp__XcodeBuildMCP__swift_package_test --packagePath /path/to/package --parallel true

# Run executable target
mcp__XcodeBuildMCP__swift_package_run --packagePath /path/to/package --executableName myapp --arguments ["arg1", "arg2"]

# Stop running Swift package executable
mcp__XcodeBuildMCP__swift_package_stop --pid 12345

# List running Swift package processes
mcp__XcodeBuildMCP__swift_package_list

# Clean Swift package build artifacts
mcp__XcodeBuildMCP__swift_package_clean --packagePath /path/to/package
```

### App Lifecycle Management

Install, launch, and manage apps on simulators and devices:

```bash
# Get app bundle paths
mcp__XcodeBuildMCP__get_sim_app_path_name_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn --platform "iOS Simulator" --simulatorName "iPhone 16 Pro"
mcp__XcodeBuildMCP__get_device_app_path_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn
mcp__XcodeBuildMCP__get_mac_app_path_ws --workspacePath /Users/chrisbal/Documents/Code/iBurn-iOS/iBurn.xcworkspace --scheme iBurn

# Get bundle IDs from app paths
mcp__XcodeBuildMCP__get_app_bundle_id --appPath /path/to/app.app
mcp__XcodeBuildMCP__get_mac_bundle_id --appPath /path/to/app.app

# Simulator app management
mcp__XcodeBuildMCP__install_app_sim --simulatorUuid "SIMULATOR_UUID" --appPath /path/to/app.app
mcp__XcodeBuildMCP__launch_app_sim --simulatorUuid "SIMULATOR_UUID" --bundleId com.example.app
mcp__XcodeBuildMCP__launch_app_logs_sim --simulatorUuid "SIMULATOR_UUID" --bundleId com.example.app
mcp__XcodeBuildMCP__stop_app_sim --simulatorUuid "SIMULATOR_UUID" --bundleId com.example.app

# Device app management
mcp__XcodeBuildMCP__install_app_device --deviceId "DEVICE_UUID" --appPath /path/to/app.app
mcp__XcodeBuildMCP__launch_app_device --deviceId "DEVICE_UUID" --bundleId com.example.app
mcp__XcodeBuildMCP__stop_app_device --deviceId "DEVICE_UUID" --processId 12345

# macOS app management
mcp__XcodeBuildMCP__launch_mac_app --appPath /path/to/app.app --args ["arg1", "arg2"]
mcp__XcodeBuildMCP__stop_mac_app --appName "MyApp"
```

### UI Automation and Testing

XcodeBuildMCP provides powerful UI automation capabilities for testing:

```bash
# Get UI hierarchy and element coordinates
mcp__XcodeBuildMCP__describe_ui --simulatorUuid "SIMULATOR_UUID"

# UI interactions (use describe_ui to get precise coordinates)
mcp__XcodeBuildMCP__tap --simulatorUuid "SIMULATOR_UUID" --x 200 --y 300
mcp__XcodeBuildMCP__long_press --simulatorUuid "SIMULATOR_UUID" --x 200 --y 300 --duration 1000
mcp__XcodeBuildMCP__swipe --simulatorUuid "SIMULATOR_UUID" --x1 100 --y1 200 --x2 100 --y2 100

# Text input and keyboard interactions
mcp__XcodeBuildMCP__type_text --simulatorUuid "SIMULATOR_UUID" --text "Hello World"
mcp__XcodeBuildMCP__key_press --simulatorUuid "SIMULATOR_UUID" --keyCode 40  # Return key
mcp__XcodeBuildMCP__key_sequence --simulatorUuid "SIMULATOR_UUID" --keyCodes [40, 42, 44]  # Return, Backspace, Space

# Hardware button interactions
mcp__XcodeBuildMCP__button --simulatorUuid "SIMULATOR_UUID" --buttonType home
mcp__XcodeBuildMCP__button --simulatorUuid "SIMULATOR_UUID" --buttonType siri

# Gesture presets
mcp__XcodeBuildMCP__gesture --simulatorUuid "SIMULATOR_UUID" --preset scroll-up
mcp__XcodeBuildMCP__gesture --simulatorUuid "SIMULATOR_UUID" --preset swipe-from-left-edge

# Screenshots for visual verification
mcp__XcodeBuildMCP__screenshot --simulatorUuid "SIMULATOR_UUID"

# Log capture
mcp__XcodeBuildMCP__start_sim_log_cap --simulatorUuid "SIMULATOR_UUID" --bundleId com.example.app
mcp__XcodeBuildMCP__stop_sim_log_cap --logSessionId "SESSION_ID"
mcp__XcodeBuildMCP__start_device_log_cap --deviceId "DEVICE_UUID" --bundleId com.example.app
mcp__XcodeBuildMCP__stop_device_log_cap --logSessionId "SESSION_ID"
```

### Fastlane Commands
- `fastlane ios beta` - Build and upload to TestFlight
- `fastlane ios refresh_dsyms` - Download and upload crash symbols

### Testing
- **XcodeBuildMCP**: Use testing commands for automated testing with precise error reporting
- **Xcode GUI**: Run tests through Xcode Test Navigator or `Cmd+U`  
- **Test targets**: `iBurnTests`, `PlayaKitTests`
- **UI Testing**: Use XcodeBuildMCP's UI automation tools for comprehensive app testing

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
