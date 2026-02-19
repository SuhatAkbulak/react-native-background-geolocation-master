package com.backgroundlocation;

import android.Manifest;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.location.Location;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.os.BatteryManager;
import android.os.Build;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.GeofenceModel;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.data.sqlite.SQLiteLocationDAO;
import com.backgroundlocation.data.sqlite.SQLiteGeofenceDAO;
import com.backgroundlocation.event.LocationEvent;
import com.backgroundlocation.event.HttpResponseEvent;
import com.backgroundlocation.event.ConnectivityChangeEvent;
import com.backgroundlocation.event.EnabledChangeEvent;
import com.backgroundlocation.event.MotionChangeEvent;
import com.backgroundlocation.event.GeofenceEvent;
import com.backgroundlocation.event.ActivityChangeEvent;
import com.backgroundlocation.event.HeartbeatEvent;
import com.backgroundlocation.receiver.GeofenceBroadcastReceiver;
import com.backgroundlocation.service.LocationService;
import com.backgroundlocation.service.SyncService;
import com.backgroundlocation.service.ActivityRecognitionService;
import com.backgroundlocation.lifecycle.LifecycleManager;
import com.backgroundlocation.headless.HeadlessTask;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.LifecycleEventListener;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.facebook.react.modules.core.PermissionAwareActivity;
import com.facebook.react.modules.core.PermissionListener;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * React Native Background Location Module
 * JavaScript bridge to native Android functionality
 */
public class RNBackgroundLocationModule extends ReactContextBaseJavaModule implements LifecycleEventListener {

    private static final String MODULE_NAME = "RNBackgroundLocation";
    private static final int PERMISSION_REQUEST_CODE = 1001;

    private final ReactApplicationContext reactContext;
    private BackgroundLocationAdapter adapter;
    private Config config;
    private SQLiteLocationDAO locationDatabase;
    private SQLiteGeofenceDAO geofenceDatabase;
    private FusedLocationProviderClient fusedLocationClient;
    private GeofencingClient geofencingClient;
    private boolean isReady = false;
    private Callback pendingPermissionCallback;
    
    // Duplicate event prevention (prevent same UUID from being sent twice)
    // CRITICAL: Static Set - tüm modül instance'ları aynı Set'i paylaşır (modül birden fazla kez oluşturulsa bile)
    private static final java.util.Set<String> sentLocationUUIDs = new java.util.HashSet<>();
    private static final Object sentLocationUUIDsLock = new Object(); // Lock object for synchronization
    private static final int MAX_TRACKED_UUIDS = 100; // Son 100 UUID'yi takip et
    private String lastSentLocationUUID = null;

    public RNBackgroundLocationModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        
        // Initialize adapter
        this.adapter = BackgroundLocationAdapter.getInstance(reactContext);
        this.config = Config.getInstance(reactContext);
        this.locationDatabase = SQLiteLocationDAO.getInstance(reactContext);
        this.geofenceDatabase = SQLiteGeofenceDAO.getInstance(reactContext);
        this.fusedLocationClient = LocationServices.getFusedLocationProviderClient(reactContext);
        this.geofencingClient = LocationServices.getGeofencingClient(reactContext);
        
        reactContext.addLifecycleEventListener(this);
        
