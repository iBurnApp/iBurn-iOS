# iBurn Deep Linking Implementation Overview
*Date: August 7, 2025*

## Executive Summary

This document outlines the complete implementation plan for adding deep linking capabilities to the iBurn ecosystem, enabling users to share specific content (art installations, camps, events, and custom map pins) via web URLs that intelligently open in the native apps when available or display rich preview pages as fallback.

## Project Goals

1. **Enable content sharing** - Users can share any data object or custom map pin via URL
2. **Cross-platform consistency** - Identical URL structures work across iOS, Android, and web
3. **Rich previews** - Web fallback pages display interactive maps and images
4. **Seamless experience** - Automatic app opening with graceful fallbacks
5. **Future-proof architecture** - Extensible system for new content types

## URL Architecture

### Base Domain
- Primary: `https://iburnapp.com`
- Custom URL scheme: `iburn://`

### URL Patterns

#### API-Based Objects
```
https://iburnapp.com/{type}/{uid}?{parameters}
iburn://{type}/{uid}?{parameters}

Types: art, camp, event
UID: Salesforce-style identifier (e.g., "a2Id0000000cbObEAI")
```

#### Custom Map Pins
```
https://iburnapp.com/pin?lat={latitude}&lng={longitude}&title={title}&{parameters}
iburn://pin?lat={latitude}&lng={longitude}&title={title}&{parameters}
```

### Query Parameters

#### Universal Parameters (all object types)
| Parameter | Description | Example |
|-----------|-------------|---------|
| `title` | Display name | `Sunrise%20Yoga` |
| `desc` | Short description (≤100 chars) | `Morning%20yoga%20session` |
| `lat` | GPS latitude (6 decimals) | `40.786800` |
| `lng` | GPS longitude (6 decimals) | `-119.206800` |
| `addr` | Playa address | `3%3A15%20%26%20G` |
| `year` | Event year | `2025` |
| `img` | Override image URL | `https%3A%2F%2Fexample.com%2Fimage.jpg` |

#### Event-Specific Parameters
| Parameter | Description | Example |
|-----------|-------------|---------|
| `host` | Hosting camp/art name | `Camp%20Mystic` |
| `host_id` | Host object UID | `a1XVI000001vN7N` |
| `host_type` | Host type | `camp` or `art` |
| `start` | Start time (ISO 8601) | `2025-08-26T18:00` |
| `end` | End time (ISO 8601) | `2025-08-26T20:00` |
| `type` | Event category | `workshop` |
| `all_day` | All-day event flag | `true` |

#### Pin-Specific Parameters
| Parameter | Description | Example |
|-----------|-------------|---------|
| `color` | Pin color/category | `red` |
| `icon` | Pin icon type | `bike` |

### Example URLs

**Minimal art piece:**
```
https://iburnapp.com/art/a2Id0000000cbObEAI
```

**Rich event with metadata:**
```
https://iburnapp.com/event/5ye8cMz8?title=Fire%20Spinning&host=The%20Folly&host_id=a2Id0000000cbOb&host_type=art&addr=9%3A00%20Plaza&start=2025-08-29T21:00&desc=Nightly%20fire%20performance
```

**Custom map pin:**
```
https://iburnapp.com/pin?lat=40.78680&lng=-119.20680&title=Lost%20Bike&addr=7%3A30%20%26%20K&desc=Blue%20cruiser%20with%20EL%20wire&color=blue
```

## Technical Architecture

### Website (Jekyll/GitHub Pages)

**Static Landing Pages:**
- `/art/index.html` - Art object handler
- `/camp/index.html` - Camp object handler
- `/event/index.html` - Event object handler
- `/pin/index.html` - Custom pin handler

**Key Features:**
1. **PMTiles Map Display** - Interactive offline maps using Protomaps
2. **Image Gallery** - Camp/art photos from `/data/{year}/images/`
3. **Smart App Banners** - Native iOS/Android deep link attempts
4. **JavaScript Rendering** - Dynamic content from URL parameters
5. **Fallback UI** - App store links and "Try Again" button

