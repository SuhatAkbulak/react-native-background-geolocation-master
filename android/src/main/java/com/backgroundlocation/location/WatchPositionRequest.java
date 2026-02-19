package com.backgroundlocation.location;

import android.app.PendingIntent;
import android.content.Context;
import android.os.Build;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.service.LocationRequestService;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

import java.util.concurrent.atomic.AtomicBoolean;

/**
 * WatchPositionRequest
 * TSWatchPositionRequest.java
 * Watch position request - continuous location updates
 */
public class WatchPositionRequest extends SingleLocationRequest {
    
    private long interval;
    private PendingIntent pendingIntent;
    private final AtomicBoolean isWatching = new AtomicBoolean(false);
    
    public static class Builder extends SingleLocationRequest.Builder<Builder> {
        private long interval = 1000;
        
        public Builder(Context context) {
            super(context);
            this.action = ACTION_WATCH_POSITION;
            Config config = Config.getInstance(context);
            this.desiredAccuracy = config.desiredAccuracy;
        }
        
        public Builder setInterval(Long interval) {
            this.interval = interval;
            return this;
        }
        
        public WatchPositionRequest build() {
            return new WatchPositionRequest(this);
        }
    }
    
    WatchPositionRequest(Builder builder) {
        super(builder);
        Config config = Config.getInstance(context);
        this.desiredAccuracy = config.desiredAccuracy;
        this.interval = builder.interval;
    }
    
    @Override
    protected void requestLocation() {
        FusedLocationProviderClient client = LocationServices.getFusedLocationProviderClient(context);
        
        LocationRequest locationRequest = new LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            interval
        )
        .setMaxUpdateDelayMillis(interval * 2)
        .setWaitForAccurateLocation(false)
        .build();
        
        try {
            pendingIntent = getPendingIntent();
            client.requestLocationUpdates(locationRequest, pendingIntent);
            isWatching.set(true);
            
            // Start service
            LocationRequestService.start(context);
        } catch (SecurityException e) {
            onError(LocationManager.LOCATION_ERROR_DENIED);
            finish();
        }
    }
    
    @Override
    public void cancel() {
        synchronized (isWatching) {
            isWatching.set(false);
        }
        
        if (pendingIntent != null) {
            FusedLocationProviderClient client = LocationServices.getFusedLocationProviderClient(context);
            client.removeLocationUpdates(pendingIntent);
        }
        
        LocationRequestService.stop(context);
        super.cancel();
    }
    
    public long getInterval() {
        return interval;
    }
}

