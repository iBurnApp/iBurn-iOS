# Website Deep Linking Implementation Guide
*Date: August 7, 2025*

## Overview

This guide provides detailed implementation instructions for creating deep link landing pages on the iBurn website (iburnapp.com). These pages will display rich previews with interactive maps and images, attempting to open the native apps when available.

## Current State Analysis

### Existing Infrastructure
- **Static Site**: Jekyll on GitHub Pages
- **Domain**: iburnapp.com (CNAME configured)
- **Framework**: Bootstrap 3 with custom landing page theme
- **Assets**: Camp/art images at `/data/2025/images/`
- **Analytics**: Google Analytics and Facebook Pixel
- **Repository**: `/Users/chrisbal/Documents/Code/iburnapp.github.io/`

### Available Resources
- **Map Data**: MBTiles files in iBurn-Data submodule
- **Images**: 1266 camp/art images (named by UID)
- **No Backend**: Pure static file hosting

## Implementation Steps

### Step 1: Convert MBTiles to PMTiles

#### 1.1 Install PMTiles Converter

```bash
# Install Go if not already installed
brew install go

# Install pmtiles tool
go install github.com/protomaps/go-pmtiles/pmtiles@latest

# Add to PATH if needed
export PATH=$PATH:$(go env GOPATH)/bin
```

#### 1.2 Convert Map Files

```bash
# Navigate to website repository
cd /Users/chrisbal/Documents/Code/iburnapp.github.io

# Create map directories
mkdir -p data/2025/map
mkdir -p data/2024/map

# Convert 2025 map
pmtiles convert \
  /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/data/2025/Map/Map.bundle/map.mbtiles \
  data/2025/map/map-2025.pmtiles

# Convert 2024 map (if available)
pmtiles convert \
  /Users/chrisbal/Documents/Code/iBurn-iOS/Submodules/iBurn-Data/data/2024/Map/map.mbtiles \
  data/2024/map/map-2024.pmtiles

# Verify conversions
pmtiles show data/2025/map/map-2025.pmtiles
```

### Step 2: Create Landing Page Structure

#### 2.1 Directory Structure

```
iburnapp.github.io/
├── art/
│   └── index.html
├── camp/
│   └── index.html
├── event/
│   └── index.html
├── pin/
│   └── index.html
├── assets/
│   ├── js/
│   │   ├── deeplink-handler.js
│   │   ├── map-viewer.js
│   │   └── pmtiles-protocol.js
│   └── css/
│       └── deeplink-pages.css
├── .well-known/
│   ├── apple-app-site-association
│   └── assetlinks.json
└── data/
    └── 2025/
        ├── map/
        │   └── map-2025.pmtiles
        └── images/
            └── [existing camp/art images]
```

### Step 3: Create Landing Pages

#### 3.1 Base Template (_layouts/deeplink.html)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    
    <title id="page-title">iBurn - {{ page.type | capitalize }}</title>
    <meta name="description" id="meta-description" content="View on iBurn - Offline Map and Guide for Burning Man">
    
    <!-- Open Graph / Social Media -->
    <meta property="og:title" id="og-title" content="iBurn">
    <meta property="og:description" id="og-description" content="View on iBurn">
    <meta property="og:image" id="og-image" content="/img/iburn-logo.png">
    <meta property="og:url" id="og-url" content="">
    <meta property="og:type" content="website">
    
    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" id="twitter-title" content="iBurn">
    <meta name="twitter:description" id="twitter-description" content="View on iBurn">
    <meta name="twitter:image" id="twitter-image" content="/img/iburn-logo.png">
    
    <!-- iOS Smart App Banner -->
    <meta name="apple-itunes-app" id="ios-app-banner" content="app-id=388169740">
    
    <!-- Existing CSS -->
    <link href="/css/bootstrap.min.css" rel="stylesheet">
    <link href="/css/landing-page.css" rel="stylesheet">
    <link href="/assets/css/deeplink-pages.css" rel="stylesheet">
    
    <!-- MapLibre GL CSS -->
    <link href="https://unpkg.com/maplibre-gl@3.3.1/dist/maplibre-gl.css" rel="stylesheet">
    
    <!-- Custom Fonts -->
    <link href="/font-awesome-4.1.0/css/font-awesome.min.css" rel="stylesheet" type="text/css">
    <link href="https://fonts.googleapis.com/css?family=Lato:300,400,700,300italic,400italic,700italic" rel="stylesheet" type="text/css">
    
    {{ page.head_extra }}
