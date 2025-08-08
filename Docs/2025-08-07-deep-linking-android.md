# Android Deep Linking Implementation Guide
*Date: August 7, 2025*

## Overview

This guide provides detailed implementation instructions for adding deep linking support to the iBurn Android app. The implementation will support both custom URL schemes (`iburn://`) and Android App Links (`https://iburnapp.com`).

## Current State Analysis

### Existing Infrastructure
- **No deep linking** in AndroidManifest.xml
- **No URL handling** in MainActivity
- **Navigation**: Intent-based with `IntentUtil.viewItemDetail()`
- **Detail Views**: `PlayaItemViewActivity` handles all object types
- **Search Support**: MainActivity handles `ACTION_SEARCH` intents

### Data Model
- **Base Class**: `PlayaItem` abstract class
- **Object Types**:
  - `Art` - Art installations
  - `Camp` - Theme camps  
  - `Event` - Events
- **Database**: Room/SQLite
- **Identifiers**: `playaId` field contains Salesforce-style IDs

## Implementation Steps

### Step 1: Configure Intent Filters

#### 1.1 Update AndroidManifest.xml

```xml
<!-- AndroidManifest.xml -->
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop">
    
    <!-- Existing intent filters... -->
    
    <!-- Custom URL Scheme -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data android:scheme="iburn" />
    </intent-filter>
    
    <!-- App Links (auto-verified) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data android:scheme="https" />
        <data android:host="iburnapp.com" />
        <data android:host="www.iburnapp.com" />
        <data android:pathPrefix="/art/" />
        <data android:pathPrefix="/camp/" />
        <data android:pathPrefix="/event/" />
        <data android:pathPattern="/pin" />
    </intent-filter>
</activity>
```

### Step 2: Create Deep Link Handler

#### 2.1 DeepLinkHandler.kt

```kotlin
package com.iburnapp.iburn.deeplink

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.iburnapp.iburn.data.PlayaDatabase
import com.iburnapp.iburn.data.PlayaItem
import com.iburnapp.iburn.data.MapPin
import com.iburnapp.iburn.ui.PlayaItemViewActivity
import com.iburnapp.iburn.ui.MainActivity
import com.iburnapp.iburn.util.IntentUtil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

class DeepLinkHandler(
    private val context: Context,
    private val database: PlayaDatabase
) {
    
    companion object {
        private const val TAG = "DeepLinkHandler"
        
        // URL path types
        private const val PATH_ART = "art"
        private const val PATH_CAMP = "camp"
        private const val PATH_EVENT = "event"
        private const val PATH_PIN = "pin"
    }
    
    fun canHandle(uri: Uri): Boolean {
        return when (uri.scheme) {
            "iburn" -> true
            "https", "http" -> {
                val host = uri.host
                host == "iburnapp.com" || host == "www.iburnapp.com"
            }
            else -> false
        }
    }
    
    fun handle(uri: Uri, callback: (Intent?) -> Unit) {
        if (!canHandle(uri)) {
            callback(null)
            return
        }
        
        val pathSegments = uri.pathSegments
        val queryParams = extractQueryParams(uri)
        
        when (pathSegments.firstOrNull()) {
            PATH_ART, PATH_CAMP, PATH_EVENT -> {
                val type = pathSegments[0]
                val playaId = pathSegments.getOrNull(1)
                
                if (playaId != null) {
                    handleDataObject(type, playaId, queryParams, callback)
                } else {
                    callback(null)
                }
            }
            PATH_PIN -> {
                handleMapPin(queryParams, callback)
            }
            else -> {
                // Handle scheme-only URLs like iburn://art/123
                val host = uri.host
                val path = uri.path?.removePrefix("/")
                
                if (host in listOf(PATH_ART, PATH_CAMP, PATH_EVENT) && !path.isNullOrEmpty()) {
                    handleDataObject(host, path, queryParams, callback)
                } else {
                    callback(null)
                }
            }
        }
    }
    
    private fun extractQueryParams(uri: Uri): Map<String, String> {
        return uri.queryParameterNames.associateWith { name ->
            uri.getQueryParameter(name) ?: ""
        }
    }
    
    private fun handleDataObject(
        type: String,
        playaId: String,
        metadata: Map<String, String>,
        callback: (Intent?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            val playaItem = when (type) {
                PATH_ART -> database.artDao().getByPlayaId(playaId)
                PATH_CAMP -> database.campDao().getByPlayaId(playaId)
                PATH_EVENT -> database.eventDao().getByPlayaId(playaId)
                else -> null
            }
            
            withContext(Dispatchers.Main) {
                if (playaItem != null) {
                    val intent = createDetailIntent(playaItem)
                    callback(intent)
                } else {
                    // Object not found - could show search or error
                    Log.w(TAG, "Object not found: $type/$playaId")
                    showNotFoundDialog(type, playaId, metadata)
                    callback(null)
                }
            }
        }
    }
    
    private fun handleMapPin(metadata: Map<String, String>, callback: (Intent?) -> Unit) {
        val lat = metadata["lat"]?.toDoubleOrNull()
        val lng = metadata["lng"]?.toDoubleOrNull()
        val title = metadata["title"] ?: "Custom Pin"
        
        if (lat == null || lng == null) {
            Log.e(TAG, "Invalid coordinates for pin: lat=$lat, lng=$lng")
            callback(null)
            return
        }
        
        // Validate coordinates are within Black Rock City bounds
        if (!isValidBRCCoordinate(lat, lng)) {
            Log.e(TAG, "Coordinates outside BRC bounds: $lat, $lng")
            callback(null)
            return
        }
        
        // Create and save the pin
        val pin = MapPin(
            id = 0, // Auto-generate
            uid = UUID.randomUUID().toString(),
            title = title,
            description = metadata["desc"],
            latitude = lat,
            longitude = lng,
            address = metadata["addr"],
            color = metadata["color"] ?: "red",
            createdAt = System.currentTimeMillis()
        )
        
        CoroutineScope(Dispatchers.IO).launch {
            database.mapPinDao().insert(pin)
            
            withContext(Dispatchers.Main) {
                // Create intent to show map centered on pin
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = MainActivity.ACTION_SHOW_MAP_PIN
                    putExtra(MainActivity.EXTRA_PIN_ID, pin.uid)
                    putExtra(MainActivity.EXTRA_LATITUDE, lat)
                    putExtra(MainActivity.EXTRA_LONGITUDE, lng)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                callback(intent)
            }
        }
    }
    
    private fun createDetailIntent(playaItem: PlayaItem): Intent {
        return IntentUtil.viewItemDetail(context, playaItem)
    }
    
    private fun isValidBRCCoordinate(lat: Double, lng: Double): Boolean {
        // Black Rock City approximate bounds
        return lat in 40.75..40.82 && lng in -119.25..-119.17
    }
    
    private fun showNotFoundDialog(type: String, id: String, metadata: Map<String, String>) {
        val title = metadata["title"] ?: "Content"
        val message = "$title could not be found. It may not be available yet."
        
        // Show dialog or toast
        // Implementation depends on UI framework
    }
}
```

