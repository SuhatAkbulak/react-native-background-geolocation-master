package com.backgroundlocation.service;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.IBinder;
import com.backgroundlocation.location.LocationManager;
import com.backgroundlocation.location.SingleLocationResult;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.LocationResult;

/**
 * LocationRequestService
 * LocationRequestService.java
 * Location request service - handles location updates for single location requests
 */
public class LocationRequestService extends Service {
    
    private static final String TAG = "LocationRequestService";
    
    @Override
    public void onCreate() {
        super.onCreate();
        LogHelper.d(TAG, "LocationRequestService created");
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            return START_NOT_STICKY;
        }
        
        // Handle location result
        if (LocationResult.hasResult(intent)) {
            LocationResult locationResult = LocationResult.extractResult(intent);
            if (locationResult != null) {
                int requestId = intent.getIntExtra("requestId", -1);
                if (requestId >= 0) {
                    for (Location location : locationResult.getLocations()) {
                        SingleLocationResult result = new SingleLocationResult(requestId, location);
                        LocationManager.getInstance(this).onSingleLocationResult(result);
                    }
                } else {
                    LogHelper.w(TAG, "Received location update without requestId");
                }
            }
        }
        
        // Stop self if no more work
        stopSelf();
        return START_NOT_STICKY;
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    /**
     * Start service
     */
    public static void start(Context context) {
        Intent intent = new Intent(context, LocationRequestService.class);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }
    
    /**
     * Stop service
     */
    public static void stop(Context context) {
        Intent intent = new Intent(context, LocationRequestService.class);
        context.stopService(intent);
    }
}

