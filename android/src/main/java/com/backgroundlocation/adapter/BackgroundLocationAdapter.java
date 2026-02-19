package com.backgroundlocation.adapter;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import com.backgroundlocation.adapter.callback.ActivityChangeCallback;
import com.backgroundlocation.adapter.callback.Callback;
import com.backgroundlocation.adapter.callback.ConnectivityChangeCallback;
import com.backgroundlocation.adapter.callback.EnabledChangeCallback;
import com.backgroundlocation.adapter.callback.GeofenceCallback;
import com.backgroundlocation.adapter.callback.HeartbeatCallback;
import com.backgroundlocation.adapter.callback.HttpResponseCallback;
import com.backgroundlocation.adapter.callback.LocationCallback;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.data.GeofenceModel;
import com.backgroundlocation.data.sqlite.SQLiteLocationDAO;
import com.backgroundlocation.data.sqlite.SQLiteGeofenceDAO;
import com.backgroundlocation.event.ActivityChangeEvent;
import com.backgroundlocation.event.ConnectivityChangeEvent;
import com.backgroundlocation.event.EnabledChangeEvent;
import com.backgroundlocation.event.GeofenceEvent;
import com.backgroundlocation.event.HeartbeatEvent;
import com.backgroundlocation.event.HttpResponseEvent;
import com.backgroundlocation.event.LocationEvent;
import com.backgroundlocation.event.MotionChangeEvent;
import com.backgroundlocation.lifecycle.LifecycleManager;
import com.backgroundlocation.service.LocationService;
import com.backgroundlocation.service.SyncService;
import com.backgroundlocation.service.ActivityRecognitionService;
import com.backgroundlocation.service.HeartbeatService;
import com.backgroundlocation.service.ConnectivityMonitor;
import com.backgroundlocation.geofence.GeofenceManager;
import com.backgroundlocation.event.HeadlessEvent;
import com.backgroundlocation.util.HeadlessEventBroadcaster;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Background Location Adapter
 * Tüm servisleri yöneten merkezi adapter sınıfı
 */
public class BackgroundLocationAdapter {
    
    private static final String TAG = "BackgroundLocationAdapter";
    private static BackgroundLocationAdapter instance;
    private static final ExecutorService threadPool = Executors.newCachedThreadPool();
    private static Handler uiHandler;
    
    // Context
    private final Context context;
    
    // Config & Database
    private final Config config;
    private final SQLiteLocationDAO locationDatabase;
    private final SQLiteGeofenceDAO geofenceDatabase;
    
    // Services
    private final FusedLocationProviderClient fusedLocationClient;
    private final GeofenceManager geofenceManager;
    
    // State
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final AtomicBoolean isStarted = new AtomicBoolean(false);
    
    // Callback Lists
    private final List<LocationCallback> locationCallbacks = new ArrayList<>();
    private final List<LocationCallback> motionChangeCallbacks = new ArrayList<>();
    private final List<GeofenceCallback> geofenceCallbacks = new ArrayList<>();
    private final List<HeartbeatCallback> heartbeatCallbacks = new ArrayList<>();
    private final List<HttpResponseCallback> httpResponseCallbacks = new ArrayList<>();
    private final List<EnabledChangeCallback> enabledChangeCallbacks = new ArrayList<>();
    private final List<ActivityChangeCallback> activityChangeCallbacks = new ArrayList<>();
    private final List<ConnectivityChangeCallback> connectivityChangeCallbacks = new ArrayList<>();
    
    /**
     * Private constructor (Singleton)
     */
    private BackgroundLocationAdapter(Context context) {
        this.context = context.getApplicationContext();
        this.config = Config.getInstance(this.context);
        this.locationDatabase = SQLiteLocationDAO.getInstance(this.context);
        this.geofenceDatabase = SQLiteGeofenceDAO.getInstance(this.context);
        this.fusedLocationClient = LocationServices.getFusedLocationProviderClient(this.context);
        this.geofenceManager = GeofenceManager.getInstance(this.context);
        
        // Register EventBus
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        
        // Initialize LifecycleManager
        if (isOnMainThread()) {
            LifecycleManager.getInstance().run();
        } else {
            getUiHandler().post(LifecycleManager.getInstance());
        }
        
        LogHelper.d(TAG, "✅ BackgroundLocationAdapter initialized");
    }
    