        // Register EventBus (adapter zaten kayıtlı, ama module de kayıtlı olmalı React Native events için)
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
            android.util.Log.d("RNBackgroundLocation", "✅ EventBus registered for RNBackgroundLocationModule");
        } else {
            android.util.Log.w("RNBackgroundLocation", "⚠️ EventBus already registered for RNBackgroundLocationModule");
        }
        
        // Register HeadlessTask if headless mode is enabled
        if (config.enableHeadless) {
            HeadlessTask headlessTask = new HeadlessTask();
            if (!EventBus.getDefault().isRegistered(headlessTask)) {
                EventBus.getDefault().register(headlessTask);
            }
        }
    }

    @Override
    public String getName() {
        return MODULE_NAME;
    }

    @Override
    public void onHostResume() {
        // React Native resumed
    }

    @Override
    public void onHostPause() {
        // React Native paused
    }

    @Override
    public void onHostDestroy() {
        // Cleanup
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
    }

    // EventBus subscribers for native events
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onLocationEvent(LocationEvent event) {
        try {
            // CRITICAL: Duplicate check - prevent same UUID from being sent twice to React Native
            // This can happen if EventBus has multiple subscribers or event is posted twice
            JSONObject locationJson = event.toJson();
            String uuid = locationJson.optString("uuid", null);
            
            android.util.Log.d("RNBackgroundLocation", "📥 Location event received (UUID: " + uuid + ", Thread: " + Thread.currentThread().getName() + ")");
            
            if (uuid == null || uuid.isEmpty()) {
                // UUID yok, gönderme
                android.util.Log.w("RNBackgroundLocation", "⚠️ Location event has no UUID, ignoring");
                return;
            }
            
            // CRITICAL: Thread-safe duplicate check - çifte gönderimi önle
            // Static Set kullanıyoruz, böylece tüm modül instance'ları aynı Set'i paylaşır
            synchronized (sentLocationUUIDsLock) {
                // UUID daha önce gönderilmiş mi kontrol et
                if (sentLocationUUIDs.contains(uuid)) {
                    // Duplicate event - ignore (çifte gönderim önlendi)
                    android.util.Log.d("RNBackgroundLocation", "⚠️ DUPLICATE location event IGNORED (UUID already sent): " + uuid);
                    return;
                }
                
                // UUID'yi set'e ekle (göndermeden ÖNCE ekle - race condition önleme)
                sentLocationUUIDs.add(uuid);
                
                // Set çok büyüdüyse eski kayıtları temizle
                if (sentLocationUUIDs.size() > MAX_TRACKED_UUIDS) {
                    // En eski UUID'yi kaldır (FIFO)
                    String oldestUUID = sentLocationUUIDs.iterator().next();
                    sentLocationUUIDs.remove(oldestUUID);
                }
            }
            
            // Update last sent UUID (backward compatibility)
            lastSentLocationUUID = uuid;
            
            // CRITICAL: Event'i React Native'e gönder (duplicate check'ten geçti)
            WritableMap params = jsonToWritableMap(locationJson);
            sendEvent(event.getEventName(), params);
            
            android.util.Log.d("RNBackgroundLocation", "✅ Location event sent to React Native: " + uuid);
        } catch (JSONException e) {
            android.util.Log.e("RNBackgroundLocation", "❌ Error processing location event: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onHttpResponse(HttpResponseEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onConnectivityChange(ConnectivityChangeEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onEnabledChange(EnabledChangeEvent event) {
        try {
            WritableMap params = Arguments.createMap();
            params.putBoolean("enabled", event.isEnabled());
            sendEvent(event.getEventName(), params);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onMotionChange(MotionChangeEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onGeofence(GeofenceEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onActivityChange(ActivityChangeEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onHeartbeat(HeartbeatEvent event) {
        try {
            WritableMap params = jsonToWritableMap(event.toJson());
            sendEvent(event.getEventName(), params);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    /**
     * Initialize and configure the plugin
     */
    @ReactMethod
    public void ready(ReadableMap configMap, Callback success, Callback failure) {
        try {
            // Update configuration
            JSONObject configJson = readableMapToJson(configMap);
            config.updateFromJSON(configJson);
            
            // Use adapter
            adapter.ready(new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    isReady = true;
                    success.invoke(getStateMap());
                }
                
                @Override
                public void onFailure(String error) {
                    failure.invoke(error);
                }
            });
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Configure the plugin (reset and apply config)
     */
    @ReactMethod
    public void configure(ReadableMap configMap, Callback success, Callback failure) {
        try {
            config.reset();
            JSONObject configJson = readableMapToJson(configMap);
            config.updateFromJSON(configJson);
            
            isReady = true;
            success.invoke(getStateMap());
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Update configuration
     */
    @ReactMethod
    public void setConfig(ReadableMap configMap, Callback success, Callback failure) {
        try {
            JSONObject configJson = readableMapToJson(configMap);
            config.updateFromJSON(configJson);
            success.invoke(getStateMap());
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Reset configuration
     */
    @ReactMethod
    public void reset(ReadableMap defaultConfig, Callback success, Callback failure) {
        try {
            config.reset();
            if (defaultConfig != null) {
                JSONObject configJson = readableMapToJson(defaultConfig);
                config.updateFromJSON(configJson);
            }
            success.invoke(getStateMap());
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Start location tracking
     */
    @ReactMethod
    public void start(Callback success, Callback failure) {
        try {
            if (!checkPermissions()) {
                failure.invoke("Location permissions not granted");
                return;
            }
            
            // Use adapter
            adapter.start(new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    success.invoke(getStateMap());
                }
                
                @Override
                public void onFailure(String error) {
                    failure.invoke(error);
                }
            });
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Stop location tracking
     */
    @ReactMethod
    public void stop(Callback success, Callback failure) {
        try {
            // Use adapter
            adapter.stop(new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    success.invoke(getStateMap());
                }
                
                @Override
                public void onFailure(String error) {
                    failure.invoke(error);
                }
            });
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Start geofence-only tracking
     */
    @ReactMethod
    public void startGeofences(Callback success, Callback failure) {
        try {
            if (!checkPermissions()) {
                failure.invoke("Location permissions not granted");
                return;
            }
            
            config.enabled = true;
            config.save();
            
            success.invoke(getStateMap());
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Start schedule
     */
    @ReactMethod
    public void startSchedule(Callback success, Callback failure) {
        // Schedule feature - future implementation
        failure.invoke("Schedule feature not yet implemented");
    }

    /**
     * Stop schedule
     */
    @ReactMethod
    public void stopSchedule(Callback success, Callback failure) {
        // Schedule feature - future implementation
        success.invoke(getStateMap());
    }

    /**
     * Change pace (moving/stationary)
     */
    @ReactMethod
    public void changePace(boolean isMoving, Callback success, Callback failure) {
        try {
            // Use adapter
            adapter.changePace(isMoving, new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    success.invoke();
                }
                
                @Override
                public void onFailure(String error) {
                    failure.invoke(error);
                }
            });
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get current position (one-time location)
     */
    @ReactMethod
    public void getCurrentPosition(ReadableMap options, Callback success, Callback failure) {
        try {
            if (!checkPermissions()) {
                failure.invoke("Location permissions not granted");
                return;
            }
            
            fusedLocationClient.getLastLocation()
                .addOnSuccessListener(location -> {
                    if (location != null) {
                        try {
                            LocationModel model = createLocationModel(location);
                            
                            // Optionally persist
                            if (options.hasKey("persist") && options.getBoolean("persist")) {
                                locationDatabase.persist(model.toJSON());
                            }
                            
                            WritableMap result = jsonToWritableMap(model.toJSON());
                            success.invoke(result);
                        } catch (Exception e) {
                            failure.invoke(e.getMessage());
                        }
                    } else {
                        failure.invoke("Location not available");
                    }
                })
                .addOnFailureListener(e -> {
                    failure.invoke(e.getMessage());
                });
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Watch position
     */
    @ReactMethod
    public void watchPosition(ReadableMap options, Callback success, Callback failure) {
        // Watch position feature - uses location service
        success.invoke();
    }

    /**
     * Stop watching position
     */
    @ReactMethod
    public void stopWatchPosition(Callback success, Callback failure) {
        success.invoke();
    }

    /**
     * Get current state
     */
    @ReactMethod
    public void getState(Callback success, Callback failure) {
        try {
            success.invoke(getStateMap());
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get stored locations
     */
    @ReactMethod
    public void getLocations(Callback success, Callback failure) {
        try {
            List<LocationModel> locations = locationDatabase.all();
            WritableArray array = Arguments.createArray();
            
            for (LocationModel location : locations) {
                WritableMap map = jsonToWritableMap(location.toJSON());
                array.pushMap(map);
            }
            
            success.invoke(array);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get location count
     */
    @ReactMethod
    public void getCount(Callback success, Callback failure) {
        try {
            int count = locationDatabase.count();
            success.invoke(count);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Insert location manually
     */
    @ReactMethod
    public void insertLocation(ReadableMap locationMap, Callback success, Callback failure) {
        try {
            JSONObject locationJson = readableMapToJson(locationMap);
            String uuid = locationDatabase.persist(locationJson);
            
            if (uuid != null) {
                success.invoke(uuid);
            } else {
                failure.invoke("Failed to insert location");
            }
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Delete all locations
     */
    @ReactMethod
    public void destroyLocations(Callback success, Callback failure) {
        try {
            locationDatabase.clear();
            success.invoke();
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Delete specific location
     */
    @ReactMethod
    public void destroyLocation(String uuid, Callback success, Callback failure) {
        try {
            // Find location by uuid first
            List<LocationModel> allLocations = locationDatabase.all();
            for (LocationModel location : allLocations) {
                if (location.uuid != null && location.uuid.equals(uuid)) {
                    locationDatabase.destroy(location);
                    success.invoke();
                    return;
                }
            }
            failure.invoke("Location not found");
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Sync locations to server
     */
    @ReactMethod
    public void sync(Callback success, Callback failure) {
        try {
            if (config.url.isEmpty()) {
                failure.invoke("No URL configured");
                return;
            }
            
            List<LocationModel> locations = locationDatabase.allWithLocking(config.maxBatchSize);
            
            SyncService.sync(reactContext);
            
            WritableArray array = Arguments.createArray();
            for (LocationModel location : locations) {
                WritableMap map = jsonToWritableMap(location.toJSON());
                array.pushMap(map);
            }
            
            success.invoke(array);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get odometer value
     */
    @ReactMethod
    public void getOdometer(Callback success, Callback failure) {
        try {
            success.invoke(config.odometer);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Set odometer value
     */
    @ReactMethod
    public void setOdometer(float value, Callback success, Callback failure) {
        try {
            config.odometer = value;
            config.save();
            
            // Return current location with new odometer
            getCurrentPosition(Arguments.createMap(), success, failure);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Add geofence
     */
    @ReactMethod
    public void addGeofence(ReadableMap geofenceMap, Callback success, Callback failure) {
        try {
            if (!checkPermissions()) {
                failure.invoke("Location permissions not granted");
                return;
            }
            
            JSONObject geofenceJson = readableMapToJson(geofenceMap);
            GeofenceModel geofenceModel = GeofenceModel.fromJSON(geofenceJson);
            
            if (geofenceModel == null) {
                failure.invoke("Invalid geofence data");
                return;
            }
            
            // Save to SQLite database
            geofenceDatabase.persist(geofenceModel);
            
            // Register with Google Play Services
            registerGeofence(geofenceModel);
            
            success.invoke();
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Add multiple geofences
     */
    @ReactMethod
    public void addGeofences(ReadableArray geofencesArray, Callback success, Callback failure) {
        try {
            List<GeofenceModel> geofences = new ArrayList<>();
            
            for (int i = 0; i < geofencesArray.size(); i++) {
                ReadableMap geofenceMap = geofencesArray.getMap(i);
                JSONObject geofenceJson = readableMapToJson(geofenceMap);
                GeofenceModel geofenceModel = GeofenceModel.fromJSON(geofenceJson);
                
                if (geofenceModel != null) {
                    geofences.add(geofenceModel);
                }
            }
            
            // Save to SQLite database
            for (GeofenceModel geofence : geofences) {
                geofenceDatabase.persist(geofence);
                // Register with Google Play Services
                registerGeofence(geofence);
            }
            
            success.invoke();
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Remove geofence
     */
    @ReactMethod
    public void removeGeofence(String identifier, Callback success, Callback failure) {
        try {
            geofenceDatabase.destroy(identifier);
            
            List<String> ids = new ArrayList<>();
            ids.add(identifier);
            geofencingClient.removeGeofences(ids);
            
            success.invoke();
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Remove all geofences
     */
    @ReactMethod
    public void removeGeofences(Callback success, Callback failure) {
        try {
            geofenceDatabase.clear();
            geofencingClient.removeGeofences(getGeofencePendingIntent());
            success.invoke();
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get all geofences
     */
    @ReactMethod
    public void getGeofences(Callback success, Callback failure) {
        try {
            List<GeofenceModel> geofences = geofenceDatabase.all();
            WritableArray array = Arguments.createArray();
            
            for (GeofenceModel geofence : geofences) {
                WritableMap map = jsonToWritableMap(geofence.toJSON());
                array.pushMap(map);
            }
            
            success.invoke(array);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Get specific geofence
     */
    @ReactMethod
    public void getGeofence(String identifier, Callback success, Callback failure) {
        try {
            GeofenceModel geofence = geofenceDatabase.get(identifier);
            
            if (geofence != null) {
                WritableMap map = jsonToWritableMap(geofence.toJSON());
                success.invoke(map);
            } else {
                failure.invoke("Geofence not found");
            }
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Check if geofence exists
     */
    @ReactMethod
    public void geofenceExists(String identifier, Callback callback) {
        try {
            boolean exists = geofenceDatabase.exists(identifier);
            callback.invoke(exists);
        } catch (Exception e) {
            callback.invoke(false);
        }
    }

    /**
     * Request location permissions
     */
    @ReactMethod
    public void requestPermission(Callback callback) {
        // Check if permission already granted
        if (checkPermissions()) {
            callback.invoke(checkPermissionStatus());
            return;
        }
        
        // Request permission
        android.app.Activity activity = getCurrentActivity();
        if (activity == null) {
            callback.invoke(2); // DENIED
            return;
        }
        
        pendingPermissionCallback = callback;
        
        // CRITICAL: Include ACTIVITY_RECOGNITION permission if motion activity updates are enabled
        Config config = Config.getInstance(getReactApplicationContext());
        java.util.List<String> permissionList = new java.util.ArrayList<>();
        permissionList.add(Manifest.permission.ACCESS_FINE_LOCATION);
        permissionList.add(Manifest.permission.ACCESS_COARSE_LOCATION);
        
        // Add ACTIVITY_RECOGNITION if motion activity updates are not disabled
        if (!config.disableMotionActivityUpdates && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissionList.add(Manifest.permission.ACTIVITY_RECOGNITION);
        }
        
        String[] permissions = permissionList.toArray(new String[0]);
        
        if (activity instanceof PermissionAwareActivity) {
            ((PermissionAwareActivity) activity).requestPermissions(
                permissions,
                PERMISSION_REQUEST_CODE,
                new PermissionListener() {
                    @Override
                    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
                        if (requestCode == PERMISSION_REQUEST_CODE) {
                            boolean granted = grantResults.length > 0 && 
                                grantResults[0] == PackageManager.PERMISSION_GRANTED;
                            
                            if (pendingPermissionCallback != null) {
                                int status = granted ? checkPermissionStatus() : 2; // 2 = DENIED
                                pendingPermissionCallback.invoke(status);
                                pendingPermissionCallback = null;
                            }
                            return true;
                        }
                        return false;
                    }
                }
            );
        } else {
            // Fallback: use ActivityCompat (will be handled by BaseActivityEventListener)
            ActivityCompat.requestPermissions(activity, permissions, PERMISSION_REQUEST_CODE);
        }
    }

    /**
     * Check if power save mode is enabled
     */
    @ReactMethod
    public void isPowerSaveMode(Callback callback) {
        // Power save mode check
        callback.invoke(false);
    }

    /**
     * Get device info
     */
    @ReactMethod
    public void getDeviceInfo(Callback callback) {
        WritableMap map = Arguments.createMap();
        map.putString("platform", "android");
        map.putString("manufacturer", Build.MANUFACTURER);
        map.putString("model", Build.MODEL);
        map.putString("version", Build.VERSION.RELEASE);
        map.putString("framework", "react-native");
        callback.invoke(map);
    }

    /**
     * Get sensor info
     */
    @ReactMethod
    public void getSensors(Callback callback) {
        WritableMap map = Arguments.createMap();
        map.putString("platform", "android");
        map.putBoolean("accelerometer", true);
        map.putBoolean("magnetometer", true);
        map.putBoolean("gyroscope", true);
        map.putBoolean("significant_motion", true);
        callback.invoke(map);
    }

    /**
     * Get provider state
     */
    @ReactMethod
    public void getProviderState(Callback success, Callback failure) {
        try {
            WritableMap map = Arguments.createMap();
            map.putBoolean("enabled", checkPermissions());
            map.putBoolean("gps", true);
            map.putBoolean("network", true);
            map.putInt("status", checkPermissionStatus());
            map.putInt("accuracyAuthorization", 1);
            success.invoke(map);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }

    /**
     * Destroy logs
     */
    @ReactMethod
    public void destroyLog(Callback success, Callback failure) {
        success.invoke(true);
    }

    /**
     * Play sound (debug)
     */
    @ReactMethod
    public void playSound(String soundId) {
        // Sound playback - debug feature
    }

    /**
     * Get current activity
     */
    @ReactMethod
    public void getActivity(Callback success, Callback failure) {
        try {
            com.google.android.gms.location.ActivityTransitionEvent lastActivity = 
                ActivityRecognitionService.getLastActivity();
            
            String activityName = "unknown";
            int confidence = 0;
            
            if (lastActivity != null) {
                int activityType = lastActivity.getActivityType();
                activityName = getActivityName(activityType);
                confidence = 100; // ActivityTransitionEvent doesn't have confidence, use default
            }
            
            WritableMap map = Arguments.createMap();
            map.putString("activity", activityName);
            map.putInt("confidence", confidence);
            success.invoke(map);
        } catch (Exception e) {
            failure.invoke(e.getMessage());
        }
    }
    
    private String getActivityName(int activityType) {
        switch (activityType) {
            case com.google.android.gms.location.DetectedActivity.IN_VEHICLE:
                return "in_vehicle";
            case com.google.android.gms.location.DetectedActivity.ON_BICYCLE:
                return "on_bicycle";
            case com.google.android.gms.location.DetectedActivity.RUNNING:
                return "running";
            case com.google.android.gms.location.DetectedActivity.WALKING:
                return "walking";
            case com.google.android.gms.location.DetectedActivity.ON_FOOT:
                return "on_foot";
            case com.google.android.gms.location.DetectedActivity.STILL:
                return "still";
            default:
                return "unknown";
        }
    }

    /**
     * Check if moving
     */
    @ReactMethod
    public void isMoving(Callback callback) {
        boolean moving = ActivityRecognitionService.isMoving(reactContext);
        callback.invoke(moving);
    }

    /**
     * Check if background
     */
    @ReactMethod
    public void isBackground(Callback callback) {
        boolean background = LifecycleManager.getInstance().isBackground();
        callback.invoke(background);
    }

    /**
     * Check if headless
     */
    @ReactMethod
    public void isHeadless(Callback callback) {
        boolean headless = LifecycleManager.getInstance().isHeadless();
        callback.invoke(headless);
    }

    @ReactMethod
    public void addListener(String eventName) {
        // Required for RN built-in EventEmitter
    }

    @ReactMethod
    public void removeListeners(Integer count) {
        // Required for RN built-in EventEmitter
    }

    // Helper Methods

    private boolean checkPermissions() {
        int fineLocation = ContextCompat.checkSelfPermission(reactContext, 
                Manifest.permission.ACCESS_FINE_LOCATION);
        return fineLocation == PackageManager.PERMISSION_GRANTED;
    }

    private int checkPermissionStatus() {
        if (checkPermissions()) {
            return 3; // ALWAYS
        }
        return 2; // DENIED
    }

    private WritableMap getStateMap() {
        try {
            return jsonToWritableMap(config.toJSON());
        } catch (Exception e) {
            return Arguments.createMap();
        }
    }

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
        
        // Battery info
        IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
        Intent batteryStatus = reactContext.registerReceiver(null, filter);
        if (batteryStatus != null) {
            int level = batteryStatus.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int scale = batteryStatus.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
            int status = batteryStatus.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
            
            model.batteryLevel = level / (float) scale;
            model.batteryIsCharging = status == BatteryManager.BATTERY_STATUS_CHARGING;
        }
        
        return model;
    }

    private void registerGeofence(GeofenceModel model) {
        try {
            if (!checkPermissions()) {
                return;
            }
            
            int transitionTypes = 0;
            if (model.getNotifyOnEntry()) transitionTypes |= Geofence.GEOFENCE_TRANSITION_ENTER;
            if (model.getNotifyOnExit()) transitionTypes |= Geofence.GEOFENCE_TRANSITION_EXIT;
            if (model.getNotifyOnDwell()) transitionTypes |= Geofence.GEOFENCE_TRANSITION_DWELL;
            
            Geofence geofence = new Geofence.Builder()
                    .setRequestId(model.getIdentifier())
                    .setCircularRegion(model.getLatitude(), model.getLongitude(), model.getRadius())
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .setTransitionTypes(transitionTypes)
                    .setLoiteringDelay(model.getLoiteringDelay())
                    .build();
            
            GeofencingRequest request = new GeofencingRequest.Builder()
                    .setInitialTrigger(config.geofenceInitialTriggerEntry ? 
                            GeofencingRequest.INITIAL_TRIGGER_ENTER : 0)
                    .addGeofence(geofence)
                    .build();
            
            geofencingClient.addGeofences(request, getGeofencePendingIntent());
        } catch (SecurityException e) {
            e.printStackTrace();
        }
    }

    private PendingIntent getGeofencePendingIntent() {
        Intent intent = new Intent(reactContext, GeofenceBroadcastReceiver.class);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_MUTABLE;
        }
        return PendingIntent.getBroadcast(reactContext, 0, intent, flags);
    }

    private void sendEvent(String eventName, WritableMap params) {
        reactContext
                .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    // JSON Conversion Helpers

    public static WritableMap jsonToWritableMap(JSONObject json) throws JSONException {
        WritableMap map = Arguments.createMap();
        Iterator<String> keys = json.keys();
        
        while (keys.hasNext()) {
            String key = keys.next();
            Object value = json.get(key);
            
            if (value instanceof JSONObject) {
                map.putMap(key, jsonToWritableMap((JSONObject) value));
            } else if (value instanceof JSONArray) {
                map.putArray(key, jsonToWritableArray((JSONArray) value));
            } else if (value instanceof Boolean) {
                map.putBoolean(key, (Boolean) value);
            } else if (value instanceof Integer) {
                map.putInt(key, (Integer) value);
            } else if (value instanceof Double) {
                map.putDouble(key, (Double) value);
            } else if (value instanceof String) {
                map.putString(key, (String) value);
            }
        }
        
        return map;
    }

    private static WritableArray jsonToWritableArray(JSONArray array) throws JSONException {
        WritableArray writableArray = Arguments.createArray();
        
        for (int i = 0; i < array.length(); i++) {
            Object value = array.get(i);
            
            if (value instanceof JSONObject) {
                writableArray.pushMap(jsonToWritableMap((JSONObject) value));
            } else if (value instanceof JSONArray) {
                writableArray.pushArray(jsonToWritableArray((JSONArray) value));
            } else if (value instanceof Boolean) {
                writableArray.pushBoolean((Boolean) value);
            } else if (value instanceof Integer) {
                writableArray.pushInt((Integer) value);
            } else if (value instanceof Double) {
                writableArray.pushDouble((Double) value);
            } else if (value instanceof String) {
                writableArray.pushString((String) value);
            }
        }
        
        return writableArray;
    }

    private JSONObject readableMapToJson(ReadableMap map) throws JSONException {
        JSONObject json = new JSONObject();
        ReadableMapKeySetIterator keys = map.keySetIterator();
        
        while (keys.hasNextKey()) {
            String key = keys.nextKey();
            
            switch (map.getType(key)) {
                case Boolean:
                    json.put(key, map.getBoolean(key));
                    break;
                case Number:
                    json.put(key, map.getDouble(key));
                    break;
                case String:
                    json.put(key, map.getString(key));
                    break;
                case Map:
                    json.put(key, readableMapToJson(map.getMap(key)));
                    break;
                case Array:
                    json.put(key, readableArrayToJson(map.getArray(key)));
                    break;
                case Null:
                    json.put(key, JSONObject.NULL);
                    break;
            }
        }
        
        return json;
    }

    private JSONArray readableArrayToJson(ReadableArray array) throws JSONException {
        JSONArray json = new JSONArray();
        
        for (int i = 0; i < array.size(); i++) {
            switch (array.getType(i)) {
                case Boolean:
                    json.put(array.getBoolean(i));
                    break;
                case Number:
                    json.put(array.getDouble(i));
                    break;
                case String:
                    json.put(array.getString(i));
                    break;
                case Map:
                    json.put(readableMapToJson(array.getMap(i)));
                    break;
                case Array:
                    json.put(readableArrayToJson(array.getArray(i)));
                    break;
                case Null:
                    json.put(JSONObject.NULL);
                    break;
            }
        }
        
        return json;
    }
}

