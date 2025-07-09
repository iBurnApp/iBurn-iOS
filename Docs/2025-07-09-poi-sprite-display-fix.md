# POI Sprite Display Fix - July 9, 2025

## High-Level Plan

### Problem Statement
After restructuring the iBurn-Data Swift package to use proper `.bundle` directories, POI sprites were not displaying correctly on the map. The root cause was a mismatch between the MapLibre style JSON expectations and the generated data properties.

### Solution Overview
1. **Fix Data Generation Pipeline**: Update BlackRockCityPlanner to output both `name` and `NAME` properties for MapLibre compatibility
2. **Align POI Naming**: Update poi.json names to match MapViewAdapter imageMap expectations  
3. **Regenerate Map Data**: Create new vector tiles with corrected POI layer
4. **Update Documentation**: Reflect new bundle structure paths

### Key Technical Changes
- **Generate Script Enhancement**: Added uppercase `NAME` property generation alongside lowercase `name`
- **POI Name Standardization**: Updated poi.json names to match MapViewAdapter expectations
- **Map Tile Regeneration**: Created new vector tiles with corrected POI layer using proper bundle structure
- **Documentation Updates**: Updated all paths to reflect `.bundle` directory structure

## Technical Details

### Context Preservation
This session continued from a previous conversation about fixing bundle structure issues in the iBurn iOS app after restructuring the iBurn-Data Swift package. The focus was on fixing POI sprite display issues on the map.

#### Previous Context
- Bundle code signing issues were resolved after restructuring to use proper `.bundle` directories
- Map tiles weren't showing up after bundle restructure
- Asset URLs in style JSON files were incorrect
- Sprites weren't displaying despite asset:// scheme working for glyphs
- MBTiles were missing `points` and `toilets` vector layers
- The real issue was that poi.json naming conventions didn't match the 2024 official dataset

#### Key Insight
The critical discovery was that the MapLibre style JSON uses `{NAME}` placeholders (uppercase) but the generated points.geojson only contained `name` (lowercase) properties.

### Files Modified

#### 1. `/Submodules/iBurn-Data/scripts/BlackRockCityPlanner/src/cli/generate_all.js`
**Purpose**: Added uppercase NAME property for MapLibre compatibility
**Change**: Lines 52-55
```javascript
// Added uppercase NAME property for MapLibre compatibility
if (poi.properties.name) {
    point.properties.NAME = poi.properties.name;
}
```

#### 2. `/Submodules/iBurn-Data/data/2025/layouts/poi.json`
**Purpose**: Updated POI names to match MapViewAdapter expectations
**Changes**:
- "Center Camp" → "Center Camp Plaza"
- "Black Rock City Airport" → "Airport"
- "First Aid (Main)" → "Rampart"
- "First Aid (3:00)" → "Station 3"
- "First Aid (9:00)" → "Station 9"
- "Ranger Outpost (Berlin)" → "Ranger Station Berlin"
- "Ranger Outpost (Tokyo)" → "Ranger Station Tokyo"
- "Burner Express Bus" → "Burner Express Bus Depot"
- Added ice location names based on time positions:
  - 2:58 → "Ice Cubed Arctica 3"
  - 6:14 → "Arctica Center Camp"
  - 8:56 → "Ice Nine Arctica"

#### 3. `/Submodules/iBurn-Data/CLAUDE.md`
**Purpose**: Updated documentation to reflect correct bundle structure paths
**Changes**: Updated all paths to use `Map.bundle/` subdirectory structure and added note about `NAME` property requirement

### Commands Executed

1. **Regenerate GeoJSON data**:
   ```bash
   cd /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/scripts/BlackRockCityPlanner
   node src/cli/generate_all.js -d ../../data/2025
   ```

