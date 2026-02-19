package com.backgroundlocation.service;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import androidx.core.app.NotificationCompat;
import com.backgroundlocation.Constants;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.service.ForegroundNotification;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingEvent;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.LocationResult;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

/**
 * AbstractService
 * AbstractService.java
 * Tüm servislerin extend ettiği base service sınıfı
 */
public abstract class AbstractService extends Service {
    
    private static final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private static final AtomicBoolean isReady = new AtomicBoolean(false);
    private static final String FOREGROUND_SERVICE_START_NOT_ALLOWED = "ForegroundServiceStartNotAllowedException";
    private static final List<String> activeServices = new ArrayList<>();
    private static final List<Intent> queuedIntents = new ArrayList<>();
    
    private long onCreateTime;
    private int startId;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private final AtomicInteger eventCount = new AtomicInteger(0);
    private final AtomicInteger lastStartId = new AtomicInteger(0);
    private final AtomicBoolean isSticky = new AtomicBoolean(false);
    private final AtomicReference<Runnable> stopRunnable = new AtomicReference<>();
    protected final List<Intent> pendingIntents = new ArrayList<>();
    protected Date startTime;
    private String serviceName = "AbstractService";
    
    /**
     * Check if any service is active
     */
    static boolean isAnyServiceActive() {
        synchronized (activeServices) {
            return !activeServices.isEmpty();
        }
    }
    
    /**
     * Mark service as active
     */
    private static void markServiceActive(String serviceName) {
        synchronized (activeServices) {
            if (!activeServices.contains(serviceName)) {
                activeServices.add(serviceName);
            }
        }
    }
    
    /**
     * Mark service as inactive
     */
    private static void markServiceInactive(String serviceName) {
        synchronized (activeServices) {
            activeServices.remove(serviceName);
        }
    }
    
    /**
     * Get queued intents
     */
    private static List<Intent> getQueuedIntents() {
        synchronized (queuedIntents) {
            List<Intent> result = new ArrayList<>(queuedIntents);
            queuedIntents.clear();
            return result;
        }
    }
    
    /**
     * Launch queued services
     */
    public static void launchQueuedServices(Context context) {
        for (Intent intent : getQueuedIntents()) {
            startForegroundService(context, intent);
        }
    }
    
    /**
     * Launch service
     */
    public static void launchService(Context context, Class<?> cls, String action) {
        Intent intent = new Intent(context, cls);
        intent.setAction(action);
        startForegroundService(context, intent);
    }
    
    /**
     * Set initialization state
     */
    public static void setInitialized(boolean initialized, boolean ready) {
        isInitialized.set(initialized);
        isReady.set(ready);
    }
    
