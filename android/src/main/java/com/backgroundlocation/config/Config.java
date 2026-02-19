package com.backgroundlocation.config;

import android.content.Context;
import android.content.SharedPreferences;
import com.google.gson.Gson;
import com.google.gson.annotations.SerializedName;
import org.json.JSONObject;

/**
 * Configuration Management Class
 * Tüm ayarları yönetir ve SharedPreferences'a kaydeder
 */
public class Config {
    private static final String PREFS_NAME = "BackgroundLocationConfig";
    private static final String KEY_CONFIG = "config";
    
    private static Config instance;
    // Gson tarafından serileştirilmemesi gereken alanlar
    // (Context ve Gson nesnesi çok büyük ve döngüsel referanslara sahip)
    private transient Context context;
    private transient Gson gson;

    // Location Settings
    @SerializedName("desiredAccuracy")
    public int desiredAccuracy = 100; // Default: 100 (MEDIUM accuracy)
    
    @SerializedName("distanceFilter")
    public int distanceFilter = 10; // Default: 10 meters
    
    @SerializedName("stationaryRadius")
    public int stationaryRadius = 25; // Default: 25 meters
    
    @SerializedName("locationUpdateInterval")
    public long locationUpdateInterval = 1000; // Default: 1000ms (1 second)
    
    @SerializedName("fastestLocationUpdateInterval")
    public long fastestLocationUpdateInterval = -1; // Default: -1 (not set, Android default: 30s)
    
    // Activity Recognition
    @SerializedName("activityRecognitionInterval")
    public long activityRecognitionInterval = 10000; // Default: 10000ms (10 seconds)
    
    @SerializedName("stopTimeout")
    public int stopTimeout = 5; // Default: 5 minutes
    
    @SerializedName("stopOnStationary")
    public boolean stopOnStationary = false;
    
    @SerializedName("disableStopDetection")
    public boolean disableStopDetection = false; // Default: false (stop detection enabled)
    
    @SerializedName("disableMotionActivityUpdates")
    public boolean disableMotionActivityUpdates = false;
    
    // Foreground Service
    @SerializedName("foregroundService")
    public boolean foregroundService = true;
    
    // Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority, channelName, channelId)
    // Backward compatibility için eski field isimlerini de destekle (notificationTitle, notificationText, vb.)
    @SerializedName(value = "title", alternate = {"notificationTitle"})
    public String title = "Location Tracking";
    
    @SerializedName(value = "text", alternate = {"notificationText"})
    public String text = "Your location is being tracked";
    
    @SerializedName(value = "smallIcon", alternate = {"notificationIcon"})
    public String smallIcon = "";
    
    @SerializedName(value = "largeIcon", alternate = {"notificationLargeIcon"})
    public String largeIcon = "";
    
    @SerializedName(value = "color", alternate = {"notificationColor"})
    public String color = "#3498db";
    
    @SerializedName(value = "priority", alternate = {"notificationPriority"})
    public int priority = 0; // PRIORITY_DEFAULT
    
    @SerializedName(value = "channelId", alternate = {"notificationChannelId"})
    public String channelId = "";
    
    @SerializedName(value = "channelName", alternate = {"notificationChannelName"})
    public String channelName = "";
    
    // Backward compatibility: Eski field isimlerini de destekle (deprecated)
    @Deprecated
    public String getNotificationTitle() { return title; }
    @Deprecated
    public void setNotificationTitle(String value) { this.title = value; }
    
    @Deprecated
    public String getNotificationText() { return text; }
    @Deprecated
    public void setNotificationText(String value) { this.text = value; }
    
    @Deprecated
    public String getNotificationIcon() { return smallIcon; }
    @Deprecated
    public void setNotificationIcon(String value) { this.smallIcon = value; }
    
    @Deprecated
    public String getNotificationColor() { return color; }
    @Deprecated
    public void setNotificationColor(String value) { this.color = value; }
    
    @Deprecated
    public int getNotificationPriority() { return priority; }
    @Deprecated
    public void setNotificationPriority(int value) { this.priority = value; }
    
