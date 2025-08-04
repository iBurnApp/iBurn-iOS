# BlackRockCityPlanner Geocoding Fix for Plaza Locations
Date: 2025-08-04

## Problem Statement
The BlackRockCityPlanner geocoder is failing to process plaza locations with time positions, affecting numerous camps in the 2025 data. Examples of failing addresses:
- "Center Camp Plaza @ 7:30"
- "3:00 Plaza @ 10:00"
- "9:00 Public Plaza @ 3:15"
- "7:30 Plaza @ 12:30"

These addresses represent camps located on the perimeter of plazas at specific clock positions, which is a common addressing pattern at Burning Man.

## Technical Analysis

### Current State
1. **Geocoding Run Results**:
   - 38 camps failed to geocode with "Center Camp Plaza @ X:XX" addresses
   - Additional camps with plaza addresses at other locations also failed
   - Missing location_string fields resulted in camps without any location data

2. **Code Investigation**:
   - The geocoder has hardcoded locations for "Center Camp Plaza", "Café", and "Rod's Road"
   - These only work for exact string matches
   - The parser correctly splits plaza + time combinations but the geocoder doesn't handle them
   - Test cases for plaza + time exist but are commented out as TODO items

### Root Causes
1. **Hardcoded Location Limitation**: 
   ```javascript
   // In forward.js line 199
   if (locationString1 in this.hardcodedLocations) {
       return this.hardcodedLocations[locationString1];
   }
   ```
   This only matches exact strings, so "Center Camp Plaza @ 7:30" doesn't match "Center Camp Plaza"

2. **Incomplete Plaza Handling**:
   - The code has logic for polygon features (plazas) but doesn't properly calculate perimeter points
   - Plaza + time combinations need special handling to find points on the plaza edge

3. **Parser Support**:
   - The parser regex correctly identifies plaza features: `(^[a-l|rod|p].*)|(^.*plaza.*$)|(^.*portal.*$)`
   - But the geocoder doesn't have a complete implementation for plaza intersections

## Proposed Solution

### 1. Enhanced Plaza Detection
Modify the geocoder to detect plaza patterns before exact string matching:
```javascript
// Extract base plaza name from patterns like "Center Camp Plaza @ 7:30"
var plazaMatch = locationString1.match(/^(.*?plaza)\s*[@&]\s*(.+)$/i);
if (plazaMatch) {
    var plazaName = plazaMatch[1].trim();
    var timeString = plazaMatch[2].trim();
    // Handle plaza + time combination
}
```

### 2. Plaza Perimeter Calculation
Implement a new method to calculate points on plaza perimeters:
```javascript
Geocoder.prototype.plazaTimeToLatLon = function(plazaName, timeString) {
    // Get plaza center from hardcoded locations or features
    var plazaCenter = this.getPlazaCenter(plazaName);
    if (!plazaCenter) return undefined;
    
    // Get plaza radius
    var plazaRadius = this.getPlazaRadius(plazaName);
    
    // Convert time to bearing from plaza center
    var bearing = utils.timeStringToCompassDegress(timeString, this.cityBearing);
    
    // Calculate point on perimeter
    return turf.destination(plazaCenter, plazaRadius, bearing, {units: 'miles'});
};
```

### 3. Update Geocode Method
Enhance the main geocode method to handle plaza patterns:
```javascript
Geocoder.prototype.geocode = function(locationString1, locationString2) {
    // Check for plaza + time pattern first
    var plazaMatch = locationString1.match(/^(.*?plaza)\s*[@&]\s*(.+)$/i);
    if (plazaMatch) {
        return this.plazaTimeToLatLon(plazaMatch[1], plazaMatch[2]);
    }
    
    // Continue with existing logic...
}
```

### 4. Plaza Definitions
Update prepare.js to include plaza radius information:
```javascript
var hardcodedLocations = {
    "Center Camp Plaza": {
        center: turf.point(centerCampCenter.geometry.coordinates),
        radius: utils.feetToMiles(layoutFile.center_camp.cafe_plaza_radius)
    },
    // Add other plazas...
};
```

## Implementation Plan

### Phase 1: Core Fix
1. **Update forward.js**:
   - Add `plazaTimeToLatLon` method
   - Modify `geocode` method to detect plaza patterns
   - Handle plaza radius calculations

2. **Update prepare.js**:
   - Enhance hardcoded locations with plaza metadata
   - Add radius information for accurate perimeter calculations

3. **Parser Updates** (if needed):
   - Ensure plaza pattern matching is comprehensive
   - Handle various plaza name formats

### Phase 2: Testing
1. **Uncomment Test Cases**:
   - Enable commented plaza tests in GeocoderTest.js
   - Add new test cases for all plaza patterns found in data