#### 2.2 MapPin.kt (New Model)

```kotlin
package com.iburnapp.iburn.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "map_pins")
data class MapPin(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val uid: String,
    val title: String,
    val description: String? = null,
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
    val color: String = "red",
    val icon: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val notes: String? = null
)
```

#### 2.3 MapPinDao.kt

```kotlin
package com.iburnapp.iburn.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Dao
interface MapPinDao {
    
    @Query("SELECT * FROM map_pins ORDER BY createdAt DESC")
    fun getAllPins(): Flow<List<MapPin>>
    
    @Query("SELECT * FROM map_pins WHERE uid = :uid")
    suspend fun getByUid(uid: String): MapPin?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(pin: MapPin): Long
    
    @Update
    suspend fun update(pin: MapPin)
    
    @Delete
    suspend fun delete(pin: MapPin)
    
    @Query("DELETE FROM map_pins WHERE uid = :uid")
    suspend fun deleteByUid(uid: String)
}
```

### Step 3: Update MainActivity

#### 3.1 Handle Deep Links in MainActivity

```kotlin
// MainActivity.kt

class MainActivity : AppCompatActivity() {
    
    companion object {
        const val ACTION_SHOW_MAP_PIN = "com.iburnapp.iburn.SHOW_MAP_PIN"
        const val EXTRA_PIN_ID = "pin_id"
        const val EXTRA_LATITUDE = "latitude"
        const val EXTRA_LONGITUDE = "longitude"
    }
    
    private lateinit var deepLinkHandler: DeepLinkHandler
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize deep link handler
        deepLinkHandler = DeepLinkHandler(this, PlayaDatabase.getInstance(this))
        
        // Handle initial intent
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            Intent.ACTION_VIEW -> {
                // Handle deep link
                intent.data?.let { uri ->
                    deepLinkHandler.handle(uri) { resultIntent ->
                        resultIntent?.let { startActivity(it) }
                    }
                }
            }
            ACTION_SHOW_MAP_PIN -> {
                // Show map centered on pin
                val lat = intent.getDoubleExtra(EXTRA_LATITUDE, 0.0)
                val lng = intent.getDoubleExtra(EXTRA_LONGITUDE, 0.0)
                val pinId = intent.getStringExtra(EXTRA_PIN_ID)
                
                showMapAtLocation(lat, lng, pinId)
            }
            // ... existing intent handling
        }
    }
    
    private fun showMapAtLocation(latitude: Double, longitude: Double, pinId: String?) {
        // Navigate to map fragment
        val mapFragment = supportFragmentManager.findFragmentById(R.id.map_container) as? MapFragment
            ?: MapFragment.newInstance()
        
        // Center map on location
        mapFragment.centerOnLocation(latitude, longitude)
        
        // Select pin if provided
        pinId?.let { mapFragment.selectPin(it) }
        
        // Show map tab
        bottomNavigation.selectedItemId = R.id.navigation_map
    }
}
```

