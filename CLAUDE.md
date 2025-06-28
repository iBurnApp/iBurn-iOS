# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iBurn is an offline map and guide for the Burning Man art festival. It's a native iOS application built primarily with Swift and Objective-C, featuring offline map tiles, art/camp/event data management, and location tracking capabilities.

## Development Commands

### Building and Dependencies
- `pod install` - Install CocoaPods dependencies (required after cloning)
- `git submodule update --init` - Initialize git submodules (required after cloning)
- Build via Xcode: Open `iBurn.xcworkspace` (NOT the .xcodeproj file)

### Fastlane Commands
- `fastlane ios beta` - Build and upload to TestFlight
- `fastlane ios refresh_dsyms` - Download and upload crash symbols

### Testing
- Run tests through Xcode Test Navigator or `Cmd+U`
- Test targets: `iBurnTests`, `PlayaKitTests`

## Architecture Overview

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