2. **Verification**:
   - Run tests to ensure plaza geocoding works
   - Verify coordinates are on plaza perimeters

### Phase 3: Data Processing
1. **Re-run Geocoding**:
   - Process camp.json with fixed geocoder
   - Verify all plaza addresses are geocoded

2. **Validation**:
   - Check that geocoded coordinates make sense
   - Ensure camps are positioned correctly on plaza edges

## Expected Outcomes
1. All plaza + time addresses will geocode successfully
2. Camps will be correctly positioned on plaza perimeters
3. No more "could not geocode" errors for plaza locations
4. Complete location data for all camps in 2025 dataset

## File Changes Summary
- `/src/geocoder/forward.js` - Add plaza handling methods
- `/src/geocoder/prepare.js` - Enhance plaza definitions
- `/tests/GeocoderTest.js` - Enable and add plaza tests
- `/src/geocoder/geocodeParser.js` - Enhance plaza parsing (if needed)

## Error Examples Fixed
Before:
```
could not geocode Chariot Project: Center Camp Plaza @ 7:30
could not geocode Alter Ego: Center Camp Plaza @ 12:30
could not geocode Infinite Community: Center Camp Plaza @ 4:45
```

After:
```
Chariot Project: Center Camp Plaza @ 7:30 → [-119.xxxxx, 40.xxxxx]
Alter Ego: Center Camp Plaza @ 12:30 → [-119.xxxxx, 40.xxxxx]
Infinite Community: Center Camp Plaza @ 4:45 → [-119.xxxxx, 40.xxxxx]
```

## Implementation Results

### Code Changes Made
1. **forward.js**:
   - Added `plazaTimeToLatLon` method to calculate points on plaza perimeters
   - Updated `geocode` method to detect plaza + time patterns using regex
   - Modified constructor to accept layout file parameter

2. **prepare.js**:
   - Added layoutFile to the return object for access in forward geocoder

3. **geocoder.js**:
   - Updated to pass layoutFile to forward geocoder constructor

### Test Results
Successfully tested various Center Camp Plaza formats:
- "Center Camp Plaza" → Success (center point)
- "Center Camp Plaza @ 7:30" → Success (perimeter point)
- "Center Camp Plaza & 7:30" → Success (perimeter point)

Different clock positions produce different coordinates:
- 12:00: [-119.209852, 40.781765]
- 3:00: [-119.209852, 40.780525]
- 6:00: [-119.211490, 40.780525]
- 7:30: [-119.211829, 40.781145]
- 9:00: [-119.211490, 40.781765]
- 10:30: [-119.210671, 40.782022]

### Geocoding Results
- **Before Fix**: Multiple "could not geocode" errors for Center Camp Plaza locations
- **After Fix**: All plaza locations successfully geocoded
- **Success Rate**: 1367 out of 1383 camps geocoded (98.8%)
- **Remaining Issues**: 16 camps with missing location_string fields (not plaza-related)

### Sample Fixed Entries
```json
{
  "name": "Chariot Project",
  "location_string": "Center Camp Plaza @ 7:30",
  "gps_latitude": 40.781145,
  "gps_longitude": -119.211829
}
{
  "name": "Alter Ego",
  "location_string": "Center Camp Plaza @ 12:30",
  "gps_latitude": 40.781583,
  "gps_longitude": -119.209667
}
```

## Conclusion
The fix successfully resolves the geocoding issues for plaza + time addresses. All Center Camp Plaza locations now have proper coordinates positioned on the plaza perimeter at their specified clock positions. The implementation is working as designed and the 2025 camp data has been updated with complete location information.

## Test Updates (2025-08-04)

### Test Coverage Added
1. **Plaza + Time Test Suite**: Added comprehensive `plazaTimeGeocoding` test with:
   - Center Camp Plaza tests for all cardinal directions (12:00, 3:00, 6:00, 9:00)
   - Tests for both @ and & separators
   - Case-insensitive matching tests
   - Bearing and distance validation
   - Other plaza types (3:00 B Plaza, 9:00 G Plaza, etc.)
   - Invalid plaza handling

2. **Updated Existing Tests**: 
   - Added plaza + time test cases to the main geocode test
   - Implemented tolerance support for tests that validate perimeter points

### Test Results
- All 97 tests in GeocoderTest.js pass
- Plaza coordinates are validated to be at correct radius from center
- Bearing calculations verified to be within 1 degree of expected
- Invalid plaza requests correctly return undefined
- Both @ and & separators work correctly
- Case insensitive matching works ("center camp plaza" = "Center Camp Plaza")