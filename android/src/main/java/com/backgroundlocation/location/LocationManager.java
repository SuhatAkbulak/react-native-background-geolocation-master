package com.backgroundlocation.location;

import android.content.Context;
import android.location.Location;
import androidx.core.location.LocationManagerCompat;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * LocationManager
 * LocationManager
 * Location manager - location request'leri yönetir
 */
public class LocationManager {
    
    private static final String TAG = "LocationManager";
    public static final int LOCATION_ERROR_BACKGROUND_WHEN_IN_USE = 3;
    public static final int LOCATION_ERROR_CANCELLED = 499;
    public static final int LOCATION_ERROR_DENIED = 1;
    public static final int LOCATION_ERROR_MINIMUM_ACCURACY = 100;
    public static final int LOCATION_ERROR_NETWORK = 2;
    public static final int LOCATION_ERROR_NOT_INITIALIZED = -1;
    public static final int LOCATION_ERROR_TIMEOUT = 408;
    public static final int LOCATION_ERROR_TRACKING_MODE_DISABLED = 101;
    public static final int LOCATION_ERROR_UNKNOWN = 0;
    
    private static final float GOOD_ACCURACY_THRESHOLD = 250.0f;
    
    private static LocationManager instance = null;
    private static final AtomicInteger requestIdCounter = new AtomicInteger(0);
    
    private final Context context;
    private final FusedLocationProviderClient fusedLocationClient;
    private final Map<Integer, SingleLocationRequest> activeRequests = new HashMap<>();
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final Location lastKnownLocation = new Location("LocationManager");
    
    public interface LocationCallback {
        void onFailure(String error);
        void onLocation(Location location);
    }
    
    private LocationManager(Context context) {
        this.context = context.getApplicationContext();
        this.fusedLocationClient = LocationServices.getFusedLocationProviderClient(this.context);
        
        // Register EventBus
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        
        isInitialized.set(true);
        LogHelper.d(TAG, "LocationManager initialized");
    }
    
    private static synchronized LocationManager getInstanceInternal(Context context) {
        if (instance == null) {
            instance = new LocationManager(context.getApplicationContext());
        }
        return instance;
    }
    
    public static LocationManager getInstance(Context context) {
        if (instance == null) {
            instance = getInstanceInternal(context.getApplicationContext());
        }
        return instance;
    }
    
    /**
     * Get last known location
     */
    public void getLastLocation(LocationCallback callback) {
        if (!isInitialized.get()) {
            if (callback != null) {
                callback.onFailure("LocationManager not initialized");
            }
            return;
        }
        
        fusedLocationClient.getLastLocation()
            .addOnSuccessListener((Location location) -> {
                if (location != null) {
                    synchronized (lastKnownLocation) {
                        lastKnownLocation.set(location);
                    }
                    if (callback != null) {
                        callback.onLocation(location);
                    }
                } else {
                    if (callback != null) {
                        callback.onFailure("No last known location");
                    }
                }
            })
            .addOnFailureListener(e -> {
                LogHelper.e(TAG, "Failed to get last location: " + e.getMessage(), e);
                if (callback != null) {
                    callback.onFailure(e.getMessage());
                }
            });
    }
    
    /**
     * Check if location services are enabled
     */
    public Boolean isLocationServicesEnabled() {
        android.location.LocationManager locationManager = (android.location.LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        if (locationManager == null) {
            return false;
        }
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            return LocationManagerCompat.isLocationEnabled(locationManager);
        } else {
            return locationManager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) ||
                   locationManager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER);
        }
    }
    
    /**
     * Calculate location age
     */
    public static long locationAge(Location location) {
        if (location == null) {
            return Long.MAX_VALUE;
        }
        return System.currentTimeMillis() - location.getTime();
    }
    
    /**
     * Register location request
     */
    public void register(SingleLocationRequest request) {
        synchronized (activeRequests) {
            activeRequests.put(request.getId(), request);
        }
        request.start();
    }
    
    /**
     * Unregister location request
     */
    public void unregister(int requestId) {
        synchronized (activeRequests) {
            SingleLocationRequest request = activeRequests.remove(requestId);
            if (request != null) {
                request.cancel();
            }
        }
    }
    
    /**
     * Handle single location result
     */
    public void onSingleLocationResult(SingleLocationResult result) {
        SingleLocationRequest request;
        synchronized (activeRequests) {
            request = activeRequests.get(result.getRequestId());
        }
        
        if (request != null) {
            request.onLocation(result.getLocation());
        }
    }
    
    /**
     * Get FusedLocationProviderClient
     */
    public FusedLocationProviderClient getFusedLocationClient() {
        return fusedLocationClient;
    }
    
    /**
     * Generate unique request ID
     */
    public static int generateRequestId() {
        return requestIdCounter.incrementAndGet();
    }
    
    /**
     * Destroy manager
     */
    public void destroy() {
        synchronized (activeRequests) {
            for (SingleLocationRequest request : activeRequests.values()) {
                request.cancel();
            }
            activeRequests.clear();
        }
        
        if (EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().unregister(this);
        }
        
        isInitialized.set(false);
        LogHelper.d(TAG, "LocationManager destroyed");
    }
}