### Step 4: Add Share Functionality

#### 4.1 ShareUrlBuilder.kt

```kotlin
package com.iburnapp.iburn.util

import android.net.Uri
import com.iburnapp.iburn.data.*
import java.text.SimpleDateFormat
import java.util.*

object ShareUrlBuilder {
    
    private const val BASE_URL = "https://iburnapp.com"
    private val ISO_8601 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US)
    
    fun buildShareUrl(item: PlayaItem): Uri {
        val builder = Uri.Builder()
            .scheme("https")
            .authority("iburnapp.com")
        
        // Add path based on type
        when (item) {
            is Art -> builder.appendPath("art").appendPath(item.playaId)
            is Camp -> builder.appendPath("camp").appendPath(item.playaId)
            is Event -> builder.appendPath("event").appendPath(item.playaId)
        }
        
        // Add metadata as query parameters
        builder.appendQueryParameter("title", item.name)
        
        item.description?.take(100)?.let { desc ->
            builder.appendQueryParameter("desc", desc)
        }
        
        item.latitude?.let { lat ->
            builder.appendQueryParameter("lat", String.format(Locale.US, "%.6f", lat))
        }
        
        item.longitude?.let { lng ->
            builder.appendQueryParameter("lng", String.format(Locale.US, "%.6f", lng))
        }
        
        item.playaAddress?.let { addr ->
            builder.appendQueryParameter("addr", addr)
        }
        
        // Event-specific parameters
        if (item is Event) {
            item.startTime?.let { start ->
                builder.appendQueryParameter("start", ISO_8601.format(Date(start)))
            }
            item.endTime?.let { end ->
                builder.appendQueryParameter("end", ISO_8601.format(Date(end)))
            }
            
            item.camp?.let { camp ->
                builder.appendQueryParameter("host", camp.name)
                builder.appendQueryParameter("host_id", camp.playaId)
                builder.appendQueryParameter("host_type", "camp")
            }
            
            item.art?.let { art ->
                builder.appendQueryParameter("host", art.name)
                builder.appendQueryParameter("host_id", art.playaId)
                builder.appendQueryParameter("host_type", "art")
            }
            
            if (item.allDay) {
                builder.appendQueryParameter("all_day", "true")
            }
        }
        
        // Add current year
        builder.appendQueryParameter("year", Calendar.getInstance().get(Calendar.YEAR).toString())
        
        return builder.build()
    }
    
    fun buildPinShareUrl(pin: MapPin): Uri {
        return Uri.Builder()
            .scheme("https")
            .authority("iburnapp.com")
            .appendPath("pin")
            .appendQueryParameter("lat", String.format(Locale.US, "%.6f", pin.latitude))
            .appendQueryParameter("lng", String.format(Locale.US, "%.6f", pin.longitude))
            .appendQueryParameter("title", pin.title)
            .apply {
                pin.description?.let { appendQueryParameter("desc", it) }
                pin.address?.let { appendQueryParameter("addr", it) }
                appendQueryParameter("color", pin.color)
            }
            .build()
    }
}
```

#### 4.2 Add Share Action to Activities

```kotlin
// PlayaItemViewActivity.kt or relevant activities

private fun shareItem() {
    val shareUrl = ShareUrlBuilder.buildShareUrl(playaItem)
    
    val shareIntent = Intent().apply {
        action = Intent.ACTION_SEND
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, "${playaItem.name} at Burning Man\n$shareUrl")
        putExtra(Intent.EXTRA_SUBJECT, playaItem.name)
    }
    
    startActivity(Intent.createChooser(shareIntent, "Share via"))
}

// In menu handling
override fun onOptionsItemSelected(item: MenuItem): Boolean {
    return when (item.itemId) {
        R.id.action_share -> {
            shareItem()
            true
        }
        else -> super.onOptionsItemSelected(item)
    }
}
```

### Step 5: Database Migration

Add the map_pins table to the database:

