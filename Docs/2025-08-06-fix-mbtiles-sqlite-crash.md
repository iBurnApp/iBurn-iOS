# Fix MBTiles SQLite Crash Issue
**Date:** 2025-08-06  
**Branch:** fix-mbtiles-sqlite-crash

## Problem Statement
The app was experiencing SQLite database integrity errors when accessing map.mbtiles directly from the app bundle:
```
BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation: vnode unlinked while in use: /Users/.../iBurn.app/iBurnData_iBurn2025Map.bundle/Map.bundle/map.mbtiles
invalidated open fd: 22 (0x11)
```

iOS was invalidating the file descriptor while SQLite was still using the MBTiles database, causing crashes.

## Solution Overview
Implemented a caching mechanism that copies the MBTiles file from the app bundle to the Application Support directory on first launch. MapLibre now uses the cached copy instead of directly accessing files in the bundle.

## Technical Details

### Files Modified

1. **iBurn/Bundle+iBurn.swift**
   - Added `brc_mapCacheDirectory` property to manage cache directory location
   - Added `brc_cachedMbtilesURL` method to handle MBTiles caching
   - Added `brc_cachedStyleURL` method for style.json location
   - Cache directory structure: `Application Support/iBurn/2025/Map/`

2. **iBurn/MLNMapView+iBurn.swift**
   - Updated `brc_setDefaults` to use `Bundle.brc_cachedMbtilesURL` instead of `Bundle.brc_mbtilesURL`
   - Changed style.json output to use `Bundle.brc_cachedStyleURL`
   - Added cleanup for old style.json in Application Support root

### Implementation Details

**Cache Directory Structure:**
```
Application Support/
└── iBurn/
    └── 2025/
        └── Map/
            ├── map.mbtiles      (260KB, copied from bundle)
            ├── style-light.json (generated for light mode)
            └── style-dark.json  (generated for dark mode)
```

**Key Features:**
- Year-based directory structure for clean separation between festival years
- Automatic directory creation with intermediate directories
- Files marked as excluded from iCloud backup
- Graceful fallback to bundle URL if cache operations fail
- Small file size (260KB) makes copying operation fast

### Code Snippets

**MBTiles Caching Logic:**
```swift
static var brc_cachedMbtilesURL: URL? {
    let cacheDirectory = brc_mapCacheDirectory
    var cachedMbtilesURL = cacheDirectory.appendingPathComponent("map.mbtiles")
    
    // Create directory structure if needed
    try? FileManager.default.createDirectory(at: cacheDirectory, 
                                            withIntermediateDirectories: true)
    
    // Copy from bundle if not cached
    if !FileManager.default.fileExists(atPath: cachedMbtilesURL.path) {
        guard let bundleMbtilesURL = brc_mbtilesURL else { return nil }
        
        do {
            try FileManager.default.copyItem(at: bundleMbtilesURL, to: cachedMbtilesURL)
            
            // Exclude from backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try cachedMbtilesURL.setResourceValues(resourceValues)
        } catch {
            // Fall back to bundle URL
            return bundleMbtilesURL
        }
    }
    
    return cachedMbtilesURL
}
```

## Context Preservation

### Error Messages
The original crash was caused by iOS's file system behavior where accessing SQLite databases directly from the app bundle can lead to file descriptor invalidation. This is a known issue with SQLite on iOS when files are accessed from read-only locations.

### Debugging Steps
1. Identified crash logs showing SQLite integrity errors
2. Researched MapLibre's mbtiles:// scheme requirements (requires absolute paths)
3. Analyzed existing app patterns (BRCMediaDownloader uses similar caching approach)
4. Implemented year-based cache directory structure for organization

### Decision Rationale
- **Year-based directories:** Allows clean separation between festival years and easy cache management
- **Application Support over Caches:** More persistent storage appropriate for map data
- **Fallback to bundle:** Ensures app continues working even if cache operations fail
- **Exclude from backup:** Prevents unnecessary iCloud storage usage

## Expected Outcomes
- SQLite crashes should be eliminated
- Map tiles load from cached location in Application Support
- Style JSON files organized alongside MBTiles in same directory
- Clean upgrade path for future years with separate cache directories

## Build Status
✅ Successfully built with Xcode 16.4 for iPhone 16 Pro simulator

## References
- MapLibre Native requires absolute paths for mbtiles:// scheme
- Similar pattern used in BRCMediaDownloader for media file caching
- iOS file system best practices for SQLite databases