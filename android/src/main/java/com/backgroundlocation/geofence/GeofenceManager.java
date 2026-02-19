package com.backgroundlocation.geofence;

import android.content.Context;
import android.location.Location;
import android.os.Handler;
import android.os.Looper;

import com.backgroundlocation.adapter.callback.Callback;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.data.GeofenceModel;
import com.backgroundlocation.data.sqlite.SQLiteGeofenceDAO;
import com.backgroundlocation.util.LogHelper;
import com.google.android.gms.location.Geofence;
import com.google.android.gms.location.GeofencingClient;
import com.google.android.gms.location.GeofencingRequest;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Geofence Manager
 * TSGeofenceManager.java
 * Manages geofence monitoring and evaluation
 */
public class GeofenceManager {
    private static final String TAG = "GeofenceManager";
    public static final int MAX_GEOFENCES = 97; // Google Play Services limit
    public static final float MINIMUM_STATIONARY_RADIUS = 150.0f;
    
    private static GeofenceManager instance;
    
    private final Context context;
    private final Config config;
    private final SQLiteGeofenceDAO geofenceDatabase;
    private final GeofencingClient geofencingClient;
    private final Handler handler;
    
    private final AtomicBoolean isMonitoring = new AtomicBoolean(false);
    private final AtomicInteger geofenceCount = new AtomicInteger(0);
    private Location lastLocation;
    
    /**
     * Private constructor (Singleton)
     */
    private GeofenceManager(Context context) {
        this.context = context.getApplicationContext();
        this.config = Config.getInstance(this.context);
        this.geofenceDatabase = SQLiteGeofenceDAO.getInstance(this.context);
        this.geofencingClient = LocationServices.getGeofencingClient(this.context);
        this.handler = new Handler(Looper.getMainLooper());
        
        // Note: GeofenceManager doesn't need to subscribe to EventBus
        // Geofence events are handled by GeofenceBroadcastReceiver
        
        // Initialize geofence count
        geofenceCount.set(geofenceDatabase.count());
        
        LogHelper.d(TAG, "✅ GeofenceManager initialized");
    }
    
    /**
     * Get singleton instance
     */
    public static GeofenceManager getInstance(Context context) {
        if (instance == null) {
            synchronized (GeofenceManager.class) {
                if (instance == null) {
                    instance = new GeofenceManager(context);
                }
            }
        }
        return instance;
    }
    
    /**
     * Add geofence
     * addGeofence()
     */
    public void addGeofence(GeofenceModel geofence, Callback callback) {
        if (geofence == null) {
            if (callback != null) {
                callback.onFailure("Geofence is null");
            }
            return;
        }
        
        // Validate
        if (!geofence.validate()) {
            IllegalArgumentException error = geofence.getValidationError();
            if (callback != null) {
                callback.onFailure("Geofence validation failed: " + 
                    (error != null ? error.getMessage() : "Unknown error"));
            }
            return;
        }
        
        // Check if already exists
        if (geofenceDatabase.exists(geofence.getIdentifier())) {
            if (callback != null) {
                callback.onFailure("Geofence with identifier '" + 
                    geofence.getIdentifier() + "' already exists");
            }
            return;
        }
        
        // Save to database
        geofenceDatabase.persist(geofence);
        geofenceCount.set(geofenceDatabase.count());
        
        // Register with Google Play Services
        registerGeofence(geofence, callback);
    }
    
    /**
     * Add multiple geofences
     * addGeofences()
     */
    public void addGeofences(List<GeofenceModel> geofences, Callback callback) {
        if (geofences == null || geofences.isEmpty()) {
            if (callback != null) {
                callback.onFailure("No geofences provided");
            }
            return;
        }
        
        // Validate all geofences
        for (GeofenceModel geofence : geofences) {
            if (!geofence.validate()) {
                IllegalArgumentException error = geofence.getValidationError();
                if (callback != null) {
                    callback.onFailure("Geofence validation failed for '" + 
                        geofence.getIdentifier() + "': " + 
                        (error != null ? error.getMessage() : "Unknown error"));
                }
                return;
            }
        }
        
        // Save to database
        for (GeofenceModel geofence : geofences) {
            geofenceDatabase.persist(geofence);
        }
        geofenceCount.set(geofenceDatabase.count());
        
        // Register with Google Play Services
        registerGeofences(geofences, callback);
    }
    