**Technologies:**
- MapLibre GL JS with PMTiles protocol
- Vanilla JavaScript for compatibility
- Bootstrap 3 (existing framework)
- Open Graph meta tags for social sharing

### iOS Implementation

**URL Handling:**
1. Replace legacy URL scheme with `iburn://`
2. Configure Associated Domains for Universal Links
3. Implement URL routing in AppDelegate
4. Create DeepLinkCoordinator for navigation

**Key Components:**
- `BRCDeepLinkRouter` - URL parsing and routing
- `BRCMapPin` - Custom pin data model
- Share extensions in detail views
- URL generation utilities

**Integration Points:**
- `BRCDatabaseManager` for object lookups
- `TabController` for navigation
- `DetailViewControllerFactory` for object display

### Android Implementation

**Intent Filters:**
1. Configure App Links with auto-verification
2. Handle both `https://` and `iburn://` schemes
3. Parse URIs in MainActivity
4. Route to appropriate activities

**Key Components:**
- `DeepLinkHandler` - URI parsing and routing
- `MapPin` data class and database table
- Share intent builders
- URL generation utilities

**Integration Points:**
- Database queries by `playaId`
- `PlayaItemViewActivity` for object display
- Map fragment for pin creation

## Implementation Timeline

### Week 1: Website Foundation (Aug 8-14)
1. Convert MBTiles to PMTiles format
2. Create static landing pages
3. Implement JavaScript URL parsing
4. Add map and image display
5. Deploy to GitHub Pages

### Week 2: iOS Deep Linking (Aug 15-21)
1. Update URL schemes in Info.plist
2. Configure Associated Domains
3. Implement URL routing
4. Add custom pin support
5. Create share functionality
6. Test and debug

### Week 3: Android Deep Linking (Aug 22-28)
1. Configure intent filters
2. Implement URI handling
3. Add custom pin support
4. Create share intents
5. Test App Links verification
6. Debug and optimize

### Week 4: Integration & Polish (Aug 29-Sep 4)
1. Cross-platform testing
2. Analytics integration
3. Performance optimization
4. Documentation updates
5. User testing
6. Final deployment

*Note: Burning Man 2025 runs from August 24 - September 1, so we'll have the core functionality ready before the event begins.*

## Data Flow

### Sharing Flow
1. User selects "Share" in app
2. App generates URL with metadata
3. URL shared via system share sheet
4. Recipient clicks link

### Opening Flow
1. **App Installed:**
   - OS recognizes Universal Link/App Link
   - Opens directly in app
   - App parses URL and navigates

2. **App Not Installed:**
   - Opens in web browser
   - JavaScript attempts deep link
   - Shows rich preview with map/image
   - Provides app download links

## Assets & Resources

### Required Files

**Website:**
- PMTiles map files (converted from MBTiles)
- Camp/art images in `/data/{year}/images/`
- JavaScript libraries (MapLibre GL, PMTiles)
- Landing page HTML templates

**iOS:**
- `apple-app-site-association` file
- Updated Info.plist with URL schemes
- Entitlements with Associated Domains

**Android:**
- `assetlinks.json` file
- Updated AndroidManifest.xml
- Intent filter configurations

### Existing Resources (Already Available)
- **Map Data**: `/Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/data/2025/Map/Map.bundle/map.mbtiles`
- **Images**: `/Users/chrisbal/Documents/Code/iburnapp.github.io/data/2025/images/` (1266 camp/art images)
- **Website**: Jekyll site at `iburnapp.github.io` repository

### External Dependencies
- Protomaps PMTiles library
- MapLibre GL JS
- go-pmtiles converter tool

## Security & Privacy

1. **Input Validation** - Sanitize all URL parameters
2. **Coordinate Bounds** - Verify within Black Rock City
3. **No Personal Data** - Avoid PII in URLs
4. **URL Length** - Monitor for browser limits
5. **HTTPS Only** - Secure connections required