    @Deprecated
    public String getNotificationChannelId() { return channelId; }
    @Deprecated
    public void setNotificationChannelId(String value) { this.channelId = value; }
    
    @Deprecated
    public String getNotificationChannelName() { return channelName; }
    @Deprecated
    public void setNotificationChannelName(String value) { this.channelName = value; }
    
    @SerializedName("didDeviceReboot")
    public boolean didDeviceReboot = false;
    
    // HTTP Sync
    @SerializedName("url")
    public String url = "";
    
    @SerializedName("method")
    public String method = "POST";
    
    @SerializedName("autoSync")
    public boolean autoSync = true;
    
    @SerializedName("autoSyncThreshold")
    public int autoSyncThreshold = 0;
    
    @SerializedName("maxBatchSize")
    public int maxBatchSize = 250;
    
    @SerializedName("maxDaysToPersist")
    public int maxDaysToPersist = 1;
    
    @SerializedName("maxRecordsToPersist")
    public int maxRecordsToPersist = 10000;
    
    // Geofence
    @SerializedName("geofenceProximityRadius")
    public int geofenceProximityRadius = 1000; // meters
    
    @SerializedName("geofenceInitialTriggerEntry")
    public boolean geofenceInitialTriggerEntry = true;
    
    // Power Management
    @SerializedName("deferTime")
    public long deferTime = 0;
    
    @SerializedName("allowIdenticalLocations")
    public boolean allowIdenticalLocations = false;
    
    // Debug
    @SerializedName("debug")
    public boolean debug = false;
    
    @SerializedName("logLevel")
    public int logLevel = 3; // INFO
    
    @SerializedName("logMaxDays")
    public int logMaxDays = 3;
    
    // Platform Specific
    @SerializedName("enableHeadless")
    public boolean enableHeadless = false;
    
    @SerializedName("headlessJobService")
    public String headlessJobService = "com.backgroundlocation.HeadlessTask";
    
    @SerializedName("startOnBoot")
    public boolean startOnBoot = false;
    
    @SerializedName("stopOnTerminate")
    public boolean stopOnTerminate = false;
    
    @SerializedName("stopAfterElapsedMinutes")
    public int stopAfterElapsedMinutes = 0; // 0 = disabled
    
    // Elasticity
    @SerializedName("disableElasticity")
    public boolean disableElasticity = false;
    
    @SerializedName("elasticityMultiplier")
    public float elasticityMultiplier = 1.0f;
    
    // Advanced
    @SerializedName("batchSync")
    public boolean batchSync = true;
    
    @SerializedName("heartbeatInterval")
    public int heartbeatInterval = 60; // seconds
    
    @SerializedName("preventSuspend")
    public boolean preventSuspend = true;
    
    @SerializedName("enableTimestampMeta")
    public boolean enableTimestampMeta = true;
    
    @SerializedName("scheduleUseAlarmManager")
    public boolean scheduleUseAlarmManager = true;
    
    @SerializedName("schedulerEnabled")
    public boolean schedulerEnabled = false;
    
    @SerializedName("schedule")
    public String schedule = ""; // Comma-separated schedule strings
    
    // HTTP Details (stored as JSON strings)
    @SerializedName("headers")
    public String headers = "{}"; // JSON string
    
    @SerializedName("params")
    public String params = "{}"; // JSON string
    
    @SerializedName("extras")
    public String extras = "{}"; // JSON string
    
    // State
    @SerializedName("enabled")
    public boolean enabled = false;
    
    @SerializedName("isMoving")
    public boolean isMoving = false;
    
    @SerializedName("odometer")
    public float odometer = 0f;

    private Config(Context context) {
        this.context = context.getApplicationContext();
        this.gson = new Gson();
        load();
    }

    public static synchronized Config getInstance(Context context) {
        if (instance == null) {
            instance = new Config(context);
        }
        return instance;
    }
    
    /**
     * Check if config is loaded
     */
    public static boolean isLoaded() {
        return instance != null;
    }

