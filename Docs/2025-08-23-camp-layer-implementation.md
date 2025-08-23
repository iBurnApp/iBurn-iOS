# Camp Boundary and Label Layers Implementation

## Date: 2025-08-23

## Summary
Successfully implemented two new toggleable map layers for camp boundaries and camp labels (big) in the iBurn iOS app. The layers display polyline-based camp outlines and text shapes from provided GeoJSON files.

## Implementation Details

### Files Modified

1. **Style JSON Files**
   - `/Submodules/iBurn-Data/data/2025/Map/Map.bundle/styles/iburn-light.json`
   - `/Submodules/iBurn-Data/data/2025/Map/Map.bundle/styles/iburn-dark.json`
   - Added GeoJSON sources for camp boundaries and labels
   - Added line layers with appropriate styling for light/dark themes
   - Set default visibility to "visible" (matching UserSettings defaults)

2. **UserSettings.swift**
   - Added `showCampBoundaries` property (defaults to true)
   - Added `showBigCampNames` property (defaults to true)
   - Properties persist to UserDefaults

3. **MapLayerManager.swift** (New File)
   - Created manager class to handle runtime layer visibility
   - Updates layer visibility based on UserSettings
   - Integrated with MapLibre's MLNStyle API

4. **MapFilterView.swift**
   - Added UI section "Camp Display" with two toggles
   - Updated view model to sync with UserSettings
   - Connected toggles to save settings on change

5. **BaseMapViewController.swift**
   - Added `mapLayerManager` property
   - Implemented MLNMapViewDelegate to handle style loading
   - Updates layer visibility when style finishes loading

6. **MainMapViewController.swift**
   - Updates layers when filter settings change
   - Calls `mapLayerManager?.updateAllLayers()` after filter updates

### GeoJSON Data
- **camp_outlines.geojson** (2.3 MB) - Camp boundary polylines
- **camp_labels.geojson** (48.8 MB) - Camp name polylines (letter shapes)
- Files copied to `/Submodules/iBurn-Data/data/2025/Map/Map.bundle/`

### Layer Configuration

#### Light Theme Colors
- Camp boundaries: `#8B7BA6` with 60% opacity
- Camp labels: `#4A4A4A` with 80% opacity

#### Dark Theme Colors
- Camp boundaries: `#9B8DB0` with 70% opacity
- Camp labels: `#D4D4D4` with 90% opacity

### Technical Notes

1. **Polyline Rendering**: Both layers use LineString geometry to draw shapes
   - Camp boundaries are closed polylines forming outlines
   - Camp labels are polylines that draw letter shapes

2. **Default Visibility**: Set to true for both layers to match UserSettings defaults

3. **Layer Order**: Positioned after outline layer but before street labels for proper visual hierarchy

4. **Performance**: Large GeoJSON files (especially camp_labels.geojson at 48MB) load efficiently as they're referenced by URL rather than embedded

## Testing Performed

- ✅ Project builds successfully
- ✅ No compilation errors
- ✅ Map filter UI shows new toggle switches
- ✅ Settings persist to UserDefaults
- ✅ Layers toggle visibility when settings change

## Future Enhancements

1. **Regular Camp Names Layer**: Add traditional text-based camp names when data becomes available
2. **Zoom-Based Visibility**: Consider hiding labels at low zoom levels to reduce clutter
3. **Performance Optimization**: Monitor performance with large GeoJSON files, consider simplification if needed
4. **Camp Information**: Could link camp boundaries to tap interactions for showing camp details

## Known Issues

None identified during implementation.

## Files Added to Xcode Project

- MapLayerManager.swift (manually added to project file after creation)