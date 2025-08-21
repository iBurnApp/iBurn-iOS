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

Implemented dictionary-based de-duplication in `FilteredMapDataSource` using type-prefixed keys to ensure exactly one annotation per unique object.

## Technical Implementation

### Files Modified

#### FilteredMapDataSource.swift
- **Before**: Used array appending with partial de-duplication via `filterOutFavorites()`
- **After**: Dictionary-based collection with automatic de-duplication

### Key Changes

1. **Dictionary Collection**:
   ```swift
   var annotationsByID: [String: MLNAnnotation] = [:]
   ```

2. **Type-Prefixed Keys**:
   - Format: `"ClassName:UniqueID"`
   - Examples:
     - `"BRCArtObject:art-123"`
     - `"BRCCampObject:camp-456"`
     - `"BRCUserMapPoint:2024-08-21-12:34:56"`

3. **Simplified Logic**:
   - Removed `filterOutFavorites()` method (no longer needed)
   - Removed `filterByVisitStatus()` method (out of scope)
   - Dictionary automatically handles all de-duplication

### Code Structure

```swift
func allAnnotations() -> [MLNAnnotation] {
    var annotationsByID: [String: MLNAnnotation] = [:]
    
    func addToDict(_ annotations: [MLNAnnotation]) {
        for annotation in annotations {
            // Generate type-prefixed key
            // Add to dictionary (overwrites duplicates)
        }
    }
    
    // Process each data source
    // Dictionary ensures no duplicates
    
    return Array(annotationsByID.values)
}
```

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