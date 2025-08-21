# Map Pin Duplication Fix

## Date: 2025-08-21

## Problem Statement
Camp and art pins were being duplicated on the map at elevated zoom levels when using the filter mechanism. The duplication occurred because the same data objects appeared in multiple YapDatabase views (art/camps views, visit status views, favorites view), and each view was creating separate annotations for the same underlying object.

## Root Cause Analysis

### Duplication Sources
1. **Multiple Database Views**: Same objects appear in:
   - Main data views (artViewName, campsViewName, eventsViewName)
   - Visit status views (visitedObjectsViewName, wantToVisitObjectsViewName, unvisitedObjectsViewName)
   - Favorites view (everythingFilteredByFavorite)

2. **Ineffective De-duplication**: The existing `filterOutFavorites()` method was an attempt at de-duplication but only handled favorites, not all duplicates.

3. **Aggregation Without Uniqueness Check**: The `allAnnotations()` method was using array append operations without checking for duplicates.

## Solution Overview

Implemented universal dictionary-based de-duplication in `MapViewAdapter` using type-prefixed keys to ensure exactly one annotation per unique object, regardless of data source.

## Technical Implementation

### Files Modified

#### MapViewAdapter.swift
- **Added**: Universal de-duplication at the map presentation layer
- **Key changes**:
  - Added `annotationsByID` dictionary to track all annotations on map
  - Added `keyForAnnotation()` helper for consistent key generation
  - Modified `addAnnotations()` to check for and prevent duplicates
  - Modified `removeAnnotations()` to clean up tracking
  - Updated `reloadAnnotations()` to clear tracking dictionary

#### FilteredMapDataSource.swift
- **Reverted**: Removed dictionary-based de-duplication (now handled by MapViewAdapter)
- **Simplified**: Back to simple array appending since de-duplication happens upstream

### Key Implementation Details

1. **Central Key Generation**:
   ```swift
   private func keyForAnnotation(_ annotation: MLNAnnotation) -> String? {
       if let data = annotation as? DataObjectAnnotation {
           let className = String(describing: type(of: data.object))
           return "\(className):\(data.object.uniqueID)"
       } else if let mapPoint = annotation as? BRCMapPoint {
           let className = String(describing: type(of: mapPoint))
           return "\(className):\(mapPoint.yapKey)"
       }
       return nil // Non-trackable annotations
   }
   ```

2. **Type-Prefixed Keys**:
   - Format: `"ClassName:UniqueID"`
   - Examples:
     - `"BRCArtObject:art-123"`
     - `"BRCCampObject:camp-456"`
     - `"BRCUserMapPoint:2024-08-21-12:34:56"`

3. **De-duplication in addAnnotations()**:
   - Check if key exists in `annotationsByID` dictionary
   - Only add to map if not already present
   - Non-trackable annotations always added

### Architecture Benefits

- **Single Source of Truth**: MapViewAdapter owns what's on the map
- **Universal De-duplication**: Works for ALL data sources (filters, zoom-based, future sources)
- **No Duplicate Logic**: De-duplication logic in one place only
- **Clean Separation**: Data sources focus on filtering, MapViewAdapter handles presentation

## Benefits

1. **Complete De-duplication**: Handles all object types and data sources
2. **Simplicity**: Removed complex filtering logic
3. **Performance**: O(1) dictionary operations
4. **Maintainability**: Clear, single-responsibility code
5. **Debugging**: Type-prefixed keys make it easy to identify objects

## Testing Checklist

- [x] Build succeeds with changes
- [ ] No duplicate pins with all filters enabled
- [ ] Camps appear only once when shown in multiple views
- [ ] Art appears only once when shown in multiple views
- [ ] User map points don't duplicate
- [ ] Favorites still display correctly
- [ ] Event type filtering still works
- [ ] Today's favorites filter still works

## Future Considerations

- Visit status filtering was removed as out of scope but could be re-added if needed
- The dictionary approach scales well for additional data sources
- Type prefixing could be used for debugging/analytics

## Related Issues
- Previous filter implementation: Docs/2025-08-10-map-filter-implementation.md
- This fix simplifies and improves upon the original implementation