    /**
     * Load configuration from SharedPreferences
     */
    private void load() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String json = prefs.getString(KEY_CONFIG, null);
        if (json != null) {
            try {
                Config loaded = gson.fromJson(json, Config.class);
                copyFrom(loaded);
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    /**
     * Save configuration to SharedPreferences
     */
    public void save() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String json = gson.toJson(this);
        prefs.edit().putString(KEY_CONFIG, json).apply();
    }

    /**
     * Reset to default values
     */
    public void reset() {
        desiredAccuracy = 10;
        distanceFilter = 10;
        stationaryRadius = 25;
        locationUpdateInterval = 10000;
        fastestLocationUpdateInterval = 5000;
        activityRecognitionInterval = 10000;
        stopTimeout = 5;
        stopOnStationary = false;
        disableStopDetection = false;
        disableStopDetection = false;
        disableMotionActivityUpdates = false;
        foregroundService = true;
        notificationTitle = "Location Tracking";
        notificationText = "Your location is being tracked";
        notificationColor = "#3498db";
        notificationPriority = 0;
        notificationChannelId = "";
        notificationChannelName = "";
        didDeviceReboot = false;
        url = "";
        method = "POST";
        autoSync = true;
        autoSyncThreshold = 0;
        maxBatchSize = 250;
        maxDaysToPersist = 1;
        maxRecordsToPersist = 10000;
        geofenceProximityRadius = 1000;
        geofenceInitialTriggerEntry = true;
        deferTime = 0;
        allowIdenticalLocations = false;
        debug = false;
        logLevel = 3;
        logMaxDays = 3;
        enableHeadless = false;
        startOnBoot = false;
        stopOnTerminate = false;
        stopAfterElapsedMinutes = 0;
        disableElasticity = false;
        elasticityMultiplier = 1.0f;
        batchSync = true;
        heartbeatInterval = 60;
        preventSuspend = true;
        enableTimestampMeta = true;
        scheduleUseAlarmManager = true;
        schedulerEnabled = false;
        schedule = "";
        headers = "{}";
        params = "{}";
        extras = "{}";
        enabled = false;
        isMoving = false;
        save();
    }

    /**
     * Update configuration from JSON object
     */
    public void updateFromJSON(JSONObject json) {
        try {
            if (json.has("desiredAccuracy")) desiredAccuracy = json.getInt("desiredAccuracy");
            if (json.has("distanceFilter")) distanceFilter = json.getInt("distanceFilter");
            if (json.has("stationaryRadius")) stationaryRadius = json.getInt("stationaryRadius");
            if (json.has("locationUpdateInterval")) locationUpdateInterval = json.getLong("locationUpdateInterval");
            if (json.has("fastestLocationUpdateInterval")) fastestLocationUpdateInterval = json.getLong("fastestLocationUpdateInterval");
            if (json.has("activityRecognitionInterval")) activityRecognitionInterval = json.getLong("activityRecognitionInterval");
            if (json.has("stopTimeout")) stopTimeout = json.getInt("stopTimeout");
            if (json.has("stopOnStationary")) stopOnStationary = json.getBoolean("stopOnStationary");
            if (json.has("disableStopDetection")) disableStopDetection = json.getBoolean("disableStopDetection");
            if (json.has("disableMotionActivityUpdates")) disableMotionActivityUpdates = json.getBoolean("disableMotionActivityUpdates");
            if (json.has("foregroundService")) foregroundService = json.getBoolean("foregroundService");
            if (json.has("notificationTitle")) notificationTitle = json.getString("notificationTitle");
            if (json.has("notificationText")) notificationText = json.getString("notificationText");
            if (json.has("notificationIcon")) notificationIcon = json.getString("notificationIcon");
            if (json.has("notificationColor")) notificationColor = json.getString("notificationColor");
            if (json.has("notificationPriority")) notificationPriority = json.getInt("notificationPriority");
            if (json.has("notificationChannelId")) notificationChannelId = json.getString("notificationChannelId");
            if (json.has("notificationChannelName")) notificationChannelName = json.getString("notificationChannelName");
            if (json.has("didDeviceReboot")) didDeviceReboot = json.getBoolean("didDeviceReboot");
            if (json.has("url")) url = json.getString("url");
            if (json.has("method")) method = json.getString("method");
            if (json.has("autoSync")) autoSync = json.getBoolean("autoSync");
            if (json.has("autoSyncThreshold")) autoSyncThreshold = json.getInt("autoSyncThreshold");
            if (json.has("maxBatchSize")) maxBatchSize = json.getInt("maxBatchSize");
            if (json.has("maxDaysToPersist")) maxDaysToPersist = json.getInt("maxDaysToPersist");
            if (json.has("maxRecordsToPersist")) maxRecordsToPersist = json.getInt("maxRecordsToPersist");
            if (json.has("geofenceProximityRadius")) geofenceProximityRadius = json.getInt("geofenceProximityRadius");
            if (json.has("geofenceInitialTriggerEntry")) geofenceInitialTriggerEntry = json.getBoolean("geofenceInitialTriggerEntry");
            if (json.has("deferTime")) deferTime = json.getLong("deferTime");
            if (json.has("allowIdenticalLocations")) allowIdenticalLocations = json.getBoolean("allowIdenticalLocations");
            if (json.has("debug")) debug = json.getBoolean("debug");
            if (json.has("logLevel")) logLevel = json.getInt("logLevel");
            if (json.has("logMaxDays")) logMaxDays = json.getInt("logMaxDays");
            if (json.has("enableHeadless")) enableHeadless = json.getBoolean("enableHeadless");
            if (json.has("startOnBoot")) startOnBoot = json.getBoolean("startOnBoot");
            if (json.has("stopOnTerminate")) stopOnTerminate = json.getBoolean("stopOnTerminate");
            if (json.has("stopAfterElapsedMinutes")) stopAfterElapsedMinutes = json.getInt("stopAfterElapsedMinutes");
            if (json.has("disableElasticity")) disableElasticity = json.getBoolean("disableElasticity");
            if (json.has("elasticityMultiplier")) elasticityMultiplier = (float) json.getDouble("elasticityMultiplier");
            if (json.has("batchSync")) batchSync = json.getBoolean("batchSync");
            if (json.has("heartbeatInterval")) heartbeatInterval = json.getInt("heartbeatInterval");
            if (json.has("preventSuspend")) preventSuspend = json.getBoolean("preventSuspend");
            if (json.has("enableTimestampMeta")) enableTimestampMeta = json.getBoolean("enableTimestampMeta");
            if (json.has("scheduleUseAlarmManager")) scheduleUseAlarmManager = json.getBoolean("scheduleUseAlarmManager");
            if (json.has("schedulerEnabled")) schedulerEnabled = json.getBoolean("schedulerEnabled");
            if (json.has("schedule")) schedule = json.getString("schedule");
            if (json.has("headers")) headers = json.getJSONObject("headers").toString();
            if (json.has("params")) params = json.getJSONObject("params").toString();
            if (json.has("extras")) extras = json.getJSONObject("extras").toString();
            
            save();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * Convert configuration to JSON
     */
    public JSONObject toJSON() {
        try {
            String json = gson.toJson(this);
            return new JSONObject(json);
        } catch (Exception e) {
            e.printStackTrace();
            return new JSONObject();
        }
    }

    /**
     * Copy values from another config
     */
    private void copyFrom(Config other) {
        this.desiredAccuracy = other.desiredAccuracy;
        this.distanceFilter = other.distanceFilter;
        this.stationaryRadius = other.stationaryRadius;
        this.locationUpdateInterval = other.locationUpdateInterval;
        this.fastestLocationUpdateInterval = other.fastestLocationUpdateInterval;
        this.activityRecognitionInterval = other.activityRecognitionInterval;
        this.stopTimeout = other.stopTimeout;
        this.stopOnStationary = other.stopOnStationary;
        this.disableStopDetection = other.disableStopDetection;
        this.disableMotionActivityUpdates = other.disableMotionActivityUpdates;
        this.foregroundService = other.foregroundService;
        this.notificationTitle = other.notificationTitle;
        this.notificationText = other.notificationText;
        this.notificationIcon = other.notificationIcon;
        this.notificationColor = other.notificationColor;
        this.notificationPriority = other.notificationPriority;
        this.notificationChannelId = other.notificationChannelId;
        this.notificationChannelName = other.notificationChannelName;
        this.didDeviceReboot = other.didDeviceReboot;
        this.url = other.url;
        this.method = other.method;
        this.autoSync = other.autoSync;
        this.autoSyncThreshold = other.autoSyncThreshold;
        this.maxBatchSize = other.maxBatchSize;
        this.maxDaysToPersist = other.maxDaysToPersist;
        this.maxRecordsToPersist = other.maxRecordsToPersist;
        this.geofenceProximityRadius = other.geofenceProximityRadius;
        this.geofenceInitialTriggerEntry = other.geofenceInitialTriggerEntry;
        this.deferTime = other.deferTime;
        this.allowIdenticalLocations = other.allowIdenticalLocations;
        this.debug = other.debug;
        this.logLevel = other.logLevel;
        this.logMaxDays = other.logMaxDays;
        this.enableHeadless = other.enableHeadless;
        this.startOnBoot = other.startOnBoot;
        this.stopOnTerminate = other.stopOnTerminate;
        this.stopAfterElapsedMinutes = other.stopAfterElapsedMinutes;
        this.disableElasticity = other.disableElasticity;
        this.elasticityMultiplier = other.elasticityMultiplier;
        this.batchSync = other.batchSync;
        this.heartbeatInterval = other.heartbeatInterval;
        this.preventSuspend = other.preventSuspend;
        this.enableTimestampMeta = other.enableTimestampMeta;
        this.scheduleUseAlarmManager = other.scheduleUseAlarmManager;
        this.schedulerEnabled = other.schedulerEnabled;
        this.schedule = other.schedule;
        this.headers = other.headers;
        this.params = other.params;
        this.extras = other.extras;
        this.enabled = other.enabled;
        this.isMoving = other.isMoving;
        this.odometer = other.odometer;
    }
    
    /**
     * Update authorization
     */
    public void updateAuthorization(Authorization authorization) {
        // TODO: Store authorization in config
        // For now, just save config
        save();
    }
    
    /**
     * Calculate dynamic distance filter based on speed (elasticity)
     * Orijinal Transistorsoft implementasyonundan alındı
     * 
     * @param speed Speed in m/s
     * @return Calculated distance filter in meters
     */
    public float calculateDistanceFilter(float speed) {
        if (speed <= 0.0f || disableElasticity) {
            return distanceFilter;
        }
        
        // Hızı 5'e bölüp yuvarlama: Math.floor((speed/5) + 0.5) * 5 / 5
        // Örnek: 36 m/s → 36/5 = 7.2 → floor(7.2 + 0.5) = 7 → 7 * 5 / 5 = 7
        float speedFactor = (float) ((Math.floor((speed / 5.0) + 0.5) * 5.0) / 5.0);
        if (speedFactor < 0.0f) {
            speedFactor = 0.0f;
        }
        
        // Dinamik distance filter: base + (base * multiplier * speedFactor)
        // Örnek: distanceFilter=50, elasticityMultiplier=1.0, speed=36 m/s
        // → speedFactor = 7
        // → newDistanceFilter = 50 + (50 * 1.0 * 7) = 400m
        return distanceFilter + (distanceFilter * elasticityMultiplier * speedFactor);
    }
    
    /**
     * Increment odometer by distance
     * Orijinal Transistorsoft implementasyonundan alındı
     * 
     * @param distance Distance in meters
     * @return New odometer value in kilometers
     */
    public float incrementOdometer(float distance) {
        // Distance is in meters, convert to km and add to odometer
        float distanceKm = distance / 1000f;
        odometer += distanceKm;
        save();
        return odometer;
    }
}

