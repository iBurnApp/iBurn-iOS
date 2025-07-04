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