```kotlin
// PlayaDatabase.kt

@Database(
    entities = [
        Art::class,
        Camp::class,
        Event::class,
        MapPin::class  // Add this
    ],
    version = 2,  // Increment version
    exportSchema = true
)
abstract class PlayaDatabase : RoomDatabase() {
    
    abstract fun artDao(): ArtDao
    abstract fun campDao(): CampDao
    abstract fun eventDao(): EventDao
    abstract fun mapPinDao(): MapPinDao  // Add this
    
    companion object {
        // Migration from version 1 to 2
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("""
                    CREATE TABLE IF NOT EXISTS map_pins (
                        id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        uid TEXT NOT NULL,
                        title TEXT NOT NULL,
                        description TEXT,
                        latitude REAL NOT NULL,
                        longitude REAL NOT NULL,
                        address TEXT,
                        color TEXT NOT NULL DEFAULT 'red',
                        icon TEXT,
                        createdAt INTEGER NOT NULL,
                        notes TEXT
                    )
                """)
                
                database.execSQL("CREATE INDEX index_map_pins_uid ON map_pins(uid)")
            }
        }
        
        fun getInstance(context: Context): PlayaDatabase {
            return Room.databaseBuilder(
                context.applicationContext,
                PlayaDatabase::class.java,
                "playa_database"
            )
            .addMigrations(MIGRATION_1_2)
            .build()
        }
    }
}
```

### Step 6: assetlinks.json File

Create this file for the website repository:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.iburnapp.iburn3",
    "sha256_cert_fingerprints": [
      "YOUR_APP_SIGNING_CERTIFICATE_SHA256_FINGERPRINT"
    ]
  }
}]
```

**Important**: Replace the SHA256 fingerprint with your app's signing certificate fingerprint.

To get the fingerprint:
```bash
keytool -list -v -keystore your-release-key.keystore
```

### Step 7: Testing

#### 7.1 Test with ADB

```bash
# Test custom scheme
adb shell am start -W -a android.intent.action.VIEW -d "iburn://art/a2Id0000000cbObEAI"

# Test app links
adb shell am start -W -a android.intent.action.VIEW -d "https://iburnapp.com/camp/a1XVI000001vN7N"

# Test pin creation
adb shell am start -W -a android.intent.action.VIEW -d "iburn://pin?lat=40.7868&lng=-119.2068&title=Test%20Pin"
```

#### 7.2 Verify App Links

```bash
# Check app link verification status
adb shell pm get-app-links com.iburnapp.iburn3
```

#### 7.3 Test Matrix

| Scenario | URL | Expected Result |
|----------|-----|-----------------|
| Art object | `iburn://art/[playaId]` | Opens art detail |
| Camp object | `https://iburnapp.com/camp/[playaId]` | Opens camp detail |
| Event with host | `iburn://event/[playaId]?host=Camp%20Name` | Opens event with host info |
| Custom pin | `iburn://pin?lat=40.78&lng=-119.20&title=Test` | Creates and shows pin |
| Invalid coordinates | `iburn://pin?lat=50&lng=-100&title=Test` | Rejects (outside BRC) |
| Missing object | `iburn://art/invalid` | Shows error message |

### Step 8: ProGuard Rules

Add rules to preserve deep linking classes:

```proguard
# Deep linking
-keep class com.iburnapp.iburn.deeplink.** { *; }
-keep class com.iburnapp.iburn.data.MapPin { *; }

# Keep database entities
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao class * { *; }
```

## Performance Considerations

1. **Database Operations**: Use coroutines for all database queries
2. **Intent Processing**: Handle intents quickly to avoid ANRs
3. **Coordinate Validation**: Pre-validate before database operations
4. **URL Building**: Cache share URLs if generating frequently

## Security Considerations

1. **Input Validation**: Validate all URI parameters
2. **SQL Injection**: Use parameterized queries (Room handles this)
3. **Coordinate Bounds**: Verify coordinates are within event boundaries
4. **Intent Extras**: Validate all intent extras before use

## Troubleshooting

### Common Issues

1. **App Links not auto-verifying**
   - Check assetlinks.json is accessible at `https://iburnapp.com/.well-known/assetlinks.json`
   - Verify SHA256 fingerprint matches signing certificate
   - Ensure `android:autoVerify="true"` is set
   - Check network connectivity during app installation

2. **Deep links not opening app**
   - Verify intent filters match URL patterns
   - Check `android:exported="true"` on activities (Android 12+)
   - Test with explicit package in intent

3. **Database migration fails**
   - Check migration SQL syntax
   - Verify column types match entity fields
   - Test migration on various database states

## Future Enhancements

1. **Dynamic Links**: Firebase Dynamic Links for better analytics
2. **Deferred Deep Linking**: Handle links before app install
3. **QR Code Scanner**: Built-in QR code scanning
4. **Nearby Sharing**: Android Nearby API integration
5. **Work Manager**: Background sync of shared content

## Conclusion

This implementation provides comprehensive deep linking support for the iBurn Android app, with support for both custom URL schemes and verified App Links. The architecture follows Android best practices and integrates smoothly with the existing codebase.

---

*Last Updated: August 7, 2025*
*Platform: Android 6.0+ (API 23+)*
*Kotlin Version: 1.9.0*