## Success Metrics

1. **Adoption Rate** - % of users using share feature
2. **Conversion Rate** - % of web visitors installing app
3. **Error Rate** - Failed deep link attempts
4. **Performance** - Page load and map render times
5. **Cross-Platform** - Success rate per platform

## Testing Strategy

### Unit Tests
- URL parsing logic
- Parameter validation
- Coordinate bounds checking

### Integration Tests
- Deep link routing
- Database lookups
- Navigation flows

### End-to-End Tests
- Full sharing flow
- Cross-app link opening
- Web fallback scenarios

### Manual Testing
- Various URL formats
- Different devices/OS versions
- Social media sharing
- Email/SMS links

## Rollout Plan

1. **Pre-Event Testing** (Aug 8-20) - Internal team testing
2. **Soft Launch** (Aug 21-23) - Enable for beta users
3. **Event Launch** (Aug 24) - Full launch for Burning Man
4. **Monitor & Support** (Aug 24-Sep 1) - Active monitoring during event
5. **Post-Event Review** (Sep 2+) - Analyze metrics and plan improvements

## Future Enhancements

1. **URL Shortener** - Custom short links for long URLs
2. **QR Codes** - Generate QR codes for objects
3. **Offline Sync** - Cache shared content locally
4. **Social Features** - Comments and reactions
5. **Analytics Dashboard** - Track popular content

## Platform-Specific Documentation

Detailed implementation guides are available for each platform:

1. [iOS Implementation Guide](./2025-08-07-deep-linking-ios.md)
2. [Android Implementation Guide](./2025-08-07-deep-linking-android.md)
3. [Website Implementation Guide](./2025-08-07-deep-linking-website.md)

## Key Implementation Considerations

### Black Rock City 2025 Specifics
- Event dates: August 24 - September 1, 2025
- Theme: "Curiouser and Curiouser"
- Expected attendance: ~70,000
- Map coordinates: 40.7864°N, -119.2065°W (The Man)

### Critical Path Items
1. PMTiles conversion must complete before website deployment
2. Domain verification files must be live before app releases
3. Both apps should release updates simultaneously
4. Test with actual 2025 data before event

## Conclusion

This deep linking implementation will significantly enhance the iBurn user experience by enabling seamless content sharing across platforms. With Burning Man 2025 starting August 24, we have a tight but achievable timeline to deliver this feature before participants arrive on playa.

## Appendix: Technical Details

### PMTiles Conversion Commands
```bash
# Install converter
go install github.com/protomaps/go-pmtiles/pmtiles@latest

# Convert 2025 MBTiles to PMTiles
pmtiles convert /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/data/2025/Map/Map.bundle/map.mbtiles /Users/chrisbal/Documents/Code/iburnapp.github.io/data/2025/map/map-2025.pmtiles

# Verify output
pmtiles show /Users/chrisbal/Documents/Code/iburnapp.github.io/data/2025/map/map-2025.pmtiles
```

### URL Length Considerations
- Browser limit: ~2,000 characters (safe)
- SMS limit: ~160 characters (problematic for rich URLs)
- Social media: Varies (Twitter ~4,000, Facebook ~2,000)
- Recommendation: Keep under 500 characters when possible

### Coordinate Precision
- 6 decimal places = ~0.1 meter precision
- Black Rock City bounds: 40.75°N to 40.82°N, -119.17°W to -119.25°W
- Default center: 40.7864°N, -119.2065°W (The Man)

### Repository Locations
- **iOS**: `/Users/chrisbal/Documents/Code/iBurn-iOS/`
- **Android**: `/Users/chrisbal/Documents/Code/iBurn-Android/`
- **Website**: `/Users/chrisbal/Documents/Code/iburnapp.github.io/`

---

*Last Updated: August 7, 2025*
*Author: iBurn Development Team*