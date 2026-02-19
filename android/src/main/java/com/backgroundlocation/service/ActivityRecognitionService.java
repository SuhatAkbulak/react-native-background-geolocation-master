package com.backgroundlocation.service;

import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import com.backgroundlocation.config.Config;
import com.backgroundlocation.util.LogHelper;
import com.backgroundlocation.event.ActivityChangeEvent;
import com.backgroundlocation.event.MotionChangeEvent;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.location.ActivityRecognition;
import com.google.android.gms.location.ActivityRecognitionClient;
import com.google.android.gms.location.ActivityRecognitionResult;
import com.google.android.gms.location.ActivityTransition;
import com.google.android.gms.location.ActivityTransitionEvent;
import com.google.android.gms.location.ActivityTransitionRequest;
import com.google.android.gms.location.ActivityTransitionResult;
import com.google.android.gms.location.DetectedActivity;

import org.greenrobot.eventbus.EventBus;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Activity Recognition Service
 * Otomatik hareket algılama servisi
 * ActivityRecognitionService
 */
public class ActivityRecognitionService extends Service {
    
    private static final String TAG = "ActivityRecognitionService";
    private static final AtomicBoolean isStarted = new AtomicBoolean(false);
    private static final AtomicBoolean motionTriggerDelay = new AtomicBoolean(false);
    private static ActivityTransitionEvent lastActivity = new ActivityTransitionEvent(DetectedActivity.STILL, ActivityTransition.ACTIVITY_TRANSITION_ENTER, 0);
    
    private Config config;
    private ActivityRecognitionClient activityRecognitionClient;
    
    @Override
    public void onCreate() {
        super.onCreate();
        config = Config.getInstance(this);
        activityRecognitionClient = ActivityRecognition.getClient(this);
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            return START_NOT_STICKY;
        }
        
        isStarted.set(true);
        
        // Handle activity recognition result
        if (ActivityTransitionResult.hasResult(intent)) {
            handleActivityTransitionResult(ActivityTransitionResult.extractResult(intent));
        } else if (ActivityRecognitionResult.hasResult(intent)) {
            handleActivityRecognitionResult(ActivityRecognitionResult.extractResult(intent));
        }
        
        return START_NOT_STICKY;
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    /**
     * Handle Activity Transition Result
     * ActivityTransitionEvent processing
     */
    private void handleActivityTransitionResult(ActivityTransitionResult result) {
        if (result == null) {
            return;
        }
        
        List<ActivityTransitionEvent> events = result.getTransitionEvents();
        if (events == null || events.isEmpty()) {
            return;
        }
        
        for (ActivityTransitionEvent event : events) {
            int transitionType = event.getTransitionType();
            int activityType = event.getActivityType();
            
            // Update last activity
            lastActivity = event;
            
            // Convert activity type to string
            String activityName = getActivityName(activityType);
            
            LogHelper.d(getApplicationContext(), TAG, "Activity Transition: " + 
                (transitionType == ActivityTransition.ACTIVITY_TRANSITION_ENTER ? "ENTER" : "EXIT") + 
                " - " + activityName);
            
            // Emit ActivityChangeEvent
            try {
                ActivityChangeEvent activityEvent = new ActivityChangeEvent(activityName, 100);
                EventBus.getDefault().post(activityEvent);
            } catch (Exception e) {
                LogHelper.e(TAG, "Error emitting ActivityChangeEvent: " + e.getMessage(), e);
            }
            
            // Check if this is a "moving" activity
            boolean isMoving = isMovingActivity(activityType);
            
            // Update config if needed
            if (config.isMoving != isMoving) {
                config.isMoving = isMoving;
                config.save();
                
                // Emit MotionChangeEvent
                try {
                    JSONObject locationJson = new JSONObject();
                    locationJson.put("timestamp", System.currentTimeMillis());
                    locationJson.put("is_moving", isMoving);
                    locationJson.put("activity", activityName);
                    
                    MotionChangeEvent motionEvent = new MotionChangeEvent(isMoving, locationJson);
                    EventBus.getDefault().post(motionEvent);
                } catch (JSONException e) {
                    LogHelper.e(TAG, "Error creating MotionChangeEvent: " + e.getMessage(), e);
                }
            }
        }
    }
    
