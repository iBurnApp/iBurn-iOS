# Plaza Geocoding Bug Fix - August 5, 2025

## Problem Statement
Camps placed at plaza addresses (e.g., "4:30 G Plaza @ 2:15") were being incorrectly geocoded. Specifically:
- Camps at G Plaza addresses were being placed at B Plaza distances (~3220 feet instead of ~4825 feet)
- The fuzzy matching algorithm was returning both "4:30 B Plaza" and "4:30 G Plaza" with identical match scores
- The geocoder was arbitrarily selecting the first match, often resulting in the wrong plaza

## Root Cause Analysis

### Discovery Process
1. User reported camps appearing at wrong plazas on the map
2. Created distance validation tests comparing camp distances to expected street distances
3. Found that all plaza addresses were geocoding to ~3220-3380 feet regardless of street letter
4. Traced issue to `forward.js` fuzzy matching logic

### Technical Details
The issue was in the `plazaTimeToLatLon` function in `src/geocoder/forward.js`:
- Used `fuzzyMatchFeatures` to find plaza polygons
- Fuzzy matching gave identical scores (0.166...) to both "4:30 B Plaza" and "4:30 G Plaza"
- Code took first match (`plazaFeatures[0]`), which was unpredictable

## Solution Implemented

### Code Changes
Modified `plazaTimeToLatLon` in `forward.js` to:
1. First attempt exact name matching (case-insensitive)
2. If no exact match, use fuzzy matching with street letter preference
3. When multiple fuzzy matches have same score, prefer the one containing the correct street letter
4. Added plaza name normalization to handle "PLAZA" vs "Plaza" case variations

### Key Fix (forward.js:214-252)
```javascript
// First try exact name matching
var plazaNameLower = plazaName.toLowerCase().trim();
var exactMatch = null;

for (var i = 0; i < this.features.length; i++) {
  var feature = this.features[i];
  if (feature.properties.name && feature.properties.name.toLowerCase() === plazaNameLower) {
    exactMatch = feature;
    break;
  }
}

var plaza = exactMatch;

// If no exact match, try fuzzy matching as fallback
if (!plaza) {
  var plazaFeatures = this.fuzzyMatchFeatures(['name', 'ref'], plazaName);
  if (plazaFeatures.length > 0) {
    // If multiple matches with same score, prefer the one that contains the exact street letter
    if (plazaFeatures.length > 1 && plazaFeatures[0].properties.match === plazaFeatures[1].properties.match) {
      // Extract street letter from plaza name (e.g., "G" from "4:30 G Plaza")
      var streetMatch = plazaName.match(/\b([A-L])\s+Plaza\b/i);
      if (streetMatch) {
        var streetLetter = streetMatch[1].toUpperCase();
        for (var j = 0; j < plazaFeatures.length; j++) {
          if (plazaFeatures[j].properties.name && 
              plazaFeatures[j].properties.name.includes(streetLetter + " Plaza")) {
            plaza = plazaFeatures[j];
            break;
          }
        }
      }
    }
    // If still no match or no street letter, take the first fuzzy match
    if (!plaza) {
      plaza = plazaFeatures[0];
    }
  }
}
```

## Testing Results

### Test Coverage
- Created `PlazaGeocodingTest.js` - Comprehensive tests for all plaza formats
- Created `PlazaDistanceTest.js` - Validates camps are at correct radial distances
- Created `TestRealCampData.js` - Tests with actual 2025 camp data

### Results
- All G Plaza camps now geocode to ~4825 feet (±150 feet tolerance)
- All B Plaza camps geocode to ~3220 feet (±150 feet tolerance)
- 100% success rate on real 2025 camp data
- Handles various formats: "@" vs "&", "PLAZA" vs "Plaza"

### Sample Test Output
```
Camp Name                      | Address                   | Expected Distance | Actual Distance | Status
Example 1                 | 4:30 G Plaza @ 2:15       | 4825 ft           | 4864 ft         | ✓ PASS
Example 2                  | 4:30 G Plaza @ 7:00       | 4825 ft           | 4852 ft         | ✓ PASS
Example 3     | 4:30 B Plaza @ 1:00       | 3220 ft           | 3196 ft         | ✓ PASS
```

## Impact
- Fixes incorrect plaza placement for all camps with plaza addresses
- Ensures camps appear at correct locations on iBurn iOS map
- Improves navigation accuracy for festival attendees

## Files Modified
- `/src/geocoder/forward.js` - Added exact matching and street letter preference logic
- `/tests/PlazaGeocodingTest.js` - New comprehensive test file
- `/tests/PlazaDistanceTest.js` - New distance validation test file
- `/tests/TestRealCampData.js` - New real data validation

## Future Considerations
- Consider adding plaza definitions to hardcoded locations for guaranteed accuracy
- May want to add visual debugging tools to verify plaza polygon generation
- Could enhance fuzzy matching algorithm to consider street letters in scoring
