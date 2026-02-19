package com.backgroundlocation.service;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.location.Location;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Bundle;
import android.os.IBinder;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;

import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.data.sqlite.SQLiteLocationDAO;
import com.backgroundlocation.service.ConnectivityMonitor;
import com.backgroundlocation.service.ActivityRecognitionService;
import com.backgroundlocation.service.HeartbeatService;
import com.backgroundlocation.service.ForegroundNotification;
import com.backgroundlocation.scheduler.TSScheduleManager;
import com.backgroundlocation.event.LocationEvent;
import com.backgroundlocation.event.EnabledChangeEvent;
import com.backgroundlocation.event.StopTimeoutEvent;
import com.backgroundlocation.event.MotionActivityCheckEvent;
import com.backgroundlocation.util.LogHelper;

import org.greenrobot.eventbus.EventBus;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationAvailability;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationResult;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.Task;

import java.util.List;

/**
 * Location Tracking Service
 * Arka planda konum güncellemelerini yönetir
 */
public class LocationService extends Service {
    
    private static final String TAG = "LocationService";
    private static final String CHANNEL_ID = "BackgroundLocationChannel";
    private static final int NOTIFICATION_ID = 12345678;
    
    private FusedLocationProviderClient fusedLocationClient;
    private Config config;
    private SQLiteLocationDAO database;
    private Location lastLocation;
    private Location lastProcessedLocation; // Son işlenen konum (duplicate kontrolü için)
    private float totalDistance = 0f;
    private long trackingStartTime = 0;
    
    // Stop detection (orijinal Transistorsoft implementasyonu)
    private Location stoppedAtLocation; // Durduğu yeri sakla
    private boolean isStopped = false; // Durdu mu kontrolü
    private LocationResult lastLocationResult; // Son location result (stop detection için)
    
    // Duplicate event prevention - UUID'leri takip et
    private final java.util.Set<String> postedLocationUUIDs = new java.util.HashSet<>();
    private static final int MAX_POSTED_UUIDS = 200;
    
    // Duplicate location prevention - aynı timestamp'li location'ları takip et
    private final java.util.Set<Long> processedLocationTimestamps = new java.util.HashSet<>();
    private static final int MAX_TRACKED_TIMESTAMPS = 100;
    
    // CRITICAL: Duplicate location processing prevention - aynı location'ı iki kez işlememek için
    // Timestamp + koordinatlar kombinasyonunu takip et (daha güvenilir)
    private final java.util.Set<String> processedLocationKeys = new java.util.HashSet<>();
    private static final int MAX_PROCESSED_KEYS = 200;
    
    // Debug bildirim throttle: en fazla 10 saniyede bir güncelle (konum çok değişmese bile spam önleme)
    private long lastDebugNotificationUpdateTime = 0;
    private static final long DEBUG_NOTIFICATION_THROTTLE_MS = 10_000;
    
    @Override
    public void onCreate() {
        super.onCreate();
        
        config = Config.getInstance(this);
        database = SQLiteLocationDAO.getInstance(this);
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);
        
        // Create notification channel
        ForegroundNotification.createNotificationChannel(this, false);
        
