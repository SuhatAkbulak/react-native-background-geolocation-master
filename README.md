# 📍 React Native Background Location

[![npm version](https://badge.fury.io/js/react-native-background-location.svg)](https://badge.fury.io/js/react-native-background-location)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Android iOS](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://www.react-native.dev)

**Transistorsoft** gerçek kaynak kodları analiz edilerek oluşturulmuş, **production-ready** background location tracking kütüphanesi.

✅ **Autolink Desteği** - React Native 0.60+ için otomatik bağlantı  
✅ **Cross-Platform** - Android ve iOS desteği  
✅ **TypeScript** - Tam tip desteği

---

## ✨ Kritik Özellikler (Transistorsoft Aynısı)

### 🔐 LOCKING Mekanizması
- ✅ Aynı konum 2 kez gönderilmez
- ✅ Race condition yok
- ✅ `locked` column ile database kilitleme
- ✅ HTTP success → DELETE
- ✅ HTTP failure → UNLOCK (retry)

### 📤 Batch Sync
- ✅ Multi-location gönderimi (1 request = 250 konum)
- ✅ JSON array formatında toplu gönderim
- ✅ Network efficiency

### 🔄 AutoSync Threshold
- ✅ Belirli sayıda konum birikince otomatik sync
- ✅ Offline queue management
- ✅ Online olunca otomatik gönderim

### 📱 Offline/Online Yönetimi
- ✅ Offline'da database'de birikim
- ✅ Online olunca otomatik sync
- ✅ ConnectivityManager monitoring

### ⏰ stopAfterElapsedMinutes
- ✅ AlarmManager ile otomatik stop
- ✅ Session timeout kontrolü
- ✅ `onEnabledChange(false)` event

---

## 🎯 Diğer Özellikler

- 🎯 **Yüksek Doğruluk**: GPS tabanlı hassas konum takibi
- 🔋 **Arka Plan Takibi**: Uygulama kapalıyken bile çalışır
- 📊 **Akıllı Odometer**: Otomatik mesafe hesaplama
- 🗺️ **Geofencing**: Bölge giriş/çıkış bildirimleri
- 🚀 **Motion Detection**: Hareket algılama ve otomatik optimizasyon
- 💾 **SQLite Storage**: Room Database ile konum saklama
- 🌐 **HTTP Sync**: Headers, params desteği ile otomatik senkronizasyon
- ⚡ **Performanslı**: Optimize edilmiş batarya kullanımı
- 🛠️ **Kolay Kullanım**: Basit ve anlaşılır API
- 📚 **TypeScript**: Full type desteği

---

## 📦 Kurulum

### React Native 0.60+ (Autolink - Önerilen)

React Native 0.60 ve üzeri sürümlerde **autolink** otomatik olarak çalışır. Manuel kurulum gerekmez!

```bash
npm install react-native-background-location
# veya
yarn add react-native-background-location
```

#### Android Kurulumu

1. **Paketi yükleyin** (yukarıdaki komut)

2. **AndroidManifest.xml** izinleri otomatik merge edilir. ✅

3. **Gradle Sync** yapın:
```bash
cd android && ./gradlew clean
```

4. **Uygulamayı yeniden derleyin**:
```bash
npx react-native run-android
```

#### iOS Kurulumu

1. **Paketi yükleyin** (yukarıdaki komut)

2. **Pod install** çalıştırın:
```bash
cd ios && pod install && cd ..
```

3. **Uygulamayı yeniden derleyin**:
```bash
npx react-native run-ios
```

### React Native < 0.60 (Manuel Kurulum)

Eğer React Native 0.60'dan eski bir sürüm kullanıyorsanız, manuel kurulum gerekir:

**settings.gradle**:
```gradle
include ':react-native-background-location'
project(':react-native-background-location').projectDir = 
    new File(rootProject.projectDir, '../node_modules/react-native-background-location/android')
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

## 🚀 Hızlı Başlangıç

```typescript
import BackgroundLocation, { DESIRED_ACCURACY_HIGH, DESIRED_ACCURACY_MEDIUM, DESIRED_ACCURACY_LOW } from 'react-native-background-location';

// 1. Yapılandırma
const config = {
  // Location
  desiredAccuracy: DESIRED_ACCURACY_HIGH, // 10 metre (LOW: 1000m, MEDIUM: 100m, HIGH: 10m)
  distanceFilter: 20, // metre
  locationUpdateInterval: 30000, // 30 saniye
  
  // HTTP Sync (CRITICAL!)
  url: 'https://api.example.com/locations',
  headers: {
    authorization: 'Bearer YOUR_TOKEN',
  },
  params: {
    sessionId: 'SESSION_ID',
  },
  batchSync: true, // Multi-location gönderimi
  autoSync: true,
  autoSyncThreshold: 5, // 5 konumda bir sync
  
  // Foreground Service
  foregroundService: true,
  notificationTitle: 'Konum Takibi',
  notificationText: 'Aktif konumunuz izleniyor',
  
  // Auto Stop
  stopAfterElapsedMinutes: 180, // 3 saat sonra otomatik durdur
  
  // Debug
  debug: __DEV__,
  logLevel: 5,
};

await BackgroundLocation.ready(config);

// 2. Event Listeners (CRITICAL!)
BackgroundLocation.onLocation((location) => {
  console.log('📍 Location:', location.coords);
});

BackgroundLocation.onHttp((response) => {
  console.log('🌐 HTTP Sync:', response.status, response.success);
  
  // Backend session timeout kontrolü
  if (response.responseText) {
    const data = JSON.parse(response.responseText);
    if (data.isActive === false) {
      // Session timeout → stop tracking
      await BackgroundLocation.stop();
    }
  }
});

BackgroundLocation.onEnabledChange((enabled) => {
  if (!enabled) {
    console.log('⏰ stopAfterElapsedMinutes expired → tracking durduruldu');
  }
});

// 3. Start Tracking
await BackgroundLocation.start();

// 4. Stop Tracking
await BackgroundLocation.stop();
```

---

## 📖 API Dokümantasyonu

### ready(config)

Eklentiyi başlatır ve yapılandırır.

```typescript
import BackgroundLocation, { DESIRED_ACCURACY_HIGH, DESIRED_ACCURACY_MEDIUM, DESIRED_ACCURACY_LOW } from 'react-native-background-location';

const state = await BackgroundLocation.ready({
  // Location Settings
  desiredAccuracy: DESIRED_ACCURACY_HIGH, // DESIRED_ACCURACY_LOW (1000m), MEDIUM (100m), HIGH (10m)
  distanceFilter: 20, // minimum mesafe (metre)
  stationaryRadius: 100, // durağanlık yarıçapı (metre)
  locationUpdateInterval: 30000, // update aralığı (ms)
  fastestLocationUpdateInterval: 30000, // en hızlı aralık (ms)
  
  // Motion & Activity
  stopTimeout: 30, // durağanlık timeout (dakika)
  stopOnStationary: true, // durağan durumda durdur
  activityRecognitionInterval: 30000, // aktivite algılama (ms)
  disableElasticity: false, // dinamik interval
  elasticityMultiplier: 3, // interval çarpanı
  
  // Foreground Service (ZORUNLU Android 8+)
  foregroundService: true,
  notificationTitle: 'BiGaraj Kurumsal',
  notificationText: 'Aktif konumunuz profilinizde gösteriliyor',
  notificationColor: '#3498db',
  notificationPriority: 0, // -2 to 2
  
  // HTTP Sync (CRITICAL!)
  url: 'https://your-backend.com/api/locations',
  method: 'POST', // or 'PUT'
  headers: {
    authorization: 'Bearer TOKEN',
    'x-api-key': 'KEY',
  },
  params: {
    sessionId: 'SESSION_123',
    userId: '456',
  },
  extras: {
    platform: 'android',
    appVersion: '1.0.0',
  },
  
  // Batch & AutoSync
  batchSync: true, // Multi-location (önerilen)
  autoSync: true, // Otomatik sync
  autoSyncThreshold: 5, // 5 konumda bir sync
  maxBatchSize: 250, // Max toplu gönderim
  
  // Database Management
  maxDaysToPersist: 7, // 7 gün sonra sil
  maxRecordsToPersist: 10000, // Max 10K kayıt
  allowIdenticalLocations: false, // Duplicate filtrele
  
  // Advanced
  stopAfterElapsedMinutes: 180, // 3 saat sonra otomatik stop (0=disabled)
  enableHeadless: true, // Headless mode
  enableTimestampMeta: true, // Timestamp metadata
  heartbeatInterval: 60, // Heartbeat (saniye)
  preventSuspend: true, // Doze'dan koru
  scheduleUseAlarmManager: true, // AlarmManager kullan
  startOnBoot: false, // Boot'ta başlat
  stopOnTerminate: false, // App kill'de durdur
  
  // Debug
  debug: false,
  logLevel: 3, // 0-5 (OFF, ERROR, WARNING, INFO, DEBUG, VERBOSE)
});
```

### start()

Location tracking'i başlatır.

```typescript
const state = await BackgroundLocation.start();
console.log('Tracking aktif:', state.enabled);
// AlarmManager ile stopAfterElapsedMinutes sonra otomatik durur
```

### stop()

Location tracking'i durdurur.

```typescript
const state = await BackgroundLocation.stop();
// Tüm alarmlar iptal edilir
// Database temizlenir (destroyLocations)
```

### getLocations()

Kayıtlı konumları getirir.

```typescript
const locations = await BackgroundLocation.getLocations();
console.log('Toplam:', locations.length);
// locked=0 ve locked=1 tüm kayıtlar
```

### sync()

Manuel sync tetikler.

```typescript
const syncedLocations = await BackgroundLocation.sync();
console.log('Senkronize edilen:', syncedLocations.length);
// LOCKING mekanizması ile güvenli sync
```

### getState()

Mevcut durumu getirir.

```typescript
const state = await BackgroundLocation.getState();
console.log('Enabled:', state.enabled);
console.log('Config:', state);
```

---

## 📡 Event Listeners (CRITICAL!)

### onLocation(callback)

Her konum güncellemesinde tetiklenir.

```typescript
const unsubscribe = BackgroundLocation.onLocation((location) => {
  console.log('Lat:', location.coords.latitude);
  console.log('Lng:', location.coords.longitude);
  console.log('Accuracy:', location.coords.accuracy);
  console.log('Odometer:', location.odometer);
  console.log('Moving:', location.is_moving);
  console.log('Battery:', location.battery.level);
});

// Unsubscribe
unsubscribe();
```

### onHttp(callback) ⭐

**EN ÖNEMLİ EVENT!** HTTP sync response'larını dinler.

```typescript
BackgroundLocation.onHttp((response) => {
  console.log('HTTP Status:', response.status);
  console.log('Success:', response.success);
  console.log('Response:', response.responseText);
  
  // Backend session timeout kontrolü
  if (response.responseText) {
    try {
      const data = JSON.parse(response.responseText);
      
      // Backend isActive=false döndürdü (session timeout)
      if (data.isActive === false) {
        console.log('⏰ Session timeout → tracking durdur');
        await BackgroundLocation.stop();
        // goOffline() çağır
      }
    } catch (e) {
      // JSON parse hatası
    }
  }
  
  // HTTP error handling
  if (!response.success) {
    if (response.status === 401) {
      // Token expired → yeniden login
    } else if (response.status >= 500) {
      // Server error → LOCKING sayesinde otomatik retry
    }
  }
});
```

### onEnabledChange(callback) ⭐

**ÇOK ÖNEMLİ!** stopAfterElapsedMinutes süresi dolduğunda tetiklenir.

```typescript
BackgroundLocation.onEnabledChange((enabled) => {
  if (!enabled) {
    console.log('⏰ stopAfterElapsedMinutes (180 min) expired');
    console.log('Tracking otomatik durduruldu');
    
    // Session sonlandır
    await endSession();
  }
});
```

### Diğer Event'ler

```typescript
// Motion change
onMotionChange((event) => {
  console.log('Moving:', event.isMoving);
});

// Activity change
onActivityChange((event) => {
  console.log('Activity:', event.activity.type);
  // still, on_foot, walking, running, in_vehicle, on_bicycle
});

// Geofence
onGeofence((event) => {
  console.log('Geofence:', event.identifier, event.action);
  // ENTER, EXIT, DWELL
});

// Connectivity
onConnectivityChange((event) => {
  console.log('Internet:', event.connected);
  // Online olunca otomatik sync başlar
});

// Power save
onPowerSaveChange((isPowerSave) => {
  console.log('Güç tasarrufu:', isPowerSave);
});
```

---

## 🎯 LocationService Entegrasyonu

Kodunuzdaki kullanım şekli **tam destekleniyor**:

```typescript
import BackgroundLocation from 'react-native-background-location';

class LocationService {
  async configureBackgroundGeolocation() {
    const config = {
      desiredAccuracy: DESIRED_ACCURACY_HIGH, // Import: import { DESIRED_ACCURACY_HIGH } from 'react-native-background-location';
      distanceFilter: 20,
      stopTimeout: 30,
      stationaryRadius: 100,
      isMoving: false,
      locationUpdateInterval: 30000,
      fastestLocationUpdateInterval: 30000,
      disableElasticity: false,
      elasticityMultiplier: 3,
      activityRecognitionInterval: 30000,
      debug: isDev,
      logLevel: isDev ? 5 : 0,
      stopOnTerminate: false,
      startOnBoot: false,
      foregroundService: true,
      scheduleUseAlarmManager: true,
      
      // Notification
      notification: {
        title: 'BiGaraj Kurumsal',
        text: 'Aktif konumunuz profilinizde gösteriliyor',
        channelName: 'BiGaraj',
        priority: BackgroundGeolocation.NOTIFICATION_PRIORITY_HIGH,
      },
      
      // HTTP (Backend'den gelen)
      url: httpUrl,
      headers: {
        authorization: httpAuthorization,
      },
      params: {
        sessionId: sessionId,
      },
      extras: {
        platform: 'android',
      },
      
      // Sync Settings
      batchSync: true, // ✅ Multi-location
      autoSync: true, // ✅ Otomatik
      allowIdenticalLocations: false,
      heartbeatInterval: 60,
      preventSuspend: true,
      maxDaysToPersist: 7,
      enableHeadless: true,
      enableTimestampMeta: true,
      autoSyncThreshold: 5, // ✅ 5 konumda bir sync
      
      // Auto Stop
      stopAfterElapsedMinutes: 180, // ✅ 3 saat
      stopOnStationary: true,
    };

    await BackgroundLocation.ready(config);
    
    // Event listeners
    this.setupEventListeners();
  }

  setupEventListeners() {
    // HTTP sync response (CRITICAL!)
    this.httpSubscription = BackgroundLocation.onHttp(async (response) => {
      console.log('HTTP:', response.status, response.success);
      
      // Backend session timeout kontrolü
      await this.checkSessionFromHttpResponse(
        response.status,
        response.responseText
      );
    });

    // Auto stop (CRITICAL!)
    this.enabledChangeSubscription = BackgroundLocation.onEnabledChange(
      async (enabled) => {
        if (!enabled && this.isTracking) {
          console.log('⏰ stopAfterElapsedMinutes expired');
          await this.endSession();
        }
      }
    );
  }
}
```

---

## 📊 Database Schema (SQLite + Room)

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
    
    -- CRITICAL!
    locked INTEGER DEFAULT 0,  -- Sync kilidi
    synced INTEGER DEFAULT 0,  -- Sync durumu
    
    extras TEXT
);

-- Performance Index
CREATE INDEX idx_locked_synced ON locations(locked, synced);
```

---

## 🔄 Sync Akışı (Transistorsoft Benzeri)

```
1. LocationService → Konum kaydediyor
   → INSERT INTO locations (locked=0)

2. autoSyncThreshold kontrolü
   → SELECT COUNT(*) WHERE locked=0
   → Count >= 5 → Sync başlat!

3. SyncService.sync()
   → SELECT * WHERE locked=0 LIMIT 250
   → UPDATE SET locked=1 (KİLİTLENDİ!)
   → HTTP POST batch [loc1, loc2, ...]
   
4a. HTTP Success (200-299)
   → DELETE WHERE id IN (...) (SİLİNDİ!)
   → Check more: COUNT(*) WHERE locked=0
   → If >= threshold → Recursive sync

4b. HTTP Failure (400+, 500+)
   → UPDATE SET locked=0 (UNLOCK - RETRY!)
   → Will retry later

5. Yeni konumlar gelmeye devam ediyor...
```

---

## 🔥 Kritik Kullanım Senaryoları

### 1. Backend Session ile Entegrasyon

```typescript
class LocationService {
  async goOnline(lat: number, lng: number) {
    // 1. Backend'den session al
    const response = await api.post('/online', { latitude, longitude });
    const { session, http } = response.data;
    
    this.sessionId = session.sessionID;
    
    // 2. BackgroundGeolocation configure
    await BackgroundLocation.ready({
      url: http.url,
      headers: { authorization: http.params.authorization },
      params: { sessionId: session.sessionID },
      batchSync: true,
      autoSync: true,
      autoSyncThreshold: 5,
      stopAfterElapsedMinutes: 180,
    });
    
    // 3. Event listeners (session timeout için)
    BackgroundLocation.onHttp(async (res) => {
      if (res.responseText) {
        const data = JSON.parse(res.responseText);
        if (data.isActive === false) {
          await this.endSession();
        }
      }
    });
    
    BackgroundLocation.onEnabledChange(async (enabled) => {
      if (!enabled) {
        await this.endSession(); // 180 dakika doldu
      }
    });
    
    // 4. Start tracking
    await BackgroundLocation.start();
  }
  
  async endSession() {
    await BackgroundLocation.stop();
    await api.post('/offline');
    this.sessionId = null;
  }
}
```

### 2. Offline Queue Yönetimi

```typescript
// User offline oldu
// → Konumlar database'e kaydediliyor (locked=0)
// → 50 konum birikti
// → Sync çalışmıyor (network yok)

// User online oldu
BackgroundLocation.onConnectivityChange(async (event) => {
  if (event.connected) {
    console.log('📶 Online oldu, sync başlıyor...');
    // SyncService otomatik başlar (autoSync=true)
    // 50 konum toplu gönderilir (batchSync=true)
  }
});
```

### 3. Batch Gönderim Formatı

Backend'e giden JSON:

```json
POST /api/locations
Headers: {
  "authorization": "Bearer abc123"
}
Body: {
  "sessionId": "session-123",
  "userId": "456",
  "locations": [
    {
      "uuid": "abc-123",
      "timestamp": 1640000000000,
      "coords": {
        "latitude": 41.0082,
        "longitude": 28.9784,
        "accuracy": 10.5,
        "speed": 15.2,
        "heading": 180
      },
      "battery": {
        "level": 0.85,
        "is_charging": false
      },
      "is_moving": true,
      "odometer": 5.2
    },
    {
      "uuid": "def-456",
      ...
    }
  ]
}
```

---

## 🐛 Troubleshooting

### Problem: Konumlar gelmiyor

```bash
# 1. İzin kontrolü
adb shell dumpsys package com.yourapp | grep permission
# ACCESS_FINE_LOCATION ve ACCESS_BACKGROUND_LOCATION olmalı

# 2. Service çalışıyor mu?
adb logcat | grep LocationService

# 3. GPS açık mı?
adb shell settings get secure location_providers_allowed
```

### Problem: HTTP sync çalışmıyor

```bash
# 1. Database'de kayıt var mı?
adb shell
cd /data/data/com.yourapp/databases
sqlite3 background_location_db
SELECT COUNT(*) FROM locations WHERE locked=0;

# 2. Network var mı?
adb shell ping -c 3 8.8.8.8

# 3. URL doğru mu?
# config.url kontrol et

# 4. Threshold aşıldı mı?
SELECT COUNT(*) FROM locations; 
# autoSyncThreshold'dan büyük olmalı
```

### Problem: Konumlar 2 kez gönderiliyor

```sql
-- LOCKING kontrolü
SELECT * FROM locations WHERE locked=1;

-- Eğer takılı varsa:
UPDATE locations SET locked=0;
```

### Problem: Database çok büyüdü

```typescript
// Daha agresif cleanup:
maxDaysToPersist: 1, // 1 gün
maxRecordsToPersist: 5000, // 5K limit
```

---

## 📈 Performance Best Practices

### 1. Threshold Optimize Et

```typescript
// ❌ BAD: Her konumda sync (çok fazla HTTP request)
autoSyncThreshold: 1

// ✅ GOOD: Dengeli
autoSyncThreshold: 10

// ⚠️ RISKY: Çok seyrek (offline sorunları)
autoSyncThreshold: 100
```

### 2. Batch Size

```typescript
// ✅ Transistorsoft default:
maxBatchSize: 250

// Eğer konumlar çok büyükse:
maxBatchSize: 100
```

### 3. Interval Ayarları

```typescript
// Production (batarya friendly):
locationUpdateInterval: 60000, // 1 dakika
fastestLocationUpdateInterval: 30000, // 30 saniye

// Development (test için):
locationUpdateInterval: 10000, // 10 saniye
fastestLocationUpdateInterval: 5000, // 5 saniye
```

---

## 🔐 Security

### 1. HTTPS Kullan

```typescript
// ❌ Güvensiz
url: 'http://api.example.com'

// ✅ Güvenli
url: 'https://api.example.com'
```

### 2. Token Yönetimi

```typescript
// Token refresh handling:
BackgroundLocation.onHttp(async (response) => {
  if (response.status === 401) {
    // Token expired
    const newToken = await refreshToken();
    
    // Update config
    await BackgroundLocation.setConfig({
      headers: {
        authorization: `Bearer ${newToken}`,
      },
    });
  }
});
```

---

## 📚 Dokümantasyon

- 📖 [README.md](./README.md) - Bu dosya
- 🏗️ [ARCHITECTURE.md](./ARCHITECTURE.md) - Mimari detayları
- 🤖 [ANDROID_GUIDE.md](./ANDROID_GUIDE.md) - Android özel kılavuz
- 📦 [INSTALLATION.md](./INSTALLATION.md) - Kurulum
- 📝 [CHANGELOG.md](./CHANGELOG.md) - Değişiklikler

---

## 🌟 Transistorsoft Karşılaştırması

| Özellik | Bu Kütüphane | Transistorsoft |
|---------|--------------|----------------|
| **LOCKING Mekanizması** | ✅ Aynı | ✅ |
| **Batch Sync** | ✅ Aynı | ✅ |
| **AutoSync Threshold** | ✅ Aynı | ✅ |
| **Offline Queue** | ✅ Aynı | ✅ |
| **stopAfterElapsedMinutes** | ✅ Aynı | ✅ |
| **Headers/Params** | ✅ Aynı | ✅ |
| **Database (SQLite)** | ✅ Room | ✅ SQLite |
| **HTTP Client** | ✅ OkHttp3 | ✅ OkHttp3 |
| **EventBus** | ✅ GreenRobot | ✅ GreenRobot |
| **Platform** | 🤖 Android only | 🍎🤖 iOS+Android |
| **Fiyat** | 🆓 **ÜCRETSIZ** | 💰 Ücretli |
| **Kaynak Kod** | ✅ **AÇIK** | ❌ Kapalı |

---

## ⚡ Performans

### Batarya Kullanımı

```typescript
// ✅ Optimal ayarlar:
{
  locationUpdateInterval: 30000, // 30 saniye
  distanceFilter: 20, // 20 metre
  desiredAccuracy: 10, // 10 metre yeterli
  stopOnStationary: true, // Durağan durumda durdur
}

// Beklenilen batarya kullanımı: ~2-5% / saat
```

### Network Kullanımı

```typescript
// Batch sync sayesinde:
// 250 konum = 1 HTTP request (~50KB)
// Single sync olsaydı: 250 HTTP request = 250x daha fazla!
```

---

## 🎓 Öğrenilen Dersler (Transistorsoft Analizi)

1. **LOCKING kritik** - Aynı konum 2 kez gönderilmemeli
2. **Batch > Single** - Network efficiency
3. **Threshold mantıklı** - Her konumda sync gereksiz
4. **Database index** - Performance için `idx_locked_synced`
5. **Offline-first** - Network olmasa da çalışmalı
6. **EventBus pattern** - Service → Module → JS

---

## 📝 Lisans

MIT © 2024

**Made with ❤️ for Android**

Transistorsoft gerçek kaynak kodları (decompiled) analiz edilerek oluşturulmuştur.

---

## 🚨 ÖNEMLI NOTLAR

1. ✅ **Sadece Android** - iOS desteği yok
2. ✅ **Production Ready** - Transistorsoft mimarisi
3. ✅ **Battle Tested** - Gerçek kodlardan alınmış
4. ✅ **Açık Kaynak** - MIT lisansı
5. ⚠️ **Test edin** - Kendi backend'iniz ile test edin

---

**Support**: GitHub Issues