    /**
     * Handle Activity Recognition Result (legacy API)
     */
    private void handleActivityRecognitionResult(ActivityRecognitionResult result) {
        if (result == null) {
            return;
        }
        
        DetectedActivity mostProbableActivity = result.getMostProbableActivity();
        if (mostProbableActivity == null) {
            return;
        }
        
        int activityType = mostProbableActivity.getType();
        int confidence = mostProbableActivity.getConfidence();
        String activityName = getActivityName(activityType);
        
        LogHelper.d(getApplicationContext(), TAG, "Activity Recognition: " + activityName + " (confidence: " + confidence + ")");
        
        // Emit ActivityChangeEvent
        try {
            ActivityChangeEvent activityEvent = new ActivityChangeEvent(activityName, confidence);
            EventBus.getDefault().post(activityEvent);
        } catch (Exception e) {
            LogHelper.e(TAG, "Error emitting ActivityChangeEvent: " + e.getMessage(), e);
        }
    }
    
    /**
     * Check if activity type indicates movement
     */
    private boolean isMovingActivity(int activityType) {
        return activityType == DetectedActivity.IN_VEHICLE ||
               activityType == DetectedActivity.ON_BICYCLE ||
               activityType == DetectedActivity.RUNNING ||
               activityType == DetectedActivity.WALKING ||
               activityType == DetectedActivity.ON_FOOT;
    }
    
    /**
     * Get activity name from type
     */
    private String getActivityName(int activityType) {
        switch (activityType) {
            case DetectedActivity.IN_VEHICLE:
                return "in_vehicle";
            case DetectedActivity.ON_BICYCLE:
                return "on_bicycle";
            case DetectedActivity.RUNNING:
                return "running";
            case DetectedActivity.WALKING:
                return "walking";
            case DetectedActivity.ON_FOOT:
                return "on_foot";
            case DetectedActivity.STILL:
                return "still";
            default:
                return "unknown";
        }
    }
    
    /**
     * Start activity recognition
     * requestActivityUpdates
     */
    public static void start(Context context) {
        Context appContext = context.getApplicationContext();
        Config config = Config.getInstance(appContext);
        
        // Check if motion activity updates are disabled
        if (config.disableMotionActivityUpdates) {
            LogHelper.d(appContext, TAG, "Motion activity updates disabled");
            return;
        }
        
        // Check permission (activity recognition permission)
        if (!hasActivityPermission(appContext)) {
            LogHelper.w(TAG, "Activity recognition permission not granted");
            return;
        }
        
        LogHelper.i(TAG, "✅ Start motion-activity updates");
        
        ActivityRecognitionClient client = ActivityRecognition.getClient(appContext);
        PendingIntent pendingIntent = getPendingIntent(appContext);
        
        // Request activity updates (legacy API - simpler)
        client.requestActivityUpdates(0, pendingIntent)
            .addOnSuccessListener(aVoid -> {
                LogHelper.d(appContext, TAG, "Activity recognition started successfully");
                isStarted.set(true);
            })
            .addOnFailureListener(e -> {
                LogHelper.w(TAG, "Failed to start activity recognition: " + e.getMessage());
                isStarted.set(false);
                
                // Try activity transitions (newer API)
                try {
                    startActivityTransitions(appContext);
                } catch (Exception ex) {
                    LogHelper.e(TAG, "Failed to start activity transitions: " + ex.getMessage(), ex);
                }
            });
    }
    