    /**
     * Remove geofence
     * remove()
     */
    public void removeGeofence(String identifier, Callback callback) {
        List<String> identifiers = new ArrayList<>();
        identifiers.add(identifier);
        removeGeofences(identifiers, callback);
    }
    
    /**
     * Remove multiple geofences
     * remove()
     */
    public void removeGeofences(List<String> identifiers, Callback callback) {
        List<String> identifiersToRemove = identifiers;
        if (identifiersToRemove == null || identifiersToRemove.isEmpty()) {
            // Remove all
            identifiersToRemove = geofenceDatabase.getAllIdentifiers();
        }
        
        final List<String> finalIdentifiers = identifiersToRemove;
        
        if (finalIdentifiers.isEmpty()) {
            if (callback != null) {
                callback.onSuccess();
            }
            return;
        }
        
        // Remove from Google Play Services
        geofencingClient.removeGeofences(finalIdentifiers)
            .addOnSuccessListener(new OnSuccessListener<Void>() {
                @Override
                public void onSuccess(Void aVoid) {
                    // Remove from database
                    for (String identifier : finalIdentifiers) {
                        geofenceDatabase.delete(identifier);
                    }
                    geofenceCount.set(geofenceDatabase.count());
                    
                    LogHelper.d(TAG, "✅ Geofences removed: " + finalIdentifiers.size());
                    
                    if (callback != null) {
                        callback.onSuccess();
                    }
                }
            })
            .addOnFailureListener(new OnFailureListener() {
                @Override
                public void onFailure(Exception e) {
                    LogHelper.e(TAG, "Failed to remove geofences: " + e.getMessage(), e);
                    if (callback != null) {
                        callback.onFailure(e.getMessage());
                    }
                }
            });
    }
    
    /**
     * Remove all geofences
     */
    public void removeAllGeofences(Callback callback) {
        removeGeofences(null, callback);
    }
    
    /**
     * Get all geofences
     */
    public List<GeofenceModel> getGeofences() {
        return geofenceDatabase.all();
    }
    
    /**
     * Get geofence by identifier
     */
    public GeofenceModel getGeofence(String identifier) {
        return geofenceDatabase.find(identifier);
    }
    
    /**
     * Check if geofence exists
     */
    public boolean geofenceExists(String identifier) {
        return geofenceDatabase.exists(identifier);
    }
    
    /**
     * Get geofence count
     */
    public int getGeofenceCount() {
        return geofenceCount.get();
    }
    
    /**
     * Check if has geofences
     */
    public boolean hasGeofences() {
        return geofenceCount.get() > 0;
    }
    
    /**
     * Start monitoring geofences
     */
    public void startMonitoring() {
        if (isMonitoring.get()) {
            return;
        }
        
        isMonitoring.set(true);
        
        // Load all geofences and register
        List<GeofenceModel> geofences = geofenceDatabase.all();
        if (!geofences.isEmpty()) {
            registerGeofences(geofences, null);
        }
        
        LogHelper.d(TAG, "✅ Geofence monitoring started");
    }
    
    /**
     * Stop monitoring geofences
     */
    public void stopMonitoring() {
        if (!isMonitoring.get()) {
            return;
        }
        
        isMonitoring.set(false);
        
        // Remove all geofences from Google Play Services
        List<String> identifiers = geofenceDatabase.getAllIdentifiers();
        if (!identifiers.isEmpty()) {
            geofencingClient.removeGeofences(identifiers);
        }
        
        LogHelper.d(TAG, "✅ Geofence monitoring stopped");
    }
    