</head>
<body>
    <div class="container deeplink-container">
        <!-- Loading State -->
        <div id="loading-state" class="text-center">
            <h2>Opening in iBurn...</h2>
            <div class="spinner"></div>
        </div>
        
        <!-- Content Preview -->
        <div id="content-preview" style="display: none;">
            <div class="preview-card">
                <!-- Image -->
                <div id="image-container" class="image-wrapper">
                    <img id="preview-image" alt="Preview" style="display: none;">
                    <div id="image-placeholder" class="image-placeholder">
                        <i class="fa fa-image fa-3x"></i>
                    </div>
                </div>
                
                <!-- Content Info -->
                <div class="content-info">
                    <h1 id="content-title">Loading...</h1>
                    <p id="content-description" class="lead"></p>
                    
                    <!-- Event Specific -->
                    <div id="event-details" style="display: none;">
                        <p id="event-host"></p>
                        <p id="event-time"></p>
                    </div>
                    
                    <!-- Location -->
                    <p id="content-location">
                        <i class="fa fa-map-marker"></i> 
                        <span id="location-text"></span>
                    </p>
                </div>
                
                <!-- Map Container -->
                <div id="map-container" class="map-wrapper" style="display: none;">
                    <div id="map" style="height: 400px;"></div>
                </div>
                
                <!-- Action Buttons -->
                <div class="action-buttons">
                    <button id="open-app-btn" class="btn btn-primary btn-lg">
                        <i class="fa fa-external-link"></i> Open in iBurn
                    </button>
                    
                    <div class="download-section">
                        <p>Don't have iBurn yet?</p>
                        <div class="app-store-buttons">
                            <a href="https://itunes.apple.com/us/app/iburn/id388169740" class="app-store-link">
                                <img src="/img/appstore.svg" alt="Download on App Store" height="40">
                            </a>
                            <a href="https://play.google.com/store/apps/details?id=com.iburnapp.iburn3" class="app-store-link">
                                <img src="/img/playstore.svg" alt="Get it on Google Play" height="45">
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Scripts -->
    <script src="/js/jquery-1.11.0.js"></script>
    <script src="/js/bootstrap.min.js"></script>
    
    <!-- MapLibre GL JS -->
    <script src="https://unpkg.com/maplibre-gl@3.3.1/dist/maplibre-gl.js"></script>
    
    <!-- PMTiles -->
    <script src="https://unpkg.com/pmtiles@2.11.0/dist/index.js"></script>
    
    <!-- Deep Link Handler -->
    <script src="/assets/js/pmtiles-protocol.js"></script>
    <script src="/assets/js/map-viewer.js"></script>
    <script src="/assets/js/deeplink-handler.js"></script>
    
    <script>
        // Initialize with page type
        window.DEEPLINK_TYPE = '{{ page.type }}';
    </script>