    /**
     * Get singleton instance
     */
    public static BackgroundLocationAdapter getInstance(Context context) {
        if (instance == null || instance.isDead()) {
            synchronized (BackgroundLocationAdapter.class) {
                if (instance == null || instance.isDead()) {
                    instance = new BackgroundLocationAdapter(context);
                }
            }
        }
        return instance;
    }
    
    /**
     * Get thread pool
     */
    public static ExecutorService getThreadPool() {
        return threadPool;
    }
    
    /**
     * Get UI handler
     */
    public static Handler getUiHandler() {
        if (uiHandler == null) {
            uiHandler = new Handler(Looper.getMainLooper());
        }
        return uiHandler;
    }
    
    /**
     * Check if on main thread
     */
    public static boolean isOnMainThread() {
        return Thread.currentThread().equals(Looper.getMainLooper().getThread());
    }
    
    /**
     * Check if adapter is dead
     */
    public boolean isDead() {
        return context == null;
    }
    
    // ============================================
    // EventBus Subscribers ( _ prefix)
    // ============================================
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onLocationEvent(LocationEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode - event'i broadcast et
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "location", event));
        }
        
        // Callback'leri çağır
        synchronized (locationCallbacks) {
            for (LocationCallback callback : locationCallbacks) {
                try {
                    LocationModel locationModel = LocationModel.fromJSON(event.toJson());
                    if (locationModel != null) {
                        callback.onLocation(locationModel);
                    }
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in location callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onMotionChange(MotionChangeEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "motionchange", event));
        }
        
        // Callback'leri çağır
        synchronized (motionChangeCallbacks) {
            for (LocationCallback callback : motionChangeCallbacks) {
                try {
                    LocationModel locationModel = LocationModel.fromJSON(event.toJson());
                    if (locationModel != null) {
                        callback.onLocation(locationModel);
                    }
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in motion change callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onGeofence(GeofenceEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "geofence", event));
        }
        
        // Callback'leri çağır
        synchronized (geofenceCallbacks) {
            for (GeofenceCallback callback : geofenceCallbacks) {
                try {
                    callback.onGeofence(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in geofence callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onHeartbeat(HeartbeatEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "heartbeat", event));
        }
        
        // Callback'leri çağır
        synchronized (heartbeatCallbacks) {
            for (HeartbeatCallback callback : heartbeatCallbacks) {
                try {
                    callback.onHeartbeat(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in heartbeat callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onHttpResponse(HttpResponseEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "http", event));
        }
        
        // Callback'leri çağır
        synchronized (httpResponseCallbacks) {
            for (HttpResponseCallback callback : httpResponseCallbacks) {
                try {
                    callback.onHttpResponse(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in http response callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onEnabledChange(EnabledChangeEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "enabledchange", event));
        }
        
        // Callback'leri çağır
        synchronized (enabledChangeCallbacks) {
            for (EnabledChangeCallback callback : enabledChangeCallbacks) {
                try {
                    callback.onEnabledChange(event.isEnabled());
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in enabled change callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onActivityChange(ActivityChangeEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "activitychange", event));
        }
        
        // Callback'leri çağır
        synchronized (activityChangeCallbacks) {
            for (ActivityChangeCallback callback : activityChangeCallbacks) {
                try {
                    callback.onActivityChange(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in activity change callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onConnectivityChange(ConnectivityChangeEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode
            HeadlessEventBroadcaster.post(new HeadlessEvent(context, "connectivitychange", event));
        }
        
        // Callback'leri çağır
        synchronized (connectivityChangeCallbacks) {
            for (ConnectivityChangeCallback callback : connectivityChangeCallbacks) {
                try {
                    callback.onConnectivityChange(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in connectivity change callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    /**
     * Handle TerminateEvent
     * Uygulama kapandığında stopOnTerminate kontrolü yap
     */
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void _onTerminate(com.backgroundlocation.event.TerminateEvent event) {
        LogHelper.d(TAG, "📱 TerminateEvent received: " + event.getReason());
        
        // Check if app is still active (not headless)
        if (!LifecycleManager.getInstance().isHeadless()) {
            LogHelper.d(TAG, "TERMINATE_EVENT ignored (MainActivity is still active)");
            return;
        }
        
        // Check stopOnTerminate config
        if (config.stopOnTerminate) {
            LogHelper.w(TAG, "⚠️ stopOnTerminate: true - Stopping tracking");
            stop(new Callback() {
                @Override
                public void onSuccess() {
                    LogHelper.d(TAG, "✅ Tracking stopped on terminate");
                }
                
                @Override
                public void onFailure(String error) {
                    LogHelper.e(TAG, "❌ Failed to stop on terminate: " + error);
                }
            });
            return;
        }
        
        // stopOnTerminate: false - Continue tracking in background
        LogHelper.d(TAG, "✅ stopOnTerminate: false - Continuing tracking in background");
        
        // Check background location permission
        if (config.enabled && !com.backgroundlocation.util.LocationAuthorization.hasBackgroundPermission(context)) {
            LogHelper.w(TAG, "⚠️ Background location permission not granted - tracking may be limited");
        }
        
        // Fire headless terminate event if enabled
        if (config.enableHeadless) {
            HeadlessEventBroadcaster.post(new com.backgroundlocation.event.HeadlessEvent(
                context,
                "terminate",
                config.toJSON()
            ));
        }
    }
    
    // ============================================
    // Callback Management
    // ============================================
    
    /**
     * Add location callback
     */
    public void onLocation(LocationCallback callback) {
        synchronized (locationCallbacks) {
            locationCallbacks.add(callback);
        }
    }
    
    /**
     * Add motion change callback
     */
    public void onMotionChange(LocationCallback callback) {
        synchronized (motionChangeCallbacks) {
            motionChangeCallbacks.add(callback);
        }
    }
    
    /**
     * Add geofence callback
     */
    public void onGeofence(GeofenceCallback callback) {
        synchronized (geofenceCallbacks) {
            geofenceCallbacks.add(callback);
        }
    }
    
    /**
     * Add heartbeat callback
     */
    public void onHeartbeat(HeartbeatCallback callback) {
        synchronized (heartbeatCallbacks) {
            heartbeatCallbacks.add(callback);
        }
    }
    
    /**
     * Add HTTP response callback
     */
    public void onHttpResponse(HttpResponseCallback callback) {
        synchronized (httpResponseCallbacks) {
            httpResponseCallbacks.add(callback);
        }
    }
    
    /**
     * Add enabled change callback
     */
    public void onEnabledChange(EnabledChangeCallback callback) {
        synchronized (enabledChangeCallbacks) {
            enabledChangeCallbacks.add(callback);
        }
    }
    
    /**
     * Add activity change callback
     */
    public void onActivityChange(ActivityChangeCallback callback) {
        synchronized (activityChangeCallbacks) {
            activityChangeCallbacks.add(callback);
        }
    }
    
    /**
     * Add connectivity change callback
     */
    public void onConnectivityChange(ConnectivityChangeCallback callback) {
        synchronized (connectivityChangeCallbacks) {
            connectivityChangeCallbacks.add(callback);
        }
    }
    
    /**
     * Remove location callback
     */
    public boolean removeLocationCallback(LocationCallback callback) {
        synchronized (locationCallbacks) {
            return locationCallbacks.remove(callback);
        }
    }
    
    /**
     * Remove all callbacks
     */
    public void removeAllCallbacks() {
        synchronized (locationCallbacks) {
            locationCallbacks.clear();
        }
        synchronized (motionChangeCallbacks) {
            motionChangeCallbacks.clear();
        }
        synchronized (geofenceCallbacks) {
            geofenceCallbacks.clear();
        }
        synchronized (heartbeatCallbacks) {
            heartbeatCallbacks.clear();
        }
        synchronized (httpResponseCallbacks) {
            httpResponseCallbacks.clear();
        }
        synchronized (enabledChangeCallbacks) {
            enabledChangeCallbacks.clear();
        }
        synchronized (activityChangeCallbacks) {
            activityChangeCallbacks.clear();
        }
        synchronized (connectivityChangeCallbacks) {
            connectivityChangeCallbacks.clear();
        }
        LogHelper.d(TAG, "✅ All callbacks cleared");
    }
    
    // ============================================
    // Core Methods
    // ============================================
    
    /**
     * Ready - Initialize and configure
     *  ready()
     */
    public void ready(Callback callback) {
        if (isInitialized.get()) {
            if (config.enabled) {
                // Get current position if enabled
                getCurrentPosition(null, new LocationCallback() {
                    @Override
                    public void onError(Integer errorCode) {
                        // Ignore
                    }
                    
                    @Override
                    public void onLocation(LocationModel location) {
                        // Ignore
                    }
                });
            }
            if (callback != null) {
                callback.onSuccess();
            }
            return;
        }
        
        isInitialized.set(true);
        
        // Initialize services
        initializeServices();
        
        // Check if should start
        if (config.enabled) {
            // Always start location tracking (geofence mode is handled separately)
            start(callback);
        } else {
            if (callback != null) {
                callback.onSuccess();
            }
        }
    }
    
    /**
     * Start location tracking
     *  start()
     */
    public void start(Callback callback) {
        if (isStarted.get()) {
            if (callback != null) {
                callback.onSuccess();
            }
            return;
        }
        
        try {
            config.enabled = true;
            config.save();
            
            LocationService.start(context);
            isStarted.set(true);
            
            if (callback != null) {
                callback.onSuccess();
            }
            
            LogHelper.d(TAG, "✅ Location tracking started");
        } catch (Exception e) {
            LogHelper.e(TAG, "Failed to start: " + e.getMessage(), e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Start on boot
     *  startOnBoot()
     */
    public void startOnBoot() {
        threadPool.execute(() -> {
            try {
                if (config.enabled && config.startOnBoot) {
                    LogHelper.d(TAG, "🔄 Starting on boot...");
                    start(null);
                } else {
                    LogHelper.d(TAG, "⏸️ Not starting on boot (enabled: " + config.enabled + ", startOnBoot: " + config.startOnBoot + ")");
                }
            } catch (Exception e) {
                LogHelper.e(TAG, "Failed to start on boot: " + e.getMessage(), e);
            }
        });
    }
    
    /**
     * Fire notification action listeners
     *  fireNotificationActionListeners()
     */
    public void fireNotificationActionListeners(String actionId) {
        // TODO: Implement notification action callback system
        LogHelper.d(TAG, "Notification action: " + actionId);
    }
    
    /**
     * Stop location tracking
     *  stop()
     */
    public void stop(Callback callback) {
        try {
            config.enabled = false;
            config.save();
            
            LocationService.stop(context);
            isStarted.set(false);
            
            if (callback != null) {
                callback.onSuccess();
            }
            
            LogHelper.d(TAG, "✅ Location tracking stopped");
        } catch (Exception e) {
            LogHelper.e(TAG, "Failed to stop: " + e.getMessage(), e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Start geofences only
     *  startGeofences()
     */
    public void startGeofences(Callback callback) {
        try {
            config.enabled = true;
            config.save();
            
            // TODO: Start geofence monitoring
            
            if (callback != null) {
                callback.onSuccess();
            }
            
            LogHelper.d(TAG, "✅ Geofence tracking started");
        } catch (Exception e) {
            LogHelper.e(TAG, "Failed to start geofences: " + e.getMessage(), e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Change pace (moving/stationary)
     *  changePace()
     */
    public void changePace(boolean isMoving, Callback callback) {
        if (!config.enabled) {
            if (callback != null) {
                callback.onFailure("BackgroundLocation is disabled");
            }
            return;
        }
        
        try {
            config.isMoving = isMoving;
            config.save();
            
            // Emit motion change event
            org.json.JSONObject locationJson = new org.json.JSONObject();
            locationJson.put("timestamp", System.currentTimeMillis());
            locationJson.put("is_moving", isMoving);
            
            EventBus.getDefault().post(new MotionChangeEvent(isMoving, locationJson));
            
            if (callback != null) {
                callback.onSuccess();
            }
            
            LogHelper.d(TAG, "✅ Pace changed: " + (isMoving ? "MOVING" : "STATIONARY"));
        } catch (Exception e) {
            LogHelper.e(TAG, "Failed to change pace: " + e.getMessage(), e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Get current position
     *  getCurrentPosition()
     */
    public void getCurrentPosition(org.json.JSONObject options, LocationCallback callback) {
        threadPool.execute(() -> {
            try {
                fusedLocationClient.getLastLocation()
                    .addOnSuccessListener(location -> {
                        if (location != null) {
                            LocationModel model = createLocationModel(location);
                            
                            // Optionally persist
                            if (options != null && options.optBoolean("persist", false)) {
                                locationDatabase.persist(model.toJSON());
                            }
                            
                            if (callback != null) {
                                getUiHandler().post(() -> callback.onLocation(model));
                            }
                        } else {
                            if (callback != null) {
                                getUiHandler().post(() -> callback.onError(1)); // LOCATION_UNAVAILABLE
                            }
                        }
                    })
                    .addOnFailureListener(e -> {
                        LogHelper.e(TAG, "Failed to get current position: " + e.getMessage(), e);
                        if (callback != null) {
                            getUiHandler().post(() -> callback.onError(1));
                        }
                    });
            } catch (Exception e) {
                LogHelper.e(TAG, "Error getting current position: " + e.getMessage(), e);
                if (callback != null) {
                    getUiHandler().post(() -> callback.onError(1));
                }
            }
        });
    }
    
    /**
     * Sync locations
     *  sync()
     */
    public void sync() {
        threadPool.execute(() -> {
            SyncService.sync(context);
        });
    }
    
    /**
     * Get count of locations
     */
    public int getCount() {
        return locationDatabase.count();
    }
    
    /**
     * Get locations
     */
    public List<LocationModel> getLocations() {
        return locationDatabase.all();
    }
    
    // ============================================
    // Geofence Methods
    // ============================================
    
    /**
     * Add geofence
     *  addGeofence()
     */
    public void addGeofence(GeofenceModel geofence, Callback callback) {
        threadPool.execute(() -> {
            geofenceManager.addGeofence(geofence, new Callback() {
                @Override
                public void onSuccess() {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onSuccess());
                    }
                }
                
                @Override
                public void onFailure(String error) {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onFailure(error));
                    }
                }
            });
        });
    }
    
    /**
     * Add multiple geofences
     *  addGeofences()
     */
    public void addGeofences(List<GeofenceModel> geofences, Callback callback) {
        threadPool.execute(() -> {
            geofenceManager.addGeofences(geofences, new Callback() {
                @Override
                public void onSuccess() {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onSuccess());
                    }
                }
                
                @Override
                public void onFailure(String error) {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onFailure(error));
                    }
                }
            });
        });
    }
    
    /**
     * Remove geofence
     *  removeGeofence()
     */
    public void removeGeofence(String identifier, Callback callback) {
        threadPool.execute(() -> {
            geofenceManager.removeGeofence(identifier, new Callback() {
                @Override
                public void onSuccess() {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onSuccess());
                    }
                }
                
                @Override
                public void onFailure(String error) {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onFailure(error));
                    }
                }
            });
        });
    }
    
    /**
     * Remove all geofences
     *  removeGeofences()
     */
    public void removeAllGeofences(Callback callback) {
        threadPool.execute(() -> {
            geofenceManager.removeAllGeofences(new Callback() {
                @Override
                public void onSuccess() {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onSuccess());
                    }
                }
                
                @Override
                public void onFailure(String error) {
                    if (callback != null) {
                        getUiHandler().post(() -> callback.onFailure(error));
                    }
                }
            });
        });
    }
    
    /**
     * Get all geofences
     *  getGeofences()
     */
    public List<GeofenceModel> getGeofences() {
        return geofenceManager.getGeofences();
    }
    
    /**
     * Get geofence by identifier
     *  getGeofence()
     */
    public GeofenceModel getGeofence(String identifier) {
        return geofenceManager.getGeofence(identifier);
    }
    
    /**
     * Check if geofence exists
     *  geofenceExists()
     */
    public boolean geofenceExists(String identifier) {
        return geofenceManager.geofenceExists(identifier);
    }
    
    // ============================================
    // Private Helper Methods
    // ============================================
    
    /**
     * Initialize services
     */
    private void initializeServices() {
        // Initialize LifecycleManager
        LifecycleManager.getInstance().initialize();
        
        // Services are initialized on-demand when start() is called
        LogHelper.d(TAG, "✅ Services initialized");
    }
    
    /**
     * Create location model from Location
     */
    private LocationModel createLocationModel(android.location.Location location) {
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
        return model;
    }
}

