package com.backgroundlocation.service;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import com.backgroundlocation.config.Config;
import com.backgroundlocation.util.LogHelper;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.event.HeartbeatEvent;
import com.backgroundlocation.receiver.HeartbeatReceiver;
import com.backgroundlocation.service.SyncService;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;

import org.greenrobot.eventbus.EventBus;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Heartbeat Service
 * Periyodik location gönderimi servisi
 *  HeartbeatService
 */
public class HeartbeatService {
    
    private static final String TAG = "HeartbeatService";
    public static final String ACTION = "HEARTBEAT";
    private static final int REQUEST_CODE = 88888;
    
    /**
     * Start heartbeat service
     *  TSScheduleManager.oneShot
     */
    public static void start(Context context) {
        Config config = Config.getInstance(context);
        int interval = config.heartbeatInterval;
        
        if (interval <= 0) {
            stop(context);
            return;
        }
        
        LogHelper.i(TAG, "✅ Start heartbeat (" + interval + "s)");
        
        // Cancel existing heartbeat
        cancelHeartbeat(context);
        
        // Schedule next heartbeat
        scheduleHeartbeat(context, interval * 1000L);
    }
    
    /**
     * Stop heartbeat service
     */
    public static void stop(Context context) {
        LogHelper.i(TAG, "🔴 Stop heartbeat");
        cancelHeartbeat(context);
    }
    
    /**
     * Schedule heartbeat using AlarmManager
     *  AlarmManager.setExact
     */
    private static void scheduleHeartbeat(Context context, long delayMillis) {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            LogHelper.e(TAG, "AlarmManager is null");
            return;
        }
        
        Intent intent = new Intent(context, HeartbeatReceiver.class);
        intent.setAction(ACTION);
        
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            flags
        );
        
        long triggerAtMillis = System.currentTimeMillis() + delayMillis;
        
        // Exact alarm kullanmıyoruz - sadece setWindow kullanıyoruz
        // Bu izin gerektirmez ve daha güvenilir çalışır
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setWindow(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                60000, // Allow 1 minute window
                pendingIntent
            );
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            );
        }
        
        LogHelper.d(TAG, "✅ Heartbeat scheduled (inexact): " + (delayMillis / 1000) + "s");
    }
    
    /**
     * Cancel heartbeat
     */
    private static void cancelHeartbeat(Context context) {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) {
            return;
        }
        
        Intent intent = new Intent(context, HeartbeatReceiver.class);
        intent.setAction(ACTION);
        
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        
        PendingIntent pendingIntent = PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            flags
        );
        
        alarmManager.cancel(pendingIntent);
        pendingIntent.cancel();
    }
    
    /**
     * On heartbeat triggered
     *  getLastLocation + emit event + auto-sync
     */
    public static void onHeartbeat(Context context) {
        Config config = Config.getInstance(context);
        int interval = config.heartbeatInterval;
        
        if (interval <= 0) {
            cancelHeartbeat(context);
            return;
        }
        
        LogHelper.d(TAG, "❤️ Heartbeat triggered");
        
        // Schedule next heartbeat
        scheduleHeartbeat(context, interval * 1000L);
        
        // Get last location
        FusedLocationProviderClient fusedLocationClient = 
            LocationServices.getFusedLocationProviderClient(context);
        
        fusedLocationClient.getLastLocation()
            .addOnSuccessListener(new OnSuccessListener<Location>() {
                @Override
                public void onSuccess(Location location) {
                    if (location == null) {
                        LogHelper.w(TAG, "Last location is null");
                        return;
                    }
                    
                    // Create location model
                    LocationModel locationModel = createLocationModel(context, location);
                    locationModel.isMoving = config.isMoving;
                    
                    // Set event type to "heartbeat"
                    try {
                        JSONObject locationJson = locationModel.toJSON();
                        locationJson.put("event", "heartbeat");
                        
                        // Create heartbeat event
                        HeartbeatEvent heartbeatEvent = new HeartbeatEvent(locationJson);
                        
                        // Emit event
                        EventBus.getDefault().post(heartbeatEvent);
                        
                        // Auto-sync if enabled
                        if (config.autoSync && !config.url.isEmpty()) {
                            SyncService.sync(context);
                        }
                    } catch (JSONException e) {
                        LogHelper.e(TAG, "Error creating heartbeat event: " + e.getMessage(), e);
                    }
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(Exception e) {
                    LogHelper.w(TAG, "Failed to get last location for heartbeat: " + e.getMessage());
                }
            });
    }
    
    /**
     * Create location model from Location
     */
    private static LocationModel createLocationModel(Context context, Location location) {
        LocationModel model = new LocationModel();
        
        model.latitude = location.getLatitude();
        model.longitude = location.getLongitude();
        model.accuracy = location.getAccuracy();
        model.speed = location.getSpeed();
        model.heading = location.getBearing();
        model.altitude = location.getAltitude();
        model.timestamp = location.getTime();
        
        // Get activity from ActivityRecognitionService if available
        try {
            com.google.android.gms.location.ActivityTransitionEvent lastActivity = 
                ActivityRecognitionService.getLastActivity();
            if (lastActivity != null) {
                int activityType = lastActivity.getActivityType();
                String activityName = getActivityName(activityType);
                // Activity info can be added to location model if needed
            }
        } catch (Exception e) {
            // Ignore
        }
        
        return model;
    }
    
    /**
     * Get activity name from type
     */
    private static String getActivityName(int activityType) {
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
}