    /**
     * Start activity transitions (newer API)
     */
    private static void startActivityTransitions(Context context) {
        List<ActivityTransition> transitions = new ArrayList<>();
        
        // Add transitions for common activities
        int[] activities = {
            DetectedActivity.STILL,
            DetectedActivity.WALKING,
            DetectedActivity.RUNNING,
            DetectedActivity.ON_FOOT,
            DetectedActivity.IN_VEHICLE,
            DetectedActivity.ON_BICYCLE
        };
        
        for (int activity : activities) {
            // ENTER transition
            transitions.add(new ActivityTransition.Builder()
                .setActivityType(activity)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                .build());
            
            // EXIT transition
            transitions.add(new ActivityTransition.Builder()
                .setActivityType(activity)
                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                .build());
        }
        
        // CRITICAL: Check ACTIVITY_RECOGNITION permission before requesting ()
        if (!hasActivityPermission(context)) {
            LogHelper.w(TAG, "⚠️ ACTIVITY_RECOGNITION permission not granted - skipping activity recognition");
            return;
        }
        
        ActivityRecognitionClient client = ActivityRecognition.getClient(context);
        PendingIntent pendingIntent = getPendingIntent(context);
        
        ActivityTransitionRequest request = new ActivityTransitionRequest(transitions);
        
        try {
            client.requestActivityTransitionUpdates(request, pendingIntent)
            .addOnSuccessListener(aVoid -> {
                LogHelper.d(context, TAG, "✅ Activity transitions started successfully");
                isStarted.set(true);
            })
            .addOnFailureListener(e -> {
                LogHelper.e(TAG, "❌ Failed to start activity transitions: " + e.getMessage(), e);
                isStarted.set(false);
            });
        } catch (SecurityException e) {
            LogHelper.e(TAG, "❌ SecurityException: ACTIVITY_RECOGNITION permission not granted", e);
            isStarted.set(false);
        } catch (Exception e) {
            LogHelper.e(TAG, "❌ Error starting activity recognition: " + e.getMessage(), e);
            isStarted.set(false);
        }
    }
    
    /**
     * Stop activity recognition
     */
    public static void stop(Context context) {
        LogHelper.i(TAG, "🔴 Stop motion-activity updates");
        
        ActivityRecognitionClient client = ActivityRecognition.getClient(context);
        PendingIntent pendingIntent = getPendingIntent(context);
        
        client.removeActivityTransitionUpdates(pendingIntent);
        client.removeActivityUpdates(pendingIntent);
        
        isStarted.set(false);
        stopService(context);
    }
    
    /**
     * Stop service
     */
    private static void stopService(Context context) {
        Intent intent = new Intent(context, ActivityRecognitionService.class);
        context.stopService(intent);
    }
    
    /**
     * Get pending intent for activity recognition
     */
    private static PendingIntent getPendingIntent(Context context) {
        Intent intent = new Intent(context, ActivityRecognitionService.class);
        
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        
        return PendingIntent.getService(context, 0, intent, flags);
    }
    
    /**
     * Check if activity recognition permission is granted
     * Use LocationAuthorization helper
     */
    private static boolean hasActivityPermission(Context context) {
        return com.backgroundlocation.util.LocationAuthorization.hasActivityPermission(context);
    }
    
    /**
     * Check if service is started
     */
    public static boolean isStarted() {
        return isStarted.get();
    }
    
    /**
     * Get last detected activity
     */
    public static ActivityTransitionEvent getLastActivity() {
        return lastActivity;
    }
    
    /**
     * Get most probable activity (for compatibility)
     */
    public static ActivityTransitionEvent getMostProbableActivity() {
        return lastActivity;
    }
    
    /**
     * Check if device is moving based on last activity
     */
    public static boolean isMoving(Context context) {
        Config config = Config.getInstance(context);
        int activityType = lastActivity.getActivityType();
        
        return activityType == DetectedActivity.IN_VEHICLE ||
               activityType == DetectedActivity.ON_BICYCLE ||
               activityType == DetectedActivity.RUNNING ||
               activityType == DetectedActivity.WALKING ||
               activityType == DetectedActivity.ON_FOOT;
    }
}