2. **Regenerate map tiles**:
   ```bash
   cd /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data
   tippecanoe --output=data/2025/Map/Map.bundle/map.mbtiles -f \
     -L fence:data/2025/geo/fence.geojson \
     -L outline:data/2025/geo/outline.geojson \
     -L polygons:data/2025/geo/polygons.geojson \
     -L streets:data/2025/geo/streets.geojson \
     -L toilets:data/2025/geo/toilets.geojson \
     -L points:data/2025/geo/points.geojson \
     -L dmz:data/2025/geo/dmz.geojson \
     -z 14 -Z 4 -B0
   ```

### Bundle Structure Architecture
The solution maintains the Swift Package Manager bundle structure:
```
data/2025/Map/
├── iBurn2025Map.swift
└── Map.bundle/
    ├── map.mbtiles        # Contains points layer for POI sprites
    ├── sprites/
    │   ├── sprite.json
    │   └── sprite.png
    ├── glyphs/
    └── styles/
        ├── iburn-light.json
        └── iburn-dark.json
```

### MapViewAdapter Integration
The MapViewAdapter (`/iBurn/MapViewAdapter.swift`) has a hardcoded `imageMap` dictionary:
```swift
let imageMap = [
    "Airport": "airport",
    "Rampart": "EmergencyClinic",
    "Center Camp Plaza": "centerCamp",
    "Station 3": "firstAid",
    "Station 9": "firstAid",
    "Ranger Station Berlin": "ranger",
    "Ranger Station Tokyo": "ranger",
    "Ranger HQ": "ranger",
    "Ice Nine Arctica": "ice",
    "Arctica Center Camp": "ice",
    "Ice Cubed Arctica 3": "ice",
    "The Temple": "temple",
    "Burner Express Bus Depot": "bus",
    "Greeters": "greeters",
    // ... etc
]
```

### Style JSON Configuration
The style JSON files use uppercase `NAME` placeholders:
```json
{
  "icon-image": "{NAME}",
  "text-field": "{NAME}",
  "filter": ["!in", "NAME", "The Man", "Will Call Lot"]
}
```

### Bundle Abstraction Layer
The solution maintains the Bundle+iBurn.swift abstraction layer:
```swift
extension Bundle {
    static var brc_dataBundle: Bundle { return iBurn2025APIData.bundle }
    static var brc_mapBundle: Bundle { return iBurn2025Map.bundle }
    static var brc_mediaBundle: Bundle { return iBurn2025MediaFiles.bundle }
}
```

### Data Flow Architecture
1. **poi.json** → Source data with POI locations and names
2. **generate_all.js** → Geocodes addresses and generates GeoJSON with both `name` and `NAME` properties
3. **points.geojson** → Contains POI features with proper naming
4. **tippecanoe** → Converts GeoJSON to MBTiles vector tiles
5. **map.mbtiles** → Contains `points` layer for MapLibre rendering
6. **MapViewAdapter** → Maps POI names to sprite images at runtime

### Problem Resolution Steps
1. **Identified naming mismatch**: POI names in poi.json didn't match MapViewAdapter expectations
2. **Discovered case sensitivity**: Style JSON needed uppercase `NAME` properties
3. **Fixed generation script**: Added uppercase `NAME` property generation
4. **Updated source data**: Corrected POI names in poi.json
5. **Regenerated pipeline**: Created new GeoJSON and vector tiles
6. **Updated documentation**: Reflected current bundle structure

## Cross-References
- Related to previous bundle restructuring work that resolved code signing issues
- Builds upon Bundle+iBurn.swift abstraction layer implementation
- Connected to MapLibre style JSON configuration and asset URL fixes

## Expected Outcomes
- POI sprites should now display correctly in the iOS app
- Proper icon mapping based on corrected names and uppercase `NAME` properties
- MapLibre style compatibility with `{NAME}` placeholders
- Consistent bundle structure across all iBurn-Data components

### Future Considerations
- Consider adding validation tests for POI name consistency
- Monitor for any additional missing POI types in the MapViewAdapter imageMap
- Ensure the data generation pipeline maintains both `name` and `NAME` properties for future years
- Test POI sprite display in iOS app to verify fix is working
- Verify all expected POI icons are showing correctly