    /**
     * Register geofence with Google Play Services
     */
    private void registerGeofence(GeofenceModel geofenceModel, Callback callback) {
        try {
            Geofence geofence = geofenceModel.buildGeofence();
            
            GeofencingRequest request = new GeofencingRequest.Builder()
                    .addGeofence(geofence)
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                    .build();
            
            geofencingClient.addGeofences(request, getPendingIntent())
                .addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        LogHelper.d(TAG, "✅ Geofence registered: " + geofenceModel.getIdentifier());
                        if (callback != null) {
                            callback.onSuccess();
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(Exception e) {
                        LogHelper.e(TAG, "Failed to register geofence: " + e.getMessage(), e);
                        // Remove from database on failure
                        geofenceDatabase.delete(geofenceModel.getIdentifier());
                        geofenceCount.set(geofenceDatabase.count());
                        
                        if (callback != null) {
                            callback.onFailure(e.getMessage());
                        }
                    }
                });
        } catch (IllegalArgumentException e) {
            LogHelper.e(TAG, "Invalid geofence: " + e.getMessage(), e);
            geofenceDatabase.delete(geofenceModel.getIdentifier());
            geofenceCount.set(geofenceDatabase.count());
            
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Register multiple geofences with Google Play Services
     */
    private void registerGeofences(List<GeofenceModel> geofenceModels, Callback callback) {
        if (geofenceModels.isEmpty()) {
            if (callback != null) {
                callback.onSuccess();
            }
            return;
        }
        
        try {
            List<Geofence> geofences = new ArrayList<>();
            for (GeofenceModel model : geofenceModels) {
                try {
                    Geofence geofence = model.buildGeofence();
                    geofences.add(geofence);
                } catch (IllegalArgumentException e) {
                    LogHelper.e(TAG, "Invalid geofence '" + model.getIdentifier() + "': " + e.getMessage());
                    // Remove invalid geofence from database
                    geofenceDatabase.delete(model.getIdentifier());
                }
            }
            
            if (geofences.isEmpty()) {
                geofenceCount.set(geofenceDatabase.count());
                if (callback != null) {
                    callback.onFailure("No valid geofences to register");
                }
                return;
            }
            
            GeofencingRequest request = new GeofencingRequest.Builder()
                    .addGeofences(geofences)
                    .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                    .build();
            
            geofencingClient.addGeofences(request, getPendingIntent())
                .addOnSuccessListener(new OnSuccessListener<Void>() {
                    @Override
                    public void onSuccess(Void aVoid) {
                        LogHelper.d(TAG, "✅ Geofences registered: " + geofences.size());
                        geofenceCount.set(geofenceDatabase.count());
                        if (callback != null) {
                            callback.onSuccess();
                        }
                    }
                })
                .addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(Exception e) {
                        LogHelper.e(TAG, "Failed to register geofences: " + e.getMessage(), e);
                        // Remove from database on failure
                        for (GeofenceModel model : geofenceModels) {
                            geofenceDatabase.delete(model.getIdentifier());
                        }
                        geofenceCount.set(geofenceDatabase.count());
                        
                        if (callback != null) {
                            callback.onFailure(e.getMessage());
                        }
                    }
                });
        } catch (Exception e) {
            LogHelper.e(TAG, "Error registering geofences: " + e.getMessage(), e);
            if (callback != null) {
                callback.onFailure(e.getMessage());
            }
        }
    }
    
    /**
     * Get PendingIntent for geofence events
     */
    private android.app.PendingIntent getPendingIntent() {
        return com.backgroundlocation.receiver.GeofenceBroadcastReceiver.getPendingIntent(context);
    }
    
    /**
     * Evaluate geofences (check if location is inside any geofence)
     * For polygon geofences
     */
    public void evaluate(Location location) {
        if (location == null) {
            return;
        }
        
        lastLocation = location;
        
        // Check polygon geofences
        List<GeofenceModel> geofences = geofenceDatabase.all();
        for (GeofenceModel geofence : geofences) {
            if (geofence.isPolygon()) {
                boolean isInside = GeofenceModel.isLocationInPolygon(
                    geofence.getVertices(),
                    location.getLatitude(),
                    location.getLongitude()
                );
                
                // TODO: Track state and emit events
                LogHelper.d(TAG, "Polygon geofence '" + geofence.getIdentifier() + 
                    "': " + (isInside ? "INSIDE" : "OUTSIDE"));
            }
        }
    }
    
    /**
     * Set last location
     */
    public void setLocation(Location location) {
        this.lastLocation = location;
        if (location != null) {
            evaluate(location);
        }
    }
    
    /**
     * Get last location
     */
    public Location getLastLocation() {
        return lastLocation;
    }
}