    /**
     * Start foreground service (with error handling)
     */
    public static void startForegroundService(Context context, Intent intent) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent);
            } else {
                context.startService(intent);
            }
        } catch (Exception e) {
            if (Build.VERSION.SDK_INT < 31 || 
                !e.getClass().getSimpleName().equalsIgnoreCase(FOREGROUND_SERVICE_START_NOT_ALLOWED)) {
                LogHelper.e("AbstractService", "ERROR starting foreground service: " + intent + ", error: " + e.getMessage(), e);
                return;
            }
            
            // Retry with geofence workaround
            int launchFailures = intent.getIntExtra("launch_failures", 0) + 1;
            if (launchFailures > 1) {
                LogHelper.e("AbstractService", "LAUNCH DENIED (2nd try). Giving up. " + intent);
                return;
            }
            
            intent.putExtra("launch_failures", launchFailures);
            queueIntent(intent);
            
            // Use geofence workaround for Android 12+
            if (Build.VERSION.SDK_INT >= 33) {
                AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
                if (alarmManager != null && alarmManager.canScheduleExactAlarms()) {
                    LogHelper.w("AbstractService", "Background FGS launch denied: Retrying with AlarmManager... " + intent);
                    // TODO: Implement schedule manager
                    // TSScheduleManager.getInstance(context).oneShot(LaunchForegroundServiceEvent.ACTION, 0, true, true);
                } else {
                    LogHelper.w("AbstractService", "Background FGS launch denied: Retrying with geofence... " + intent);
                    startForegroundServiceWithGeofence(context, intent);
                }
            } else {
                LogHelper.w("AbstractService", "Background FGS launch denied: Retrying with AlarmManager... " + intent);
                // TODO: Implement schedule manager
            }
        }
    }
    
    /**
     * Queue intent for later launch
     */
    private static void queueIntent(Intent intent) {
        synchronized (queuedIntents) {
            queuedIntents.add(intent);
        }
    }
    
    /**
     * Start foreground service using geofence workaround
     */
    private static void startForegroundServiceWithGeofence(Context context, Intent intent) {
        // Get last location and create geofence
        // This is a workaround for Android 12+ background service launch restrictions
        // TODO: Implement location manager
        LogHelper.w("AbstractService", "Geofence workaround not fully implemented");
    }
    
    /**
     * Stop service
     */
    public static void stop(Context context, Class<?> cls) {
        Intent intent = new Intent(context, cls);
        if (isServiceActive(cls.getSimpleName())) {
            intent.setAction(Constants.ACTION_STOP);
            startForegroundService(context, intent);
        }
    }
    
    /**
     * Check if service is active
     */
    static boolean isServiceActive(String serviceName) {
        synchronized (activeServices) {
            return activeServices.contains(serviceName);
        }
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    @Override
    public void onDestroy() {
        stopService();
        markServiceInactive(serviceName);
        LogHelper.d(serviceName, serviceName + " stopped");
    }
    
    @Override
    public void onTimeout(int startId, int stopId) {
        LogHelper.w(serviceName, "Force stopping Service");
        setIsSticky(false);
        finish(startId);
        super.onTimeout(startId, stopId);
    }
    
    /**
     * Initialize service
     */
    protected void initialize(String serviceName, int notificationId) {
        this.serviceName = serviceName;
        this.startId = notificationId;
        this.onCreateTime = System.currentTimeMillis();
        super.onCreate();
        
        // Start foreground notification
        startForegroundNotification();
        
        // Mark as active
        markServiceActive(serviceName);
        
        // Initialize adapter
        BackgroundLocationAdapter.getThreadPool().execute(() -> {
            BackgroundLocationAdapter.getInstance(getApplicationContext());
        });
    }
    
    /**
     * Start foreground notification
     */
    private void startForegroundNotification() {
        if (startTime == null && isSticky.get()) {
            startTime = new Date();
        }
        
        try {
            if (onCreateTime >= 0) {
                long dt = System.currentTimeMillis() - onCreateTime;
                if (dt > 250) {
                    LogHelper.d(serviceName, "dt onCreate -> startForeground(): " + dt + "ms");
                }
                onCreateTime = -1;
            }
            
            Notification notification = ForegroundNotification.build(getApplicationContext());
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(ForegroundNotification.NOTIFICATION_ID, notification, -1);
            } else {
                startForeground(ForegroundNotification.NOTIFICATION_ID, notification);
            }
        } catch (Exception e) {
            stopSelf();
            LogHelper.e(serviceName, "Error starting foreground: " + e.getMessage(), e);
        }
    }
    
    /**
     * Handle start command
     */
    protected boolean handleStartCommand(Intent intent, int startId, boolean checkEnabled) {
        lastStartId.set(startId);
        eventCount.incrementAndGet();
        
        Config config = Config.getInstance(getApplicationContext());
        
        if (!isInitialized.get() || !isReady.get()) {
            config.reset();
            stopSelf();
            return false;
        }
        
        // Start foreground notification
        startForegroundNotification();
        
        String action = intent.getAction();
        if (action != null) {
            if (action.equalsIgnoreCase(Constants.ACTION_STOP)) {
                stopService();
                return false;
            } else if (action.equalsIgnoreCase(Constants.ACTION_START)) {
                // Handle location result if present
                if (LocationResult.hasResult(intent)) {
                    LocationResult locationResult = LocationResult.extractResult(intent);
                    if (locationResult != null) {
                        for (Location location : locationResult.getLocations()) {
                            handleLocation(location);
                        }
                    }
                }
                
                // Handle geofencing event if present
                GeofencingEvent geofencingEvent = GeofencingEvent.fromIntent(intent);
                if (geofencingEvent != null) {
                    handleGeofencingEvent(geofencingEvent);
                }
                
                setIsSticky(true);
            } else if (action.equalsIgnoreCase(Constants.ACTION_NOTIFICATION_ACTION)) {
                LogHelper.d(serviceName, "[notificationaction] " + intent.getStringExtra("id"));
                if (intent.hasExtra("id")) {
                    String actionId = intent.getStringExtra("id");
                    // Handle notification action
                    BackgroundLocationAdapter.getInstance(getApplicationContext())
                        .fireNotificationActionListeners(actionId);
                } else {
                    LogHelper.w(serviceName, "Notification action received with no id");
                }
            }
        }
        
        if (!checkEnabled || config.enabled) {
            if (action == null) {
                action = Constants.ACTION_START;
            }
            LogHelper.d(serviceName, action + " [" + serviceName + " startId: " + startId + ", eventCount: " + eventCount.get() + "]");
            
            if (isSticky.get() && !pendingIntents.contains(intent)) {
                pendingIntents.add(intent);
            }
            return true;
        }
        
        LogHelper.w(serviceName, "Refusing to start " + serviceName + ", enabled: false");
        stopService();
        return false;
    }
    
    /**
     * Handle location (override in subclasses)
     */
    protected void handleLocation(Location location) {
        // Override in subclasses
    }
    
    /**
     * Handle geofencing event (override in subclasses)
     */
    protected void handleGeofencingEvent(GeofencingEvent geofencingEvent) {
        if (geofencingEvent.hasError()) {
            LogHelper.i(serviceName, "Geofencing Error: " + geofencingEvent.getErrorCode());
            return;
        }
        
        List<Geofence> triggeringGeofences = geofencingEvent.getTriggeringGeofences();
        if (triggeringGeofences != null) {
            for (Geofence geofence : triggeringGeofences) {
                if (geofence.getRequestId().equals(Constants.FOREGROUND_SERVICE_GEOFENCE)) {
                    LogHelper.i(serviceName, "Foreground-service launched with geofence workaround");
                    removeForegroundServiceGeofence(getApplicationContext());
                    return;
                }
            }
        }
    }
    
    /**
     * Remove foreground service geofence
     */
    private static void removeForegroundServiceGeofence(Context context) {
        GeofencingClient geofencingClient = LocationServices.getGeofencingClient(context);
        if (geofencingClient == null) {
            LogHelper.w("AbstractService", "GeofencingClient is null");
            return;
        }
        
        List<String> geofenceIds = new ArrayList<>();
        geofenceIds.add(Constants.FOREGROUND_SERVICE_GEOFENCE);
        geofencingClient.removeGeofences(geofenceIds);
    }
    
    /**
     * Set sticky state
     */
    protected void setIsSticky(boolean sticky) {
        isSticky.set(sticky);
    }
    
    /**
     * Finish service
     */
    protected void finish(int startId) {
        LogHelper.d(serviceName, "FINISH [" + serviceName + " startId: " + startId + ", eventCount: " + 
            Math.max(eventCount.decrementAndGet(), 0) + ", sticky: " + isSticky.get() + "]");
        
        if (!isSticky.get() && eventCount.get() <= 0) {
            scheduleStop(200);
        }
    }
    
    /**
     * Schedule stop
     */
    private void scheduleStop(long delay) {
        cancelStopRunnable();
        synchronized (stopRunnable) {
            stopRunnable.set(() -> {
                if (isSticky.get()) {
                    stopService();
                } else if (eventCount.get() <= 0) {
                    LogHelper.d(serviceName, "stopSelfResult(" + lastStartId.get() + "): " + stopSelfResult(lastStartId.get()));
                }
            });
            handler.postDelayed(stopRunnable.get(), delay);
        }
    }
    
    /**
     * Cancel stop runnable
     */
    private void cancelStopRunnable() {
        synchronized (stopRunnable) {
            if (stopRunnable.get() != null) {
                handler.removeCallbacks(stopRunnable.get());
                stopRunnable.set(null);
            }
        }
    }
    
    /**
     * Stop service
     */
    private void stopService() {
        LogHelper.d(serviceName, "STOP [" + serviceName + " startId: " + lastStartId.get() + ", eventCount: " + eventCount.get() + "]");
        isSticky.set(false);
        finish(lastStartId.get());
    }
}