        // CRITICAL: Start foreground notification in onCreate
        // This ensures notification is visible immediately when service starts
        if (config.foregroundService) {
            try {
                Notification notification = ForegroundNotification.build(this);
                // Android 34+ için -1 kullan (foregroundServiceType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    // Android 14+ (API 34+)
                    startForeground(NOTIFICATION_ID, notification, -1);
                } else {
                    startForeground(NOTIFICATION_ID, notification);
                }
                LogHelper.d(TAG, "✅ Foreground notification started in onCreate");
            } catch (Exception e) {
                LogHelper.e(TAG, "Failed to start foreground in onCreate: " + e.getMessage(), e);
            }
        }
        
        // Initialize LifecycleManager
        com.backgroundlocation.lifecycle.LifecycleManager.getInstance().initialize();
        LogHelper.d(TAG, "✅ LifecycleManager initialized");
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // CRITICAL: Log EVERY onStartCommand call to debug location updates
        String action = intent != null ? intent.getAction() : "null";
        boolean hasLocationResult = intent != null && LocationResult.hasResult(intent);
        boolean hasLocationAvailability = intent != null && LocationAvailability.hasLocationAvailability(intent);
        
        LogHelper.d(TAG, "🚀 onStartCommand called - " +
                "action=" + action + 
                ", hasLocationResult=" + hasLocationResult + 
                ", hasLocationAvailability=" + hasLocationAvailability +
                ", intent=" + (intent != null ? intent.toString() : "null"));
        
        if (intent == null) {
            LogHelper.w(TAG, "⚠️ Intent is null, returning START_STICKY");
            return START_STICKY;
        }
        
        // Check if this is a stop command (stopAfterElapsedMinutes)
        if ("STOP_TRACKING".equals(action)) {
            LogHelper.i(TAG, "⏰ stopAfterElapsedMinutes expired, stopping service");
            
            config.enabled = false;
            config.save();
            
            // Emit enabledchange event (direct EventBus)
            EventBus.getDefault().post(new EnabledChangeEvent(false));
            
            stopSelf();
            return START_NOT_STICKY;
        }
        
        // CRITICAL: Handle location updates from PendingIntent
        // Bu arka planda çalışması için çok önemli!
        if (LocationResult.hasResult(intent)) {
            LogHelper.d(TAG, "✅ LocationResult.hasResult() = TRUE - extracting location...");
            LocationResult locationResult = LocationResult.extractResult(intent);
            if (locationResult != null) {
                // Tüm LocationResult'ı bir kerede işle
                handleLocationResult(locationResult);
            } else {
                LogHelper.w(TAG, "⚠️ LocationResult.extractResult() returned null!");
            }
            return START_STICKY;
        } else {
            LogHelper.d(TAG, "❌ LocationResult.hasResult() = FALSE - not a location update");
        }
        
        // Handle location availability changes
        if (LocationAvailability.hasLocationAvailability(intent)) {
            LocationAvailability availability = LocationAvailability.extractLocationAvailability(intent);
            if (availability != null && !availability.isLocationAvailable()) {
                LogHelper.w(TAG, "⚠️ Location services unavailable");
            }
            return START_STICKY;
        }
        
        // Normal start command
        if (action == null || "start".equals(action)) {
            // CRITICAL: Check if tracking is enabled
            // If service was restarted (START_STICKY) and stopOnTerminate=false,
            // config.enabled should still be true
            if (!config.enabled) {
                LogHelper.d(TAG, "⏸️ Tracking is disabled, not starting location updates");
                return START_STICKY;
            }
            
            // CRITICAL: Set enabled flag BEFORE starting services
            // (Only if explicitly started via "start" action, not on restart)
            if ("start".equals(action)) {
                config.enabled = true;
                config.save();
            }
            
            // Start connectivity monitoring
            // Only start if autoSync is enabled and tracking is active
            if (config.autoSync) {
                ConnectivityMonitor.getInstance(this).startMonitoring();
                LogHelper.d(TAG, "✅ Connectivity monitoring started");
            }
            
            // Start Activity Recognition Service
            if (!config.disableMotionActivityUpdates) {
                ActivityRecognitionService.start(this);
                LogHelper.d(TAG, "✅ Activity recognition started");
            }
            
            // Start Heartbeat Service
            if (config.heartbeatInterval > 0) {
                HeartbeatService.start(this);
                LogHelper.d(TAG, "✅ Heartbeat service started");
            }
            
            if (config.foregroundService) {
                // Use ForegroundNotification.build() for consistent notification
                ForegroundNotification.createNotificationChannel(this, false);
                Notification notification = ForegroundNotification.build(this);
                // Android 34+ için -1 kullan (foregroundServiceType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIFICATION_ID, notification, -1);
                } else {
                    startForeground(NOTIFICATION_ID, notification);
                }
                LogHelper.d(TAG, "✅ Foreground notification started");
            }
            
            // Start tracking timer
            if (trackingStartTime == 0) {
                trackingStartTime = System.currentTimeMillis();
                scheduleAutoStop();
            }
            
            startLocationUpdates();
        }
        
        return START_STICKY;
    }
    
    /**
     * Schedule auto stop based on stopAfterElapsedMinutes
     * Exact alarm kullanmıyoruz - sadece setWindow kullanıyoruz
     */
    private void scheduleAutoStop() {
        if (config.stopAfterElapsedMinutes > 0) {
            long stopTimeMillis = System.currentTimeMillis() + 
                    (config.stopAfterElapsedMinutes * 60L * 1000L);
            
            AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) {
                LogHelper.e(TAG, "AlarmManager is null, cannot schedule auto stop");
                return;
            }
            
            Intent stopIntent = new Intent(this, LocationService.class);
            stopIntent.setAction("STOP_TRACKING");
            
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                flags |= PendingIntent.FLAG_IMMUTABLE;
            }
            
            PendingIntent pendingIntent = PendingIntent.getService(
                    this, 
                    99999, 
                    stopIntent, 
                    flags
            );
            
            // Exact alarm kullanmıyoruz - sadece setWindow kullanıyoruz
            // Bu izin gerektirmez ve daha güvenilir çalışır
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setWindow(
                        AlarmManager.RTC_WAKEUP,
                        stopTimeMillis,
                        60000, // Allow 1 minute window
                        pendingIntent
                );
            } else {
                alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        stopTimeMillis,
                        pendingIntent
                );
            }
            
            LogHelper.d(TAG, "✅ Auto stop scheduled (inexact): " + 
                    config.stopAfterElapsedMinutes + " minutes");
        }
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        
        // CRITICAL: Check stopOnTerminate before stopping service
        // If stopOnTerminate = false, service should continue in background
        if (config.stopOnTerminate) {
            LogHelper.d(TAG, "🛑 stopOnTerminate: true - Stopping service");
            
            // Set enabled flag BEFORE stopping services
            // This prevents sync operations from continuing after destroy
            config.enabled = false;
            config.save();
            
            stopLocationUpdates();
            
            // Stop connectivity monitoring
            ConnectivityMonitor.getInstance(this).stopMonitoring();
            LogHelper.d(TAG, "✅ Connectivity monitoring stopped");
            
            // Stop Activity Recognition Service
            ActivityRecognitionService.stop(this);
            LogHelper.d(TAG, "✅ Activity recognition stopped");
            
            // Stop Heartbeat Service
            HeartbeatService.stop(this);
            LogHelper.d(TAG, "✅ Heartbeat service stopped");
        } else {
            // stopOnTerminate: false - Service should continue in background
            // Don't stop anything, just log
            LogHelper.d(TAG, "✅ stopOnTerminate: false - Service will continue in background");
            LogHelper.d(TAG, "✅ enabled=" + config.enabled + " - Tracking continues");
            
            // CRITICAL: Do NOT set enabled = false
            // Do NOT stop location updates
            // Do NOT stop other services
            // Service will be restarted by Android (START_STICKY)
        }
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    /**
     * Get PendingIntent for location updates
     * CRITICAL: PendingIntent kullanmak arka planda çalışması için zorunlu!
     * FLAG_MUTABLE is used for Android 31+ instead of FLAG_IMMUTABLE
     */
    public static PendingIntent getPendingIntent(Context context) {
        // CRITICAL: Use applicationContext
        // This prevents memory leaks and ensures the PendingIntent works correctly
        Context applicationContext = context.getApplicationContext();
        Intent intent = new Intent(applicationContext, LocationService.class);
        // FLAG_UPDATE_CURRENT (134217728 = 0x08000000)
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        // FLAG_MUTABLE is used for Android 31+ instead of FLAG_IMMUTABLE
        // NOT FLAG_IMMUTABLE! This is critical for location updates to work
        // FLAG_MUTABLE allows system to update the PendingIntent, which is needed for location updates
        if (Build.VERSION.SDK_INT >= 31) {
            // Android 12+ (API 31+): Use FLAG_MUTABLE instead of FLAG_IMMUTABLE
            flags |= PendingIntent.FLAG_MUTABLE; // FLAG_MUTABLE
        }
        // getForegroundService kullan - arka plan için kritik!
        PendingIntent pendingIntent = PendingIntent.getForegroundService(applicationContext, 0, intent, flags);
        LogHelper.d(TAG, "🔧 Created PendingIntent: flags=" + flags + ", intent=" + intent);
        return pendingIntent;
    }
    
    /**
     * Start location updates using PendingIntent
     * LocationCallback yerine PendingIntent kullanıyoruz - arka planda çalışması için!
     */
    private void startLocationUpdates() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
                != PackageManager.PERMISSION_GRANTED) {
            LogHelper.w(TAG, "Location permission not granted");
            return;
        }
        
        // Background location izni kontrolü (Android 10+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) 
                    != PackageManager.PERMISSION_GRANTED) {
                LogHelper.w(TAG, "Background location permission not granted - using foreground service");
                // Yine de devam et - foreground service ile çalışabilir
            }
        }
        
        // CRITICAL: desiredAccuracy to Priority mapping
        // getDesiredAccuracy() calls translateDesiredAccuracy() which maps:
        //   -2, -1, 0 → 100 (HIGH_ACCURACY)
        //   10 → 102 (BALANCED)
        //   100 → 104 (LOW_POWER) - BUT only if useCLLocationAccuracy=true
        //   1000, 3000 → 105 (NO_POWER)
        // Otherwise (normal case), desiredAccuracy is used directly as Priority
        // Priority values: 100(HIGH_ACCURACY), 102(BALANCED), 104(LOW_POWER), 105(NO_POWER)
        // Default desiredAccuracy: 100 → Priority: 100 (HIGH_ACCURACY) in normal case
        int priority;
        if (config.desiredAccuracy == -2 || config.desiredAccuracy == -1 || config.desiredAccuracy == 0) {
            priority = Priority.PRIORITY_HIGH_ACCURACY; // 100
        } else if (config.desiredAccuracy == 10) {
            priority = Priority.PRIORITY_BALANCED_POWER_ACCURACY; // 102
        } else if (config.desiredAccuracy == 100) {
            // In normal case (useCLLocationAccuracy=false), 100 → 100 (HIGH_ACCURACY)
            // But if useCLLocationAccuracy=true, 100 → 104 (LOW_POWER)
            // We use HIGH_ACCURACY for 100 (normal case)
            priority = Priority.PRIORITY_HIGH_ACCURACY; // 100
        } else if (config.desiredAccuracy == 1000 || config.desiredAccuracy == 3000) {
            priority = 105; // PRIORITY_NO_POWER (constant not available in Priority enum, use direct value)
        } else {
            // Default: Use HIGH_ACCURACY
            priority = Priority.PRIORITY_HIGH_ACCURACY; // 100
        }
        
        // CRITICAL: Validate distanceFilter
        // distanceFilter < 0 is invalid, use default 10m
        float distanceFilter = config.distanceFilter;
        if (distanceFilter < 0) {
            LogHelper.w(TAG, "Invalid distanceFilter: " + distanceFilter + ". Applying default 10.0m");
            distanceFilter = 10.0f;
        }
        
        // Use old API (LocationRequest.create)
        LocationRequest locationRequest = LocationRequest.create();
        locationRequest.setPriority(priority);
        
        // ============================================================
        // INTERVAL vs FASTEST_INTERVAL AÇIKLAMASI:
        // ============================================================
        // 
        // locationUpdateInterval (interval):
        //   - Sistemin location update göndermesi için BEKLEDİĞİ süre
        //   - Örnek: 10000ms = "Her 10 saniyede bir update göndermeye çalış"
        //   - Bu bir "hedef" süredir, kesin değildir
        //   - Sistem batarya/performans için bu süreyi geciktirebilir
        //
        // fastestLocationUpdateInterval (fastestInterval):
        //   - Sistemin location update gönderebileceği EN HIZLI süre (rate limiting)
        //   - Örnek: 5000ms = "En fazla 5 saniyede bir update gönderebilirsin"
        //   - Bu bir "limit"tir, kesindir
        //   - Sistem bu süreden DAHA HIZLI update gönderemez
        //
        // ÖRNEK (interval=10000, fastestInterval=5000):
        //   - Normal durum: Her 10 saniyede bir update gelir
        //   - Ama eğer başka bir app location istiyorsa veya sistem daha sık
        //     update göndermek isterse, fastestInterval (5 saniye) limiti
        //     içinde kalarak daha sık gönderebilir
        //   - SONUÇ: 5-10 saniye arası update alırsın (genelde 10 saniye)
        //
        // ============================================================
        
        // Set interval: Sistemin location update göndermesi için beklediği süre
        // 0 = En hızlı şekilde (test için), >0 = Her X ms'de bir (production)
        long interval = config.locationUpdateInterval;
        if (interval <= 0) {
            interval = 0; // 0 = En hızlı şekilde (test için)
        }
        locationRequest.setInterval(interval);
        
        // Set fastest interval: Sistemin update gönderebileceği EN HIZLI süre (rate limiting)
        // Bu bir "limit"tir - sistem bu süreden DAHA HIZLI update gönderemez
        // Sadece >= 0 ise set et, -1 ise hiç set etme (Android default: 30s)
        // interval'den küçük olmalı (örn: interval=10000, fastestInterval=5000)
        if (config.fastestLocationUpdateInterval >= 0) {
            long fastestInterval = config.fastestLocationUpdateInterval;
            if (fastestInterval <= 0) {
                fastestInterval = 0; // 0 = Limit yok (test için)
            }
            locationRequest.setFastestInterval(fastestInterval);
        }
        // Eğer < 0 ise (örn: -1), hiç set etme - Android'in default'unu kullan (30 saniye)
        
        // Set distance filter: 0 means use interval-based updates
        // If > 0, only get updates when moved that distance (overrides interval)
        // CRITICAL: distanceFilter=0 is required for locationUpdateInterval to work!
        locationRequest.setSmallestDisplacement(distanceFilter);
        
        // Set max wait time: 0 means get updates immediately, no batching
        // Production: 0 is recommended for real-time tracking
        locationRequest.setMaxWaitTime(0);
        
        LogHelper.d(TAG, "📋 LocationRequest config: " +
                "priority=" + priority + 
                ", interval=" + config.locationUpdateInterval + "ms" +
                ", fastestInterval=" + (config.fastestLocationUpdateInterval >= 0 ? config.fastestLocationUpdateInterval : "default") + "ms" +
                ", smallestDisplacement=" + distanceFilter + "m" +
                ", maxWaitTime=0ms");
        
        try {
            // CRITICAL: Remove old location updates first
            // This ensures we don't have duplicate requests
            PendingIntent oldPendingIntent = getPendingIntent(this);
            try {
                fusedLocationClient.removeLocationUpdates(oldPendingIntent);
                LogHelper.d(TAG, "🧹 Removed old location updates");
            } catch (Exception e) {
                // Ignore - no old updates to remove
                LogHelper.d(TAG, "No old location updates to remove");
            }
            
            // CRITICAL: PendingIntent kullan - LocationCallback arka planda çalışmaz!
            PendingIntent pendingIntent = getPendingIntent(this);
            
            LogHelper.d(TAG, "📡 Requesting location updates - " +
                    "priority: " + priority + ", interval: " + 
                    config.locationUpdateInterval + "ms, distance: " + 
                    distanceFilter + "m, desiredAccuracy: " + config.desiredAccuracy);
            LogHelper.d(TAG, "📡 PendingIntent: " + pendingIntent + 
                    " (isImmutable: " + (Build.VERSION.SDK_INT >= 23 ? pendingIntent.isImmutable() : "N/A") + ")");
            
            // CRITICAL: Check if PendingIntent is valid
            if (pendingIntent == null) {
                LogHelper.e(TAG, "❌ PendingIntent is NULL! Cannot request location updates!");
                return;
            }
            
            fusedLocationClient.requestLocationUpdates(
                    locationRequest,
                    pendingIntent
            );
            
            LogHelper.d(TAG, "✅ Location updates requested successfully (PendingIntent)");
            LogHelper.d(TAG, "⏳ Waiting for location updates... (check onStartCommand logs)");
            LogHelper.d(TAG, "🔍 DEBUG: If no location updates arrive, check:");
            LogHelper.d(TAG, "   1. Location services enabled in device settings");
            LogHelper.d(TAG, "   2. Battery optimization disabled for this app");
            LogHelper.d(TAG, "   3. Location permissions granted (FINE + BACKGROUND)");
            LogHelper.d(TAG, "   4. Device is not in Doze mode");
            LogHelper.d(TAG, "   5. LocationRequest config: interval=" + interval + "ms, fastest=" + 
                    (config.fastestLocationUpdateInterval >= 0 ? config.fastestLocationUpdateInterval : "default") + "ms");
            
            // NOT: getInitialLocation() çağrısını kaldırdık - duplicate location sorununa neden oluyordu
            // requestLocationUpdates() ile gelen ilk location update yeterli
            // Duplicate kontrolü handleLocationUpdate() içinde yapılıyor
            // getInitialLocation(); // REMOVED: Causes duplicate locations on start
        } catch (SecurityException e) {
            LogHelper.e(TAG, "Failed to start location updates: " + e.getMessage(), e);
        } catch (Exception e) {
            LogHelper.e(TAG, "Error starting location updates: " + e.getMessage(), e);
        }
    }
    
    /**
     * Get initial location immediately
     * PendingIntent ile updates başlatıldığında ilk lokasyon gecikebilir
     * Bu yüzden getLastLocation() ile hemen bir lokasyon alıyoruz
     */
    private void getInitialLocation() {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
                != PackageManager.PERMISSION_GRANTED) {
            LogHelper.w(TAG, "Cannot get initial location: permission not granted");
            return;
        }
        
        try {
            Task<Location> locationTask = fusedLocationClient.getLastLocation();
            locationTask.addOnSuccessListener(new OnSuccessListener<Location>() {
                @Override
                public void onSuccess(Location location) {
                    if (location != null) {
                        // Lokasyon yaşı kontrolü - çok eski lokasyonları kullanma
                        long locationAge = System.currentTimeMillis() - location.getTime();
                        long maxAge = 5 * 60 * 1000; // 5 dakika
                        
                        if (locationAge < maxAge) {
                            LogHelper.d(TAG, "✅ Initial location obtained: " + 
                                    location.getLatitude() + ", " + location.getLongitude() + 
                                    " (age: " + (locationAge / 1000) + "s)");
                            handleLocationUpdate(location);
                        } else {
                            LogHelper.d(TAG, "⚠️ Initial location too old: " + 
                                    (locationAge / 1000) + "s, waiting for fresh location");
                            // Eski bile olsa, en azından bir lokasyon gönder
                            // Kullanıcı hiç lokasyon görmemektense eski lokasyon görmek daha iyi
                            LogHelper.d(TAG, "📌 Using old location as fallback");
                            handleLocationUpdate(location);
                        }
                    } else {
                        LogHelper.d(TAG, "⚠️ Initial location is null, waiting for location updates");
                    }
                }
            }).addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(Exception e) {
                    LogHelper.w(TAG, "Failed to get initial location: " + e.getMessage());
                    // Hata olsa bile devam et - location updates çalışmaya devam edecek
                }
            });
        } catch (SecurityException e) {
            LogHelper.e(TAG, "SecurityException getting initial location: " + e.getMessage(), e);
        } catch (Exception e) {
            LogHelper.e(TAG, "Error getting initial location: " + e.getMessage(), e);
        }
    }
    
    /**
     * Stop location updates
     */
    private void stopLocationUpdates() {
        if (fusedLocationClient != null) {
            try {
                PendingIntent pendingIntent = getPendingIntent(this);
                fusedLocationClient.removeLocationUpdates(pendingIntent);
                LogHelper.d(TAG, "✅ Location updates stopped");
            } catch (Exception e) {
                LogHelper.e(TAG, "Error stopping location updates: " + e.getMessage(), e);
            }
        }
    }
    
    /**
     * Handle LocationResult
     * Tüm LocationResult'ı bir kerede işler
     */
    private void handleLocationResult(LocationResult locationResult) {
        if (locationResult == null) {
            LogHelper.w(TAG, "⚠️ LocationResult is null");
            return;
        }
        
        // LocationResult'dan tüm location'ları al
        List<Location> locations = locationResult.getLocations();
        if (locations == null || locations.isEmpty()) {
            LogHelper.w(TAG, "⚠️ LocationResult.getLocations() is empty");
            return;
        }
        
        int locationCount = locations.size();
        LogHelper.d(TAG, "═══════════════════════════════════════════════════════════");
        LogHelper.d(TAG, "📍 LocationResult received: " + locationCount + " locations");
        LogHelper.d(TAG, "═══════════════════════════════════════════════════════════");
        
        // Last location'ı geofence manager'a set et
        Location lastLocation = locationResult.getLastLocation();
        if (lastLocation == null) {
            LogHelper.w(TAG, "⚠️ LocationResult.getLastLocation() is null");
            return;
        }
        
        // Her location için işle
        // CRITICAL: Aynı location'ı iki kez işlememek için timestamp kontrolü yap
        for (int i = 0; i < locations.size(); i++) {
            Location location = locations.get(i);
            if (location == null) {
                LogHelper.w(TAG, "⚠️ Location[" + i + "] is null, skipping");
                continue;
            }
            
            // CRITICAL: Aynı timestamp'li location'ı iki kez işleme (LocationResult içinde duplicate olabilir)
            long locationTimestamp = location.getTime();
            synchronized (processedLocationTimestamps) {
                if (processedLocationTimestamps.contains(locationTimestamp)) {
                    // Bu timestamp zaten işlenmiş, skip
                    LogHelper.d(TAG, "⚠️ Location[" + i + "] DUPLICATE timestamp in LocationResult: " + locationTimestamp + ", skipping");
                    continue;
                }
                
                // Timestamp'i set'e ekle
                processedLocationTimestamps.add(locationTimestamp);
                
                // Set çok büyüdüyse eski kayıtları temizle
                if (processedLocationTimestamps.size() > MAX_TRACKED_TIMESTAMPS) {
                    // En eski timestamp'i kaldır
                    Long oldestTimestamp = processedLocationTimestamps.iterator().next();
                    processedLocationTimestamps.remove(oldestTimestamp);
                }
            }
            
            // Ek kontrol: Aynı timestamp VE aynı koordinatlar
            if (lastProcessedLocation != null && lastProcessedLocation.getTime() == locationTimestamp) {
                double epsilon = 0.0000001;
                if (Math.abs(lastProcessedLocation.getLatitude() - location.getLatitude()) < epsilon &&
                    Math.abs(lastProcessedLocation.getLongitude() - location.getLongitude()) < epsilon) {
                    LogHelper.d(TAG, "⚠️ Location[" + i + "] DUPLICATE in LocationResult (same timestamp & coordinates), skipping");
                    continue; // Skip duplicate in LocationResult
                }
            }
            
            // Extras kontrolü
            if (location.getExtras() == null) {
                location.setExtras(new Bundle());
            }
            
            // DETAYLI LOG: Sensörden gelen tüm verileri logla
            long locationAge = System.currentTimeMillis() - location.getTime();
            StringBuilder locationInfo = new StringBuilder();
            locationInfo.append("📍 Location[").append(i).append("] from sensor:\n");
            locationInfo.append("   └─ Coordinates: ").append(location.getLatitude()).append(", ").append(location.getLongitude()).append("\n");
            locationInfo.append("   └─ Accuracy: ").append(location.getAccuracy()).append("m\n");
            locationInfo.append("   └─ Provider: ").append(location.getProvider() != null ? location.getProvider() : "null").append("\n");
            locationInfo.append("   └─ Time: ").append(location.getTime()).append(" (").append(locationAge / 1000).append("s ago)\n");
            locationInfo.append("   └─ Speed: ").append(location.hasSpeed() ? location.getSpeed() : "N/A").append(" m/s\n");
            locationInfo.append("   └─ Bearing: ").append(location.hasBearing() ? location.getBearing() : "N/A").append("°\n");
            locationInfo.append("   └─ Altitude: ").append(location.hasAltitude() ? location.getAltitude() : "N/A").append("m\n");
            locationInfo.append("   └─ From Mock: ").append(location.isFromMockProvider()).append("\n");
            if (lastProcessedLocation != null) {
                float distance = lastProcessedLocation.distanceTo(location);
                locationInfo.append("   └─ Distance from last: ").append(distance).append("m\n");
            }
            LogHelper.d(TAG, locationInfo.toString());
            
            // Her location'ı işle
            // TSLocationManager.onLocationResult() içinde de her location için buildTSLocation() çağrılıyor
            handleLocationUpdate(location);
        }
        
        LogHelper.d(TAG, "═══════════════════════════════════════════════════════════");
    }
    
    /**
     * Handle location update
     */
    private void handleLocationUpdate(Location location) {
        if (location == null) {
            return;
        }
        
        // CRITICAL: Duplicate processing prevention - aynı location'ı iki kez işleme
        // Timestamp + koordinatlar kombinasyonu ile unique key oluştur
        String locationKey = location.getTime() + "_" + 
                            String.format("%.7f", location.getLatitude()) + "_" + 
                            String.format("%.7f", location.getLongitude());
        
        synchronized (processedLocationKeys) {
            if (processedLocationKeys.contains(locationKey)) {
                // Bu location zaten işlenmiş, skip et
                LogHelper.d(TAG, "⚠️ DUPLICATE location processing prevented: " + locationKey);
                return;
            }
            
            // Key'i set'e ekle
            processedLocationKeys.add(locationKey);
            
            // Set çok büyüdüyse eski kayıtları temizle
            if (processedLocationKeys.size() > MAX_PROCESSED_KEYS) {
                String oldestKey = processedLocationKeys.iterator().next();
                processedLocationKeys.remove(oldestKey);
            }
        }
        
        // CRITICAL: Dynamic distance filter elasticity (orijinal Transistorsoft hesaplaması)
        // Orijinal: TSLocationManager.onLocationResult() içinde yapılıyor
        // Sadece location tracking mode'da, distanceFilter > 0, disableElasticity false ise
        if (config.distanceFilter > 0 && !config.disableElasticity && 
            location.hasSpeed() && !Float.isNaN(location.getSpeed()) && 
            location.getAccuracy() <= 100.0f) { // MAXIMUM_LOCATION_ACCURACY = 100
            
            float calculatedDistanceFilter = config.calculateDistanceFilter(location.getSpeed());
            
            // Eğer hesaplanan distance filter farklıysa, location request'i güncelle
            // NOT: Bu performans sorununa neden olabilir, bu yüzden sadece önemli fark varsa güncelle
            if (Math.abs(calculatedDistanceFilter - config.distanceFilter) > 10.0f) {
                LogHelper.d(TAG, "🔄 Re-scaling distanceFilter: " + config.distanceFilter + "m -> " + 
                           calculatedDistanceFilter + "m (speed: " + location.getSpeed() + " m/s)");
                
                // Location request'i güncelle (async olarak, performans için)
                // NOT: Her location'da güncelleme yapmak performans sorununa neden olabilir
                // Bu yüzden sadece önemli fark varsa güncelle
                // startLocationUpdates(); // REMOVED: Performance issue - too frequent updates
            }
        }
        
        // CRITICAL: Duplicate kontrolü
        // Timestamp aynı VE latitude, longitude, speed, bearing hepsi aynı ise → identical
        // Veya sadece latitude ve longitude aynı ise → identical
        // PERFORMANCE: getTime() == karşılaştırması çok hızlı (tek CPU cycle, nanosecond seviyesinde)
        //              Bu, double karşılaştırmalarından (lat/lng) çok daha hızlı, endişe yok!
        if (lastProcessedLocation != null) {
            boolean isIdentical = false;
            double epsilon = 0.0000001; // GPS koordinatları için epsilon (yaklaşık 1cm)
            
            // PERFORMANCE: Timestamp karşılaştırması en hızlı yöntem (long primitive, tek CPU cycle)
            long lastTime = lastProcessedLocation.getTime();
            long currentTime = location.getTime();
            
            if (lastTime == currentTime) {
                // Timestamp aynı VE latitude, longitude, speed, bearing hepsi aynı ise → identical
                if (Math.abs(lastProcessedLocation.getLatitude() - location.getLatitude()) < epsilon &&
                    Math.abs(lastProcessedLocation.getLongitude() - location.getLongitude()) < epsilon &&
                    Math.abs(lastProcessedLocation.getSpeed() - location.getSpeed()) < 0.01f &&
                    Math.abs(lastProcessedLocation.getBearing() - location.getBearing()) < 0.01f) {
                    isIdentical = true;
                }
            } else {
                // Timestamp farklı ama latitude ve longitude aynı ise → identical
                if (Math.abs(lastProcessedLocation.getLatitude() - location.getLatitude()) < epsilon &&
                    Math.abs(lastProcessedLocation.getLongitude() - location.getLongitude()) < epsilon) {
                    isIdentical = true;
                }
            }
            
            if (isIdentical) {
                // allowIdenticalLocations kontrolü
                if (!config.allowIdenticalLocations) {
                    StringBuilder identicalInfo = new StringBuilder();
                    identicalInfo.append("⚠️ IGNORED: same as last location (DUPLICATE PREVENTED)\n");
                    identicalInfo.append("   └─ Last: ").append(lastProcessedLocation.getLatitude()).append(", ").append(lastProcessedLocation.getLongitude()).append(" (time: ").append(lastProcessedLocation.getTime()).append(")\n");
                    identicalInfo.append("   └─ Current: ").append(location.getLatitude()).append(", ").append(location.getLongitude()).append(" (time: ").append(location.getTime()).append(")\n");
                    identicalInfo.append("   └─ allowIdenticalLocations: ").append(config.allowIdenticalLocations);
                    LogHelper.d(TAG, identicalInfo.toString());
                    return; // CRITICAL: Return early to prevent duplicate SQL insert
                } else {
                    LogHelper.d(TAG, "ℹ️ Same as last location (allowIdenticalLocations=true, will persist)");
                }
            } else {
                // Farklı location - detaylı karşılaştırma logu
                StringBuilder diffInfo = new StringBuilder();
                diffInfo.append("🔍 Location DIFFERENT from last:\n");
                diffInfo.append("   └─ Lat diff: ").append(Math.abs(lastProcessedLocation.getLatitude() - location.getLatitude())).append("\n");
                diffInfo.append("   └─ Lng diff: ").append(Math.abs(lastProcessedLocation.getLongitude() - location.getLongitude())).append("\n");
                diffInfo.append("   └─ Time diff: ").append(location.getTime() - lastProcessedLocation.getTime()).append("ms\n");
                diffInfo.append("   └─ Distance: ").append(lastProcessedLocation.distanceTo(location)).append("m");
                LogHelper.d(TAG, diffInfo.toString());
            }
        } else {
            LogHelper.d(TAG, "ℹ️ First location (no duplicate check)");
        }
        
        // DETAYLI LOG: İşlenen location bilgileri
        StringBuilder processInfo = new StringBuilder();
        processInfo.append("✅ Processing location:\n");
        processInfo.append("   └─ Coordinates: ").append(location.getLatitude()).append(", ").append(location.getLongitude()).append("\n");
        processInfo.append("   └─ Accuracy: ").append(location.getAccuracy()).append("m\n");
        if (lastLocation != null) {
            float distance = lastLocation.distanceTo(location);
            processInfo.append("   └─ Distance from last: ").append(distance).append("m\n");
        }
        LogHelper.d(TAG, processInfo.toString());
        
        // Calculate distance and odometer (orijinal Transistorsoft hesaplaması)
        if (lastLocation != null) {
            // Orijinal formül: distanceTo >= (location.getAccuracy() + lastLocation.getAccuracy()) / 2.0f
            // Accuracy kontrolü: Sadece gerçek mesafe accuracy'den büyükse odometer'ı artır
            float distanceTo = location.distanceTo(lastLocation);
            float accuracyThreshold = (location.getAccuracy() + lastLocation.getAccuracy()) / 2.0f;
            
            if (distanceTo >= accuracyThreshold) {
                // Filter out unrealistic movements (less than 1km)
                float distanceKm = distanceTo / 1000f;
                if (distanceKm < 1.0f) {
                    // Orijinal Transistorsoft: incrementOdometer kullan
                    config.incrementOdometer(distanceTo);
                    totalDistance = config.odometer; // Sync with config
                }
            }
        }
        
        // CRITICAL: lastProcessedLocation'ı duplicate check'ten SONRA set et
        // Böylece bir sonraki location için duplicate check çalışır
        lastLocation = location;
        lastProcessedLocation = new Location(location); // Duplicate kontrolü için kopyala (SONRA set et)
        
        // Create location model JSON
        LocationModel locationModel = createLocationModel(location);
        
        // Save to SQLite database (as BLOB)
        // CRITICAL: Duplicate check'ten geçti, artık SQL'e kaydedebiliriz
        String uuid = database.persist(locationModel.toJSON());
        
        if (uuid != null) {
            // CRITICAL: Duplicate event prevention - aynı UUID'yi birden fazla kez post etme
            synchronized (postedLocationUUIDs) {
                if (postedLocationUUIDs.contains(uuid)) {
                    // Bu UUID zaten post edilmiş, tekrar post etme
                    LogHelper.d(TAG, "⚠️ Location UUID already posted, skipping event: " + uuid);
                    return;
                }
                
                // UUID'yi set'e ekle
                postedLocationUUIDs.add(uuid);
                
                // Set çok büyüdüyse eski kayıtları temizle
                if (postedLocationUUIDs.size() > MAX_POSTED_UUIDS) {
                    // En eski UUID'yi kaldır
                    String oldestUUID = postedLocationUUIDs.iterator().next();
                    postedLocationUUIDs.remove(oldestUUID);
                }
            }
            
            // Emit event (direct EventBus)
            EventBus.getDefault().post(new LocationEvent(locationModel.toJSON()));
            
            // CRITICAL: Stop detection (orijinal Transistorsoft implementasyonu)
            if (!config.disableStopDetection) {
                performStopDetection(location);
            }
            
            // Update notification if debug mode – throttle: en fazla 10 saniyede bir
            if (config.debug && config.foregroundService) {
                long now = System.currentTimeMillis();
                if (now - lastDebugNotificationUpdateTime >= DEBUG_NOTIFICATION_THROTTLE_MS) {
                    lastDebugNotificationUpdateTime = now;
                    try {
                        NotificationManager notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
                        if (notificationManager != null) {
                            ForegroundNotification.createNotificationChannel(this, false);
                            Notification notification = ForegroundNotification.build(this);
                            notificationManager.notify(NOTIFICATION_ID, notification);
                        }
                    } catch (Exception e) {
                        LogHelper.e(TAG, "Failed to update notification: " + e.getMessage(), e);
                    }
                }
            }
            
            // Check auto sync
            // CRITICAL: Only sync if tracking is enabled
            if (config.enabled && config.autoSync && !config.url.isEmpty()) {
                int unlockedCount = database.count(true); // only unlocked
                
                if (config.autoSyncThreshold <= 0 || unlockedCount >= config.autoSyncThreshold) {
                    LogHelper.d(TAG, "🔄 AutoSync triggered: " + unlockedCount + " >= " + config.autoSyncThreshold);
                    SyncService.sync(this);
                }
            }
        }
        
        // Clean old records
        cleanOldRecords();
    }
    
    /**
     * Create location model from Location
     */
    private LocationModel createLocationModel(Location location) {
        LocationModel model = new LocationModel();
        
        model.latitude = location.getLatitude();
        model.longitude = location.getLongitude();
        model.accuracy = location.getAccuracy();
        model.speed = location.getSpeed();
        model.heading = location.getBearing();
        model.altitude = location.getAltitude();
        model.timestamp = location.getTime();
        model.isMoving = config.isMoving;
        model.odometer = config.odometer;
        
        // CRITICAL: Get activity info from ActivityRecognitionService
        try {
            com.google.android.gms.location.ActivityTransitionEvent lastActivity = 
                ActivityRecognitionService.getLastActivity();
            if (lastActivity != null) {
                int activityType = lastActivity.getActivityType();
                model.activityType = getActivityName(activityType);
                model.activityConfidence = 100; // ActivityTransitionEvent doesn't have confidence, use 100
                
                // CRITICAL: Fallback check - if speed is high but activity is STILL, use speed-based detection
                // This handles cases where activity recognition hasn't updated yet or isn't working
                float speed = location.getSpeed(); // m/s
                if (activityType == com.google.android.gms.location.DetectedActivity.STILL && speed > 0.5f) {
                    // Activity is STILL but speed > 0.5 m/s - use speed-based detection
                    model.activityType = getActivityFromSpeed(speed);
                    model.activityConfidence = 75; // Lower confidence since we're using fallback
                    LogHelper.d(TAG, "📍 Activity: " + model.activityType + " (speed-based fallback: " + speed + " m/s)");
                } else {
                LogHelper.d(TAG, "📍 Activity: " + model.activityType);
                }
            } else {
                // Fallback: Use speed to determine activity (detailed detection)
                float speed = location.getSpeed(); // m/s
                model.activityType = getActivityFromSpeed(speed);
                    model.activityConfidence = 50;
                LogHelper.d(TAG, "📍 Activity: " + model.activityType + " (speed-based: " + speed + " m/s)");
            }
        } catch (Exception e) {
            LogHelper.w(TAG, "Failed to get activity: " + e.getMessage());
            // Fallback: Use speed (detailed detection)
            float speed = location.getSpeed();
            model.activityType = getActivityFromSpeed(speed);
            model.activityConfidence = 50;
            LogHelper.d(TAG, "📍 Activity: " + model.activityType + " (fallback: " + speed + " m/s)");
        }
        
        // Battery info
        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        Intent batteryStatus = registerReceiver(null, filter);
        if (batteryStatus != null) {
            int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            int status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            
            model.batteryLevel = level / (float) scale;
            model.batteryIsCharging = status == BatteryManager.BATTERY_STATUS_CHARGING 
                    || status == BatteryManager.BATTERY_STATUS_FULL;
        }
        
        return model;
    }
    
    /**
     * Convert activity type to string
     */
    private String getActivityName(int activityType) {
        switch (activityType) {
            case com.google.android.gms.location.DetectedActivity.STILL:
                return "still";
            case com.google.android.gms.location.DetectedActivity.IN_VEHICLE:
                return "in_vehicle";
            case com.google.android.gms.location.DetectedActivity.ON_BICYCLE:
                return "on_bicycle";
            case com.google.android.gms.location.DetectedActivity.ON_FOOT:
                return "on_foot";
            case com.google.android.gms.location.DetectedActivity.WALKING:
                return "walking";
            case com.google.android.gms.location.DetectedActivity.RUNNING:
                return "running";
            default:
                return "unknown";
        }
    }
    
    /**
     * Get activity type from speed (fallback when activity recognition is not available)
     * Speed thresholds based on typical human/vehicle speeds:
     * - > 15 m/s (54 km/h) → in_vehicle (car/motorcycle)
     * - 5-15 m/s (18-54 km/h) → on_bicycle (bicycle)
     * - 2-5 m/s (7.2-18 km/h) → running (running)
     * - 0.5-2 m/s (1.8-7.2 km/h) → walking (walking)
     * - < 0.5 m/s → still (stationary)
     */
    private String getActivityFromSpeed(float speed) {
        if (speed > 15.0f) {
            // Speed > 15 m/s (54 km/h) - likely in vehicle
            return "in_vehicle";
        } else if (speed > 5.0f) {
            // Speed 5-15 m/s (18-54 km/h) - likely on bicycle
            return "on_bicycle";
        } else if (speed > 2.0f) {
            // Speed 2-5 m/s (7.2-18 km/h) - likely running
            return "running";
        } else if (speed > 0.5f) {
            // Speed 0.5-2 m/s (1.8-7.2 km/h) - likely walking
            return "walking";
        } else {
            // Speed < 0.5 m/s - stationary
            return "still";
        }
    }
    
    /**
     * Clean old records from database
     */
    /**
     * Clean old records from database
     * Pattern: prune + shrink
     */
    private void cleanOldRecords() {
        try {
            // Prune: Remove records older than maxDaysToPersist
            if (config.maxDaysToPersist > 0) {
                database.prune(config.maxDaysToPersist);
            }
            
            // Shrink: Limit total records
            if (config.maxRecordsToPersist > 0) {
                int count = database.count();
                if (count > config.maxRecordsToPersist) {
                    database.shrink(config.maxRecordsToPersist);
                }
            }
        } catch (Exception e) {
            LogHelper.e(TAG, "cleanOldRecords error: " + e.getMessage(), e);
        }
    }
    
    /**
     * Create notification for foreground service
     * Debug modda ek bilgiler gösterilir
     */
    private Notification createNotification() {
        // Orijinal Transistorsoft field isimleri (title, text)
        String title = config.title;
        String text = config.text;
        
        // Debug modda ek bilgiler ekle
        if (config.debug) {
            int locationCount = database.count();
            int unlockedCount = database.count(true);
            String activity = "unknown";
            
            // Activity bilgisini al
            try {
                com.google.android.gms.location.ActivityTransitionEvent lastActivity = 
                    ActivityRecognitionService.getLastActivity();
                if (lastActivity != null) {
                    int activityType = lastActivity.getActivityType();
                    activity = getActivityNameForNotification(activityType);
                }
            } catch (Exception e) {
                // Ignore
            }
            
            // Debug bilgilerini text'e ekle
            text = String.format("%s\n📍 Locations: %d | 🔓 Unlocked: %d | 🚶 Activity: %s | 📏 Odometer: %.2f km",
                config.notificationText,
                locationCount,
                unlockedCount,
                activity,
                config.odometer
            );
        }
        
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setPriority(getPriorityFromConfig())
                .setOngoing(true);
        
        // Set color
        try {
            if (!config.notificationColor.isEmpty()) {
                builder.setColor(Color.parseColor(config.notificationColor));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        return builder.build();
    }
    
    /**
     * Get activity name from type (helper for notification - emoji version)
     */
    private String getActivityNameForNotification(int activityType) {
        switch (activityType) {
            case com.google.android.gms.location.DetectedActivity.IN_VEHICLE:
                return "🚗 Vehicle";
            case com.google.android.gms.location.DetectedActivity.ON_BICYCLE:
                return "🚴 Bicycle";
            case com.google.android.gms.location.DetectedActivity.RUNNING:
                return "🏃 Running";
            case com.google.android.gms.location.DetectedActivity.WALKING:
                return "🚶 Walking";
            case com.google.android.gms.location.DetectedActivity.ON_FOOT:
                return "👣 On Foot";
            case com.google.android.gms.location.DetectedActivity.STILL:
                return "🛑 Still";
            default:
                return "❓ Unknown";
        }
    }
    
    /**
     * Create notification channel for Android O+
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Background Location Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Arka planda konum takibi için kullanılır");
            
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }
    
    /**
     * Get notification priority from config
     */
    private int getPriorityFromConfig() {
        switch (config.notificationPriority) {
            case -2: return NotificationCompat.PRIORITY_MIN;
            case -1: return NotificationCompat.PRIORITY_LOW;
            case 0: return NotificationCompat.PRIORITY_DEFAULT;
            case 1: return NotificationCompat.PRIORITY_HIGH;
            case 2: return NotificationCompat.PRIORITY_MAX;
            default: return NotificationCompat.PRIORITY_DEFAULT;
        }
    }
    
    /**
     * Start the location service
     */
    public static void start(Context context) {
        Intent intent = new Intent(context, LocationService.class);
        intent.setAction("start"); // CRITICAL: Set action so onStartCommand knows it's a start command
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }
    
    /**
     * Stop the location service
     */
    public static void stop(Context context) {
        Intent intent = new Intent(context, LocationService.class);
        context.stopService(intent);
    }
    
    // ============================================================
    // Stop Detection (Orijinal Transistorsoft implementasyonu)
    // ============================================================
    
    /**
     * Perform stop detection (orijinal Transistorsoft implementasyonu)
     * TrackingService.performStopDetection() metodundan alındı
     */
    private void performStopDetection(Location location) {
        if (location == null) {
            return;
        }
        
        // Eğer stoppedAtLocation yoksa ve isStopped false ise, beginStopTimeout çağır
        if (!isStopped && stoppedAtLocation == null) {
            beginStopTimeout(location);
            return;
        }
        
        // Eğer activity recognition varsa ve activity STILL değilse, beginStopTimeout çağır
        if (ActivityRecognitionService.getLastActivity() != null) {
            int activityType = ActivityRecognitionService.getLastActivity().getActivityType();
            if (activityType != com.google.android.gms.location.DetectedActivity.STILL) {
                if (!isStopped) {
                    beginStopTimeout(location);
                    return;
                }
            } else if (!isStopped && beginStopDetection(location)) {
                return;
            }
        } else if (!isStopped) {
            beginStopTimeout(location);
            return;
        }
        
        // Eğer stoppedAtLocation null ise, uyarı ver
        if (stoppedAtLocation == null) {
            LogHelper.w(TAG, "⚠️ performStopDetection found stoppedAtLocation == null");
            return;
        }
        
        // Orijinal formül: (location.distanceTo(stoppedAtLocation) - stoppedAtLocation.getAccuracy()) - location.getAccuracy()
        float distanceTo = (location.distanceTo(stoppedAtLocation) - stoppedAtLocation.getAccuracy()) - location.getAccuracy();
        
        // Stationary radius kontrolü (minimum 25m)
        float stationaryRadius = config.stationaryRadius;
        if (stationaryRadius <= 25.0f) {
            stationaryRadius = 25.0f;
        }
        
        LogHelper.d(TAG, "📍 Distance from stoppedAtLocation: " + distanceTo + "m (stationaryRadius: " + stationaryRadius + "m)");
        
        // Eğer mesafe stationaryRadius'tan büyükse, hareket var demektir
        if (distanceTo > stationaryRadius) {
            LogHelper.d(TAG, "🔄 Force cancel stopTimeout due to apparent movement beyond stoppedAt location");
            if (isStopped) {
                cancelStopTimeout();
            }
            beginStopTimeout(location);
        }
    }
    
    /**
     * Begin stop timeout (orijinal Transistorsoft implementasyonu)
     * TrackingService.beginMotionActivityCheckTimer() metodundan alındı
     */
    private void beginStopTimeout(Location location) {
        if (location == null) {
            LogHelper.w(TAG, "⚠️ beginStopTimeout was provided null location");
            return;
        }
        
        if (config.disableStopDetection) {
            return;
        }
        
        // Eğer distanceFilter > 0 ise veya stoppedAtLocation null ise, stoppedAtLocation'ı set et
        if (stoppedAtLocation == null || config.distanceFilter > 0.0f) {
            stoppedAtLocation = new Location(location);
        }
        
        // Stop timeout hesaplama (dakika -> milisaniye)
        long stopTimeoutMillis = config.stopTimeout * 60000L;
        
        // Minimum 60 saniye, maksimum 5 dakika (300000ms)
        if (stopTimeoutMillis < 60000) {
            stopTimeoutMillis = 60000;
        } else if (stopTimeoutMillis > 300000) {
            stopTimeoutMillis = 300000;
        }
        
        // TSScheduleManager ile one-shot schedule
        TSScheduleManager scheduleManager = TSScheduleManager.getInstance(this);
        scheduleManager.cancelOneShot(StopTimeoutEvent.ACTION);
        scheduleManager.oneShot(StopTimeoutEvent.ACTION, stopTimeoutMillis, true, false);
        
        LogHelper.d(TAG, "⏱️ Stop timeout scheduled: " + stopTimeoutMillis + "ms (" + (stopTimeoutMillis / 60000) + " minutes)");
    }
    
    /**
     * Begin stop detection (orijinal Transistorsoft implementasyonu)
     * TrackingService.beginStopDetection() metodundan alındı
     */
    private boolean beginStopDetection(Location location) {
        if (isStopped) {
            return true;
        }
        
        if (config.disableStopDetection) {
            return false;
        }
        
        // Mock location kontrolü
        if (location != null && location.isFromMockProvider()) {
            LogHelper.d(TAG, "🐞 Mock location detected with motion-activity STILL: stopTimeout timer would normally be initiated here 🐞.");
            return false;
        }
        
        isStopped = true;
        
        // Stop timeout hesaplama
        long stopTimeoutMillis = config.stopTimeout * 60000L;
        if (stopTimeoutMillis <= 0) {
            LogHelper.d(TAG, "⏱️ Stop-timeout elapsed! Stopping tracking...");
            changePace(false);
            return true;
        }
        
        // TSScheduleManager ile one-shot schedule
        TSScheduleManager scheduleManager = TSScheduleManager.getInstance(this);
        scheduleManager.oneShot(StopTimeoutEvent.ACTION, stopTimeoutMillis, true, true);
        scheduleManager.cancelOneShot(MotionActivityCheckEvent.ACTION);
        
        // Location availability kontrolü
        if (lastLocationResult != null && lastLocationResult.getLastLocation() != null) {
            stoppedAtLocation = new Location(lastLocationResult.getLastLocation());
        } else {
            stoppedAtLocation = new Location(location);
        }
        
        LogHelper.d(TAG, "⏱️ Stop detection started: timeout=" + stopTimeoutMillis + "ms (" + (stopTimeoutMillis / 60000) + " minutes)");
        return true;
    }
    
    /**
     * Cancel stop timeout
     */
    private void cancelStopTimeout() {
        isStopped = false;
        stoppedAtLocation = null;
        TSScheduleManager scheduleManager = TSScheduleManager.getInstance(this);
        scheduleManager.cancelOneShot(StopTimeoutEvent.ACTION);
        LogHelper.d(TAG, "🔄 Stop timeout cancelled");
    }
    
    /**
     * Change pace (moving/stationary) - orijinal Transistorsoft implementasyonu
     */
    private void changePace(boolean isMoving) {
        config.isMoving = isMoving;
        config.save();
        
        // Emit enabled change event if stopped
        if (!isMoving && config.stopOnStationary) {
            LogHelper.d(TAG, "🛑 Stopping tracking due to stationary (stopOnStationary=true)");
            stop(this);
            EventBus.getDefault().post(new EnabledChangeEvent(false));
        }
        
        LogHelper.d(TAG, "🏃 Pace changed: " + (isMoving ? "MOVING" : "STATIONARY"));
    }
}