</body>
</html>
```

#### 3.2 Landing Pages

**art/index.html:**
```html
---
layout: deeplink
type: art
---
```

**camp/index.html:**
```html
---
layout: deeplink
type: camp
---
```

**event/index.html:**
```html
---
layout: deeplink
type: event
---
```

**pin/index.html:**
```html
---
layout: deeplink
type: pin
---
```

### Step 4: JavaScript Implementation

#### 4.1 deeplink-handler.js

```javascript
// Deep Link Handler - Main Logic
(function() {
    'use strict';
    
    const DEEP_LINK_TIMEOUT = 2500; // ms to wait before showing fallback
    const BRC_CENTER = { lat: 40.7864, lng: -119.2065 }; // The Man
    
    class DeepLinkHandler {
        constructor() {
            this.type = window.DEEPLINK_TYPE || 'unknown';
            this.params = new URLSearchParams(window.location.search);
            this.uid = this.extractUid();
            this.metadata = this.extractMetadata();
            this.year = this.params.get('year') || '2025';
            
            this.init();
        }
        
        extractUid() {
            const pathParts = window.location.pathname.split('/').filter(p => p);
            return pathParts.length > 1 ? pathParts[1] : null;
        }
        
        extractMetadata() {
            const metadata = {};
            for (const [key, value] of this.params.entries()) {
                metadata[key] = decodeURIComponent(value);
            }
            return metadata;
        }
        
        init() {
            // Update page metadata
            this.updatePageMeta();
            
            // Attempt deep link
            this.attemptDeepLink();
            
            // Setup fallback UI
            setTimeout(() => this.showFallback(), DEEP_LINK_TIMEOUT);
            
            // Setup event handlers
            this.setupEventHandlers();
        }
        
        updatePageMeta() {
            const title = this.metadata.title || `iBurn ${this.type}`;
            const description = this.metadata.desc || 'View on iBurn - Offline Map and Guide for Burning Man';
            const url = window.location.href;
            
            // Update meta tags
            document.getElementById('page-title').textContent = title;
            document.getElementById('meta-description').content = description;
            document.getElementById('og-title').content = title;
            document.getElementById('og-description').content = description;
            document.getElementById('og-url').content = url;
            document.getElementById('twitter-title').content = title;
            document.getElementById('twitter-description').content = description;
            
            // Update iOS Smart App Banner
            if (this.uid) {
                const appArgument = `iburn://${this.type}/${this.uid}`;
                document.getElementById('ios-app-banner').content = 
                    `app-id=388169740, app-argument=${appArgument}`;
            }
        }
        
        buildDeepLinkUrl() {
            let deepLink = `iburn://`;
            
            if (this.type === 'pin') {
                // Pin uses query parameters
                deepLink += `pin?${this.params.toString()}`;
            } else if (this.uid) {
                // Other types use path
                deepLink += `${this.type}/${this.uid}`;
                if (this.params.toString()) {
                    deepLink += `?${this.params.toString()}`;
                }
            }
            
            return deepLink;
        }
        
        attemptDeepLink() {
            const deepLink = this.buildDeepLinkUrl();
            console.log('Attempting deep link:', deepLink);
            
            // Method 1: iframe (works on iOS)
            const iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = deepLink;
            document.body.appendChild(iframe);
            
            // Method 2: location change (works on Android)
            setTimeout(() => {
                window.location.href = deepLink;
            }, 100);
            
            // Method 3: Intent URL for Android Chrome
            if (navigator.userAgent.match(/Android/i)) {
                const intentUrl = this.buildAndroidIntentUrl();
                setTimeout(() => {
                    window.location.href = intentUrl;
                }, 200);
            }
        }
        
        buildAndroidIntentUrl() {
            const deepLink = this.buildDeepLinkUrl();
            const encoded = encodeURIComponent(deepLink);
            return `intent://${deepLink.replace('iburn://', '')}#Intent;scheme=iburn;package=com.iburnapp.iburn3;S.browser_fallback_url=${encodeURIComponent(window.location.href)};end`;
        }
        
        showFallback() {
            // Hide loading, show content
            document.getElementById('loading-state').style.display = 'none';
            document.getElementById('content-preview').style.display = 'block';
            
            // Populate content
            this.populateContent();
            
            // Load image if available
            this.loadImage();
            
            // Initialize map if coordinates available
            if (this.metadata.lat && this.metadata.lng) {
                this.initializeMap();
            }
        }
        
        populateContent() {
            // Title
            const title = this.metadata.title || `${this.type} ${this.uid || ''}`.trim();
            document.getElementById('content-title').textContent = title;
            
            // Description
            if (this.metadata.desc) {
                document.getElementById('content-description').textContent = this.metadata.desc;
            }
            
            // Location
            if (this.metadata.addr) {
                document.getElementById('location-text').textContent = this.metadata.addr;
            } else if (this.metadata.lat && this.metadata.lng) {
                document.getElementById('location-text').textContent = 
                    `${parseFloat(this.metadata.lat).toFixed(4)}, ${parseFloat(this.metadata.lng).toFixed(4)}`;
            } else {
                document.getElementById('content-location').style.display = 'none';
            }
            
            // Event-specific details
            if (this.type === 'event') {
                this.populateEventDetails();
            }
        }
        
        populateEventDetails() {
            const eventDetails = document.getElementById('event-details');
            
            if (this.metadata.host) {
                document.getElementById('event-host').innerHTML = 
                    `<i class="fa fa-users"></i> Hosted by ${this.metadata.host}`;
            }
            
            if (this.metadata.start || this.metadata.end) {
                const timeText = this.formatEventTime();
                document.getElementById('event-time').innerHTML = 
                    `<i class="fa fa-clock-o"></i> ${timeText}`;
            }
            
            if (this.metadata.host || this.metadata.start) {
                eventDetails.style.display = 'block';
            }
        }
        
        formatEventTime() {
            const options = { 
                weekday: 'short', 
                month: 'short', 
                day: 'numeric', 
                hour: 'numeric', 
                minute: '2-digit' 
            };
            
            if (this.metadata.all_day === 'true') {
                return 'All Day Event';
            }
            
            let timeText = '';
            if (this.metadata.start) {
                const startDate = new Date(this.metadata.start);
                timeText = startDate.toLocaleString('en-US', options);
            }
            
            if (this.metadata.end) {
                const endDate = new Date(this.metadata.end);
                timeText += ' - ' + endDate.toLocaleTimeString('en-US', { 
                    hour: 'numeric', 
                    minute: '2-digit' 
                });
            }
            
            return timeText;
        }
        
        loadImage() {
            // Determine image ID
            let imageId = this.uid;
            
            // For events, use host's image
            if (this.type === 'event' && this.metadata.host_id) {
                imageId = this.metadata.host_id;
            }
            
            // Skip for pins
            if (this.type === 'pin' || !imageId) {
                return;
            }
            
            const imageUrl = `/data/${this.year}/images/${imageId}.jpg`;
            const img = new Image();
            
            img.onload = () => {
                document.getElementById('preview-image').src = imageUrl;
                document.getElementById('preview-image').style.display = 'block';
                document.getElementById('image-placeholder').style.display = 'none';
                
                // Update social media image
                document.getElementById('og-image').content = window.location.origin + imageUrl;
                document.getElementById('twitter-image').content = window.location.origin + imageUrl;
            };
            
            img.onerror = () => {
                console.log('Image not found:', imageUrl);
                // Keep placeholder visible
            };
            
            img.src = imageUrl;
        }
        
        initializeMap() {
            const lat = parseFloat(this.metadata.lat);
            const lng = parseFloat(this.metadata.lng);
            
            if (isNaN(lat) || isNaN(lng)) {
                return;
            }
            
            document.getElementById('map-container').style.display = 'block';
            
            // Initialize map viewer (defined in map-viewer.js)
            const mapViewer = new MapViewer('map', this.year);
            mapViewer.initialize(lat, lng, this.metadata.title || 'Location');
        }
        
        setupEventHandlers() {
            // Open app button
            document.getElementById('open-app-btn').addEventListener('click', () => {
                this.attemptDeepLink();
            });
        }
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => new DeepLinkHandler());
    } else {
        new DeepLinkHandler();
    }
})();
```

#### 4.2 map-viewer.js

```javascript
// Map Viewer with PMTiles support
class MapViewer {
    constructor(containerId, year = '2025') {
        this.containerId = containerId;
        this.year = year;
        this.map = null;
    }
    
