package com.backgroundlocation.location;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import com.backgroundlocation.adapter.callback.LocationCallback;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.LocationModel;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * SingleLocationRequest
 * SingleLocationRequest
 * Tek location request yönetimi
 */
public class SingleLocationRequest {
    
    public static final int ACTION_GET_CURRENT_POSITION = 2;
    public static final int ACTION_GET_CURRENT_STATE = 4;
    public static final int ACTION_MOTION_CHANGE = 1;
    public static final int ACTION_PROVIDER_CHANGE = 3;
    public static final int ACTION_WATCH_POSITION = 5;
    public static final Float GOOD_ACCURACY_THRESHOLD = 10.0f;
    
    protected int action = 0;
    protected Context context;
    protected long timeout;
    protected final AtomicInteger state;
    protected boolean persist;
    protected int desiredAccuracy;
    protected int samples;
    protected LocationCallback callback;
    
    private final int requestId;
    private final AtomicInteger samplesReceived;
    private final AtomicBoolean isFinished;
    private final AtomicBoolean isCancelled;
    private long startTime;
    private final Handler handler;
    private Runnable timeoutRunnable;
    private final List<com.backgroundlocation.location.Location> locationSamples;
    
    public static class Builder<T extends Builder<T>> {
        Context context;
        int timeout;
        boolean persist;
        int samples = 3;
        int desiredAccuracy;
        LocationCallback callback;
        protected int action;
        
        public Builder(Context context) {
            Config config = Config.getInstance(context);
            this.context = context;
            this.persist = config.enabled;
            this.timeout = 60000; // Default 60 seconds
            this.desiredAccuracy = config.desiredAccuracy;
            this.callback = null;
        }
        
        public SingleLocationRequest build() {
            return new SingleLocationRequest(this);
        }
        
        public int getAction() {
            return action;
        }
        
        public T setCallback(LocationCallback callback) {
            this.callback = callback;
            return (T) this;
        }
        
        public T setDesiredAccuracy(int desiredAccuracy) {
            this.desiredAccuracy = desiredAccuracy;
            return (T) this;
        }
        
        public T setPersist(boolean persist) {
            this.persist = persist;
            return (T) this;
        }
        
        public T setSamples(int samples) {
            this.samples = samples;
            return (T) this;
        }
        
        public T setTimeout(int timeout) {
            this.timeout = timeout;
            return (T) this;
        }
    }
    
    protected SingleLocationRequest(Builder builder) {
        this.requestId = LocationManager.generateRequestId();
        this.context = builder.context;
        this.action = builder.action;
        this.timeout = builder.timeout;
        this.persist = builder.persist;
        this.desiredAccuracy = builder.desiredAccuracy;
        this.samples = builder.samples;
        this.callback = builder.callback;
        this.state = new AtomicInteger(0);
        this.samplesReceived = new AtomicInteger(0);
        this.isFinished = new AtomicBoolean(false);
        this.isCancelled = new AtomicBoolean(false);
        this.handler = new Handler(Looper.getMainLooper());
        this.locationSamples = new ArrayList<>();
    }
    
    public int getId() {
        return requestId;
    }
    
    public void start() {
        if (isCancelled.get() || isFinished.get()) {
            return;
        }
        
        startTime = System.currentTimeMillis();
        
        // Start timeout
        if (timeout > 0) {
            timeoutRunnable = () -> {
                if (!isFinished.get() && !isCancelled.get()) {
                    onError(LocationManager.LOCATION_ERROR_TIMEOUT);
                    finish();
                }
            };
            handler.postDelayed(timeoutRunnable, timeout);
        }
        
        // Request location
        requestLocation();
    }
    
    protected void requestLocation() {
        FusedLocationProviderClient client = LocationServices.getFusedLocationProviderClient(context);
        
        LocationRequest locationRequest = new LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            samples > 1 ? 1000 : 0
        )
        .setMaxUpdateDelayMillis(5000)
        .setWaitForAccurateLocation(false)
        .build();
        
        try {
            PendingIntent pendingIntent = getPendingIntent();
            client.requestLocationUpdates(locationRequest, pendingIntent);
        } catch (SecurityException e) {
            LogHelper.e("SingleLocationRequest", "SecurityException: " + e.getMessage(), e);
            onError(LocationManager.LOCATION_ERROR_DENIED);
            finish();
        }
    }
    
    protected PendingIntent getPendingIntent() {
        Intent intent = new Intent(context, com.backgroundlocation.service.LocationRequestService.class);
        intent.putExtra("requestId", requestId);
        intent.putExtra("action", action);
        
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        
        return PendingIntent.getForegroundService(context, requestId, intent, flags);
    }
    
    protected void onLocation(android.location.Location location) {
        if (isFinished.get() || isCancelled.get()) {
            return;
        }
        
        // Convert android.location.Location to com.backgroundlocation.location.Location
        com.backgroundlocation.location.Location bgLocation = new com.backgroundlocation.location.Location(context, location, null);
        locationSamples.add(bgLocation);
        int received = samplesReceived.incrementAndGet();
        
        if (received >= samples) {
            // Got enough samples, finish
            com.backgroundlocation.location.Location bestLocation = getBestLocation();
            if (bestLocation != null) {
                onSuccess(bestLocation);
            }
            finish();
        }
    }
    
    protected com.backgroundlocation.location.Location getBestLocation() {
        if (locationSamples.isEmpty()) {
            return null;
        }
        
        // Return most accurate location
        com.backgroundlocation.location.Location best = locationSamples.get(0);
        for (com.backgroundlocation.location.Location loc : locationSamples) {
            if (loc.getAccuracy() < best.getAccuracy()) {
                best = loc;
            }
        }
        return best;
    }
    
    protected void onSuccess(com.backgroundlocation.location.Location location) {
        if (callback != null && location != null) {
            // Convert Location to LocationModel
            LocationModel locationModel = location.toLocationModel();
            callback.onLocation(locationModel);
        }
    }
    
    protected void onError(int errorCode) {
        if (callback != null) {
            callback.onError(errorCode);
        }
    }
    
    protected void finish() {
        if (isFinished.compareAndSet(false, true)) {
            cancelTimeout();
            LocationManager.getInstance(context).unregister(requestId);
        }
    }
    
    public void cancel() {
        if (isCancelled.compareAndSet(false, true)) {
            cancelTimeout();
            LocationManager.getInstance(context).unregister(requestId);
        }
    }
    
    private void cancelTimeout() {
        if (timeoutRunnable != null) {
            handler.removeCallbacks(timeoutRunnable);
            timeoutRunnable = null;
        }
    }
    
    protected boolean shouldContinue() {
        return !isFinished.get() && !isCancelled.get();
    }
}

