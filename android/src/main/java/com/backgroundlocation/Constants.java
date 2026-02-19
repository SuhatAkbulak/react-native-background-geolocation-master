package com.backgroundlocation;

/**
 * Constants
 * Constants.java
 * Sabitler ve genel ayarlar
 */
public class Constants {

    public static class State {
        public static final String ON = "ON";
        public static final String OFF = "OFF";
        public static final String LOCATION_SERVICES_DISABLED = "Location-services disabled";
        public static final String LOCATION_TIMEOUT = "Location timeout";
    }

    // Notification channel IDs
    public static final String NOTIFICATION_CHANNEL_ID = "BackgroundLocationChannel";
    public static final String NOTIFICATION_CHANNEL_NAME = "Background Location Service";
    
    // Service actions
    public static final String ACTION_START = "start";
    public static final String ACTION_STOP = "stop";
    public static final String ACTION_NOTIFICATION_ACTION = "notificationaction";
    public static final String ACTION_STOP_TRACKING = "STOP_TRACKING";
    
    // Notification IDs
    public static final int NOTIFICATION_ID = 12345678;
    
    // Foreground service geofence ID
    public static final String FOREGROUND_SERVICE_GEOFENCE = "TSLocationManager::FOREGROUND_SERVICE_GEOFENCE";
    
    // Background task constants
    public static final String ACTION_BACKGROUND_TASK = "BackgroundTask";
    public static final String FIELD_TASK_ID = "taskId";
    public static final long BACKGROUND_TASK_MAX_DURATION = 180000; // 3 minutes
    
    // Schedule constants
    public static final String ACTION_SCHEDULE = "schedule";
    
    // Boot receiver actions
    public static final String ACTION_BOOT_COMPLETED = "android.intent.action.BOOT_COMPLETED";
    public static final String ACTION_LOCKED_BOOT_COMPLETED = "android.intent.action.LOCKED_BOOT_COMPLETED";
    public static final String ACTION_MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED";
}

