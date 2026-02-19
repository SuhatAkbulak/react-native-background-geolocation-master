# 📍 React Native Background Location

[![npm version](https://img.shields.io/npm/v/@suhatakbulak/react-native-background-location.svg)](https://www.npmjs.com/package/@suhatakbulak/react-native-background-location)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Android iOS](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://www.react-native.dev)

**npm:** [@suhatakbulak/react-native-background-location](https://www.npmjs.com/package/@suhatakbulak/react-native-background-location)

**Production-ready** background location tracking library for React Native with industry-standard architecture (locking, batch sync, autoSync).

✅ **Autolink** — Works with React Native 0.60+ out of the box  
✅ **Cross-Platform** — Android and iOS  
✅ **TypeScript** — Full type support

---

## ✨ Core Features

### 🔐 LOCKING Mechanism
- ✅ No duplicate location uploads
- ✅ No race conditions
- ✅ Database locking via `locked` column
- ✅ HTTP success → DELETE
- ✅ HTTP failure → UNLOCK (retry)

### 📤 Batch Sync
- ✅ Multi-location upload (1 request = up to 250 locations)
- ✅ JSON array batch format
- ✅ Network efficient

### 🔄 AutoSync Threshold
- ✅ Auto sync when a number of locations are queued
- ✅ Offline queue management
- ✅ Auto upload when back online

### 📱 Offline / Online
- ✅ Locations queued in DB when offline
- ✅ Auto sync when connectivity returns
- ✅ ConnectivityManager monitoring

### ⏰ stopAfterElapsedMinutes
- ✅ AlarmManager auto-stop
- ✅ Session timeout handling
- ✅ `onEnabledChange(false)` event

---

## 🎯 Other Features

- 🎯 **High accuracy** — GPS-based precise tracking
- 🔋 **Background tracking** — Runs when app is closed
- 📊 **Odometer** — Automatic distance calculation
- 🗺️ **Geofencing** — Region enter/exit events
- 🚀 **Motion detection** — Movement detection and optimization
- 💾 **SQLite storage** — Room (Android) / SQLite (iOS)
- 🌐 **HTTP sync** — Headers, params, automatic sync
- ⚡ **Battery optimized**
- 🛠️ **Simple API**
- 📚 **TypeScript** — Full type definitions

---

## 📦 Installation

### React Native 0.60+ (Autolink — Recommended)

With React Native 0.60+, **autolink** handles native linking. No manual steps required.

```bash
npm install @suhatakbulak/react-native-background-location
# or
yarn add @suhatakbulak/react-native-background-location
```

#### Android

1. Install the package (command above).
2. **AndroidManifest.xml** permissions are merged automatically.
3. Run Gradle sync:
```bash
cd android && ./gradlew clean
```
4. Rebuild the app:
```bash
npx react-native run-android
```

#### iOS

1. Install the package (command above).
2. Run Pod install:
```bash
cd ios && pod install && cd ..
```
3. Rebuild the app:
```bash
npx react-native run-ios
```

### React Native &lt; 0.60 (Manual linking)

**settings.gradle**:
```gradle
include ':react-native-background-location'
project(':react-native-background-location').projectDir =
    new File(rootProject.projectDir, '../node_modules/@suhatakbulak/react-native-background-location/android')
```

**app/build.gradle**:
```gradle
dependencies {
    implementation project(':react-native-background-location')
}
```

**MainApplication.java**:
```java
import com.backgroundlocation.RNBackgroundLocationPackage;

@Override
protected List<ReactPackage> getPackages() {
    return Arrays.asList(
        new MainReactPackage(),
        new RNBackgroundLocationPackage()
    );
}
```

---

## 🚀 Quick Start

```typescript
import BackgroundLocation, { DESIRED_ACCURACY_HIGH, DESIRED_ACCURACY_MEDIUM, DESIRED_ACCURACY_LOW } from '@suhatakbulak/react-native-background-location';

// 1. Configure
const config = {
  desiredAccuracy: DESIRED_ACCURACY_HIGH, // LOW: 1000m, MEDIUM: 100m, HIGH: 10m
  distanceFilter: 20, // meters
  locationUpdateInterval: 30000, // 30 seconds

  url: 'https://api.example.com/locations',
  headers: { authorization: 'Bearer YOUR_TOKEN' },
  params: { sessionId: 'SESSION_ID' },
  batchSync: true,
  autoSync: true,
  autoSyncThreshold: 5,

  foregroundService: true,
  notificationTitle: 'Location Tracking',
  notificationText: 'Your location is being tracked',

  stopAfterElapsedMinutes: 180, // auto-stop after 3 hours

  debug: __DEV__,
  logLevel: 5,
};

await BackgroundLocation.ready(config);

// 2. Event listeners
BackgroundLocation.onLocation((location) => {
  console.log('📍 Location:', location.coords);
});

BackgroundLocation.onHttp((response) => {
  console.log('🌐 HTTP Sync:', response.status, response.success);
  if (response.responseText) {
    const data = JSON.parse(response.responseText);
    if (data.isActive === false) {
      await BackgroundLocation.stop();
    }
  }
});

BackgroundLocation.onEnabledChange((enabled) => {
  if (!enabled) {
    console.log('⏰ stopAfterElapsedMinutes expired → tracking stopped');
  }
});

// 3. Start / Stop
await BackgroundLocation.start();
await BackgroundLocation.stop();
```

---

## 📖 API Reference

### ready(config)

Initializes and configures the plugin.

```typescript
import BackgroundLocation, { DESIRED_ACCURACY_HIGH, DESIRED_ACCURACY_MEDIUM, DESIRED_ACCURACY_LOW } from '@suhatakbulak/react-native-background-location';

const state = await BackgroundLocation.ready({
  desiredAccuracy: DESIRED_ACCURACY_HIGH, // LOW (1000m), MEDIUM (100m), HIGH (10m)
  distanceFilter: 20, // meters
  stationaryRadius: 100,
  locationUpdateInterval: 30000,
  fastestLocationUpdateInterval: 30000,

  stopTimeout: 30, // minutes
  stopOnStationary: true,
  activityRecognitionInterval: 30000,
  disableElasticity: false,
  elasticityMultiplier: 3,

  foregroundService: true,
  notificationTitle: 'Your App',
  notificationText: 'Location is being tracked',
  notificationColor: '#3498db',
  notificationPriority: 0, // -2 to 2

  url: 'https://your-backend.com/api/locations',
  method: 'POST',
  headers: { authorization: 'Bearer TOKEN', 'x-api-key': 'KEY' },
  params: { sessionId: 'SESSION_123', userId: '456' },
  extras: { platform: 'android', appVersion: '1.0.0' },

  batchSync: true,
  autoSync: true,
  autoSyncThreshold: 5,
  maxBatchSize: 250,

  maxDaysToPersist: 7,
  maxRecordsToPersist: 10000,
  allowIdenticalLocations: false,

  stopAfterElapsedMinutes: 180, // 0 = disabled
  enableHeadless: true,
  enableTimestampMeta: true,
  heartbeatInterval: 60,
  preventSuspend: true,
  scheduleUseAlarmManager: true,
  startOnBoot: false,
  stopOnTerminate: false,

  debug: false,
  logLevel: 3, // 0-5 (OFF, ERROR, WARNING, INFO, DEBUG, VERBOSE)
});
```

### start()

Starts location tracking.

```typescript
const state = await BackgroundLocation.start();
console.log('Tracking enabled:', state.enabled);
// Stops automatically after stopAfterElapsedMinutes (AlarmManager).
```

### stop()

Stops location tracking. Cancels alarms and clears locations.

```typescript
const state = await BackgroundLocation.stop();
```

### getLocations()

Returns stored locations (locked and unlocked).

```typescript
const locations = await BackgroundLocation.getLocations();
console.log('Total:', locations.length);
```

### sync()

Triggers manual sync. Uses the same locking mechanism.

```typescript
const syncedLocations = await BackgroundLocation.sync();
console.log('Synced:', syncedLocations.length);
```

### getState()

Returns current state and config.

```typescript
const state = await BackgroundLocation.getState();
console.log('Enabled:', state.enabled);
```

---

## 📡 Event Listeners

### onLocation(callback)

Fired on each location update.

```typescript
const unsubscribe = BackgroundLocation.onLocation((location) => {
  console.log('Lat:', location.coords.latitude);
  console.log('Lng:', location.coords.longitude);
  console.log('Accuracy:', location.coords.accuracy);
  console.log('Odometer:', location.odometer);
  console.log('Moving:', location.is_moving);
  console.log('Battery:', location.battery.level);
});
unsubscribe(); // to remove listener
```

### onHttp(callback) ⭐

**Important.** Listens to HTTP sync responses.

```typescript
BackgroundLocation.onHttp((response) => {
  console.log('HTTP Status:', response.status, response.success, response.responseText);

  if (response.responseText) {
    try {
      const data = JSON.parse(response.responseText);
      if (data.isActive === false) {
        await BackgroundLocation.stop();
      }
    } catch (e) {}
  }

  if (!response.success) {
    if (response.status === 401) {
      // Token expired — refresh and update config
    } else if (response.status >= 500) {
      // Server error — automatic retry via LOCKING
    }
  }
});
```

### onEnabledChange(callback) ⭐

Fired when tracking is turned off (e.g. when `stopAfterElapsedMinutes` expires).

```typescript
BackgroundLocation.onEnabledChange((enabled) => {
  if (!enabled) {
    console.log('stopAfterElapsedMinutes expired, tracking stopped');
    await endSession();
  }
});
```

### Other events

```typescript
BackgroundLocation.onMotionChange((event) => {
  console.log('Moving:', event.isMoving);
});

BackgroundLocation.onActivityChange((event) => {
  console.log('Activity:', event.activity.type);
  // still, on_foot, walking, running, in_vehicle, on_bicycle
});

BackgroundLocation.onGeofence((event) => {
  console.log('Geofence:', event.identifier, event.action); // ENTER, EXIT, DWELL
});

BackgroundLocation.onConnectivityChange((event) => {
  console.log('Online:', event.connected);
});

BackgroundLocation.onPowerSaveChange((isPowerSave) => {
  console.log('Power save:', isPowerSave);
});
```

---

## 📊 Database Schema (SQLite / Room)

```sql
CREATE TABLE locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    uuid TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    accuracy REAL,
    speed REAL,
    heading REAL,
    altitude REAL,
    timestamp INTEGER NOT NULL,
    batteryLevel REAL,
    batteryIsCharging INTEGER,
    isMoving INTEGER DEFAULT 0,
    odometer REAL DEFAULT 0,
    locked INTEGER DEFAULT 0,
    synced INTEGER DEFAULT 0,
    extras TEXT
);
CREATE INDEX idx_locked_synced ON locations(locked, synced);
```

---

## 🔄 Sync Flow

1. **LocationService** writes locations → `INSERT` with `locked=0`.
2. **AutoSync check** — `COUNT(*) WHERE locked=0`; if count ≥ threshold → start sync.
3. **SyncService.sync()** — `SELECT` up to 250 with `locked=0`, then `UPDATE SET locked=1`, then HTTP POST batch.
4. **HTTP 200–299** → `DELETE` those rows; check for more and sync again if needed.
5. **HTTP 4xx/5xx** → `UPDATE SET locked=0` so they are retried later.

---

## 🔥 Usage Examples

### Backend session integration

```typescript
async goOnline(lat: number, lng: number) {
  const response = await api.post('/online', { latitude: lat, longitude: lng });
  const { session, http } = response.data;
  this.sessionId = session.sessionID;

  await BackgroundLocation.ready({
    url: http.url,
    headers: { authorization: http.params.authorization },
    params: { sessionId: session.sessionID },
    batchSync: true,
    autoSync: true,
    autoSyncThreshold: 5,
    stopAfterElapsedMinutes: 180,
  });

  BackgroundLocation.onHttp(async (res) => {
    if (res.responseText) {
      const data = JSON.parse(res.responseText);
      if (data.isActive === false) await this.endSession();
    }
  });

  BackgroundLocation.onEnabledChange(async (enabled) => {
    if (!enabled) await this.endSession();
  });

  await BackgroundLocation.start();
}

async endSession() {
  await BackgroundLocation.stop();
  await api.post('/offline');
  this.sessionId = null;
}
```

### Offline queue

When the user is offline, locations are stored with `locked=0`. When they come back online, sync runs automatically if `autoSync` is true and `batchSync` sends them in batches.

### Batch request format

```json
POST /api/locations
Headers: { "authorization": "Bearer abc123" }
Body: {
  "sessionId": "session-123",
  "userId": "456",
  "locations": [
    {
      "uuid": "abc-123",
      "timestamp": 1640000000000,
      "coords": { "latitude": 41.0082, "longitude": 28.9784, "accuracy": 10.5, "speed": 15.2, "heading": 180 },
      "battery": { "level": 0.85, "is_charging": false },
      "is_moving": true,
      "odometer": 5.2
    }
  ]
}
```

---

## 🐛 Troubleshooting

### Locations not received

```bash
# Permissions
adb shell dumpsys package com.yourapp | grep permission
# Expect ACCESS_FINE_LOCATION and ACCESS_BACKGROUND_LOCATION

# Service
adb logcat | grep LocationService

# Location providers
adb shell settings get secure location_providers_allowed
```

### HTTP sync not working

- Check DB: `SELECT COUNT(*) FROM locations WHERE locked=0;`
- Check network and `config.url`.
- Ensure count reaches `autoSyncThreshold`.

### Duplicate uploads

- Ensure locking is used; check `SELECT * FROM locations WHERE locked=1;`. If stuck, you can `UPDATE locations SET locked=0` for retry.

### Database too large

```typescript
maxDaysToPersist: 1,
maxRecordsToPersist: 5000,
```

---

## 📈 Performance

- **autoSyncThreshold**: Prefer ~10; avoid 1 (too many requests) or very high values (slow offline drain).
- **maxBatchSize**: Default 250 is good; reduce to 100 if payloads are large.
- **Intervals**: Production: e.g. 60000 / 30000 ms; development: 10000 / 5000 ms.

---

## 🔐 Security

- Use **HTTPS** for `url`.
- On 401, refresh token and call `BackgroundLocation.setConfig({ headers: { authorization: 'Bearer ' + newToken } })`.

---

## 📝 License

MIT © 2024

---

## 📌 Notes

1. **Android & iOS** — Cross-platform support.
2. **Production ready** — Locking, batch sync, offline queue.
3. **Open source** — MIT license.
4. Test with your own backend before production.

**Support:** GitHub Issues