    async initialize(centerLat, centerLng, markerTitle) {
        // Register PMTiles protocol
        let protocol = new pmtiles.Protocol();
        maplibregl.addProtocol('pmtiles', protocol.tile);
        
        // Initialize map
        this.map = new maplibregl.Map({
            container: this.containerId,
            style: {
                version: 8,
                sources: {
                    'brc-tiles': {
                        type: 'vector',
                        url: `pmtiles://${window.location.origin}/data/${this.year}/map/map-${this.year}.pmtiles`
                    }
                },
                layers: [
                    {
                        id: 'background',
                        type: 'background',
                        paint: {
                            'background-color': '#f5e6d3' // Playa dust color
                        }
                    },
                    {
                        id: 'streets',
                        type: 'line',
                        source: 'brc-tiles',
                        'source-layer': 'streets',
                        paint: {
                            'line-color': '#8B4513',
                            'line-width': 2
                        }
                    },
                    {
                        id: 'labels',
                        type: 'symbol',
                        source: 'brc-tiles',
                        'source-layer': 'labels',
                        layout: {
                            'text-field': '{name}',
                            'text-size': 12
                        },
                        paint: {
                            'text-color': '#333'
                        }
                    }
                ]
            },
            center: [centerLng, centerLat],
            zoom: 15,
            attributionControl: false
        });
        
        // Add navigation controls
        this.map.addControl(new maplibregl.NavigationControl(), 'top-right');
        
        // Add marker
        new maplibregl.Marker({ color: '#ff0000' })
            .setLngLat([centerLng, centerLat])
            .setPopup(new maplibregl.Popup().setHTML(`<b>${markerTitle}</b>`))
            .addTo(this.map);
        
        // Handle map errors
        this.map.on('error', (e) => {
            console.error('Map error:', e);
            // Fallback to simple map or hide
            if (e.error && e.error.status === 404) {
                document.getElementById('map-container').style.display = 'none';
            }
        });
    }
}
```

#### 4.3 deeplink-pages.css

```css
/* Deep Link Pages Styles */
.deeplink-container {
    max-width: 800px;
    margin: 50px auto;
    padding: 20px;
}

/* Loading State */
#loading-state {
    padding: 100px 20px;
}

.spinner {
    border: 4px solid #f3f3f3;
    border-top: 4px solid #FF6B35;
    border-radius: 50%;
    width: 50px;
    height: 50px;
    animation: spin 1s linear infinite;
    margin: 30px auto;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Preview Card */
.preview-card {
    background: white;
    border-radius: 10px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    overflow: hidden;
}

/* Image */
.image-wrapper {
    width: 100%;
    height: 300px;
    background: #f5f5f5;
    position: relative;
    overflow: hidden;
}

#preview-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
}

.image-placeholder {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 100%;
    color: #ccc;
}

/* Content Info */
.content-info {
    padding: 20px;
}

#content-title {
    margin-top: 0;
    margin-bottom: 15px;
    color: #333;
}

#content-description {
    color: #666;
    margin-bottom: 15px;
}

#content-location {
    color: #888;
    font-size: 14px;
}

#event-details p {
    margin: 10px 0;
    color: #666;
}

/* Map */
.map-wrapper {
    margin: 20px 0;
    border: 1px solid #ddd;
    border-radius: 5px;
    overflow: hidden;
}

/* Action Buttons */
.action-buttons {
    padding: 20px;
    text-align: center;
    background: #f9f9f9;
    border-top: 1px solid #eee;
}

#open-app-btn {
    background: #FF6B35;
    border: none;
    padding: 15px 30px;
    font-size: 18px;
    margin-bottom: 20px;
}

#open-app-btn:hover {
    background: #E55A26;
}

.download-section {
    margin-top: 30px;
}

.download-section p {
    color: #666;
    margin-bottom: 15px;
}

.app-store-buttons {
    display: flex;
    justify-content: center;
    gap: 15px;
}

.app-store-link img {
    transition: opacity 0.2s;
}

.app-store-link:hover img {
    opacity: 0.8;
}

/* Responsive */
@media (max-width: 768px) {
    .deeplink-container {
        margin: 20px auto;
    }
    
    .image-wrapper {
        height: 200px;
    }
    
    .app-store-buttons {
        flex-direction: column;
        align-items: center;
    }
}
```

### Step 5: Domain Association Files

#### 5.1 .well-known/apple-app-site-association

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.iburnapp.iburn",
        "paths": [
          "/art/*",
          "/camp/*", 
          "/event/*",
          "/pin"
        ]
      }
    ]
  },
  "webcredentials": {
    "apps": ["TEAMID.com.iburnapp.iburn"]
  }
}
```

#### 5.2 .well-known/assetlinks.json

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.iburnapp.iburn3",
    "sha256_cert_fingerprints": [
      "YOUR_APP_SIGNING_CERTIFICATE_SHA256"
    ]
  }
}]
```

### Step 6: Jekyll Configuration

#### 6.1 Update _config.yml

```yaml
# Existing configuration...

# Include dotfiles
include:
  - .well-known

# Exclude from processing
exclude:
  - Gemfile
  - Gemfile.lock
  - README.md
  - CNAME
  - .git
  - .gitignore

# Keep PMTiles files
keep_files:
  - data/2025/map
  - data/2024/map
```

### Step 7: Testing

#### 7.1 Local Testing

```bash
# Start Jekyll server
jekyll serve

# Test URLs
open http://localhost:4000/art/a2Id0000000cbObEAI
open http://localhost:4000/camp/a1XVI000001vN7N?title=Test%20Camp
open http://localhost:4000/event/abc123?title=Sunrise%20Yoga&start=2025-08-26T06:00
open http://localhost:4000/pin?lat=40.7868&lng=-119.2068&title=Meeting%20Point
```

#### 7.2 Deployment Testing

```bash
# Commit and push to GitHub
git add .
git commit -m "Add deep linking landing pages"
git push origin master

# Wait for GitHub Pages to deploy (usually 1-2 minutes)

# Test production URLs
curl -I https://iburnapp.com/.well-known/apple-app-site-association
curl -I https://iburnapp.com/.well-known/assetlinks.json
```

#### 7.3 Cross-Browser Testing

Test on multiple browsers and devices:
- iOS Safari (for Smart App Banner)
- Android Chrome (for Intent URLs)
- Desktop browsers (fallback experience)

### Step 8: Performance Optimization

#### 8.1 Image Optimization

```bash
# Optimize existing images (if not already done)
find data/2025/images -name "*.jpg" -exec jpegoptim --strip-all {} \;
```

#### 8.2 CDN Considerations

For better performance, consider using CDN for libraries:

```html
<!-- Use CDN with fallback -->
<script src="https://cdn.jsdelivr.net/npm/maplibre-gl@3.3.1/dist/maplibre-gl.min.js" 
        integrity="sha384-..." 
        crossorigin="anonymous"></script>
<script>
    window.maplibregl || document.write('<script src="/assets/js/maplibre-gl.min.js"><\/script>')
</script>
```

### Step 9: Analytics

Add event tracking to measure deep link performance:

```javascript
// In deeplink-handler.js
function trackEvent(action, label, value) {
    if (typeof ga !== 'undefined') {
        ga('send', 'event', 'DeepLink', action, label, value);
    }
    
    if (typeof fbq !== 'undefined') {
        fbq('track', 'ViewContent', {
            content_type: label,
            content_ids: [value]
        });
    }
}

// Track deep link attempt
trackEvent('attempt', this.type, this.uid);

// Track fallback shown
trackEvent('fallback', this.type, this.uid);
```

## Troubleshooting

### Common Issues

1. **PMTiles not loading**
   - Check file paths are correct
   - Verify PMTiles files are not gitignored
   - Check browser console for CORS errors
   - Ensure files are served with correct MIME type

2. **Images not showing**
   - Verify image exists at expected path
   - Check image naming matches UID exactly
   - Look for case sensitivity issues

3. **Deep links not working**
   - Test on real devices, not just browsers
   - Verify association files are accessible
   - Check HTTPS is working correctly
   - Ensure no redirects on association file URLs

4. **Map not displaying**
   - Check PMTiles file is valid
   - Verify MapLibre GL is loading
   - Look for JavaScript errors in console
   - Test with simpler style first

## Security Considerations

1. **XSS Prevention**: Sanitize all URL parameters before displaying
2. **Content Security Policy**: Add appropriate CSP headers
3. **HTTPS Only**: Ensure all resources load over HTTPS
4. **Input Validation**: Validate coordinates and other parameters

## Future Enhancements

1. **Service Worker**: Offline caching of maps and images
2. **Progressive Web App**: Install prompt and offline support
3. **WebGL Fallback**: 2D canvas map for older browsers
4. **URL Shortener**: Integration with short URL service
5. **Social Sharing**: Custom share buttons with tracking

## Conclusion

This implementation provides rich, interactive landing pages for iBurn deep links. The pages gracefully handle both successful app launches and fallback scenarios, ensuring a good user experience regardless of whether the app is installed.

---

*Last Updated: August 7, 2025*
*Technologies: Jekyll, MapLibre GL, PMTiles, Bootstrap 3*
*Hosting: GitHub Pages*