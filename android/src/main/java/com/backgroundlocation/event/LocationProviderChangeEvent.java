package com.backgroundlocation.event;

import android.content.Context;
import android.content.SharedPreferences;
import android.location.LocationManager;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.ContextCompat;
import androidx.core.location.LocationManagerCompat;
import com.backgroundlocation.provider.TSProviderManager;
import com.backgroundlocation.util.LogHelper;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

/**
 * LocationProviderChangeEvent
 * LocationProviderChangeEvent
 * Location provider değişiklik event
 */
public class LocationProviderChangeEvent {
    
    private static final String ACCESS_FINE_LOCATION = android.Manifest.permission.ACCESS_FINE_LOCATION;
    private static final String ACCESS_BACKGROUND_LOCATION = android.Manifest.permission.ACCESS_BACKGROUND_LOCATION;
    
    private int permission;
    private boolean gpsEnabled;
    private boolean networkEnabled;
    private int status;
    private int accuracyAuthorization;
    private boolean isAirplaneMode;
    private long timestamp;
    
    public LocationProviderChangeEvent(Context context) {
        init(context);
    }
    
    /**
     * Initialize event from context
     */
    public void init(Context context) {
        this.timestamp = System.currentTimeMillis();
        this.accuracyAuthorization = TSProviderManager.ACCURACY_AUTHORIZATION_FULL;
        
        // Check permissions
        this.permission = ContextCompat.checkSelfPermission(context, ACCESS_FINE_LOCATION);
        boolean hasPermission = hasPermission(context);
        
        // Check airplane mode
        this.isAirplaneMode = Settings.System.getInt(
            context.getContentResolver(), 
            "airplane_mode_on", 
            0
        ) != 0;
        
        // Check location providers
        WifiManager wifiManager = (WifiManager) context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        LocationManager locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        
        if (locationManager != null) {
            boolean isLocationEnabled = LocationManagerCompat.isLocationEnabled(locationManager);
            this.gpsEnabled = isLocationEnabled && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
            this.networkEnabled = isLocationEnabled && 
                                 locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) &&
                                 (wifiManager == null || wifiManager.isWifiEnabled());
        } else {
            this.gpsEnabled = false;
            this.networkEnabled = false;
        }
        
        // Set status
        this.status = 0;
        if (!hasPermission) {
            this.status = TSProviderManager.PERMISSION_DENIED;
            return;
        }
        
        this.status = hasBackgroundPermission(context) 
            ? TSProviderManager.PERMISSION_ALWAYS 
            : TSProviderManager.PERMISSION_WHEN_IN_USE;
        
        // Check accuracy authorization (Android 12+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (ContextCompat.checkSelfPermission(context, ACCESS_FINE_LOCATION) == 0) {
                this.accuracyAuthorization = TSProviderManager.ACCURACY_AUTHORIZATION_FULL;
            } else {
                this.accuracyAuthorization = TSProviderManager.ACCURACY_AUTHORIZATION_REDUCED;
            }
        }
    }
    
    /**
     * Check if permission is granted
     */
    private boolean hasPermission(Context context) {
        return ContextCompat.checkSelfPermission(context, ACCESS_FINE_LOCATION) == 
               android.content.pm.PackageManager.PERMISSION_GRANTED;
    }
    
    /**
     * Check if background permission is granted
     */
    private boolean hasBackgroundPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(context, ACCESS_BACKGROUND_LOCATION) == 
                   android.content.pm.PackageManager.PERMISSION_GRANTED;
        }
        return hasPermission(context);
    }
    
    /**
     * Update from another event
     */
    public void update(LocationProviderChangeEvent other) {
        this.permission = other.permission;
        this.gpsEnabled = other.gpsEnabled;
        this.networkEnabled = other.networkEnabled;
        this.status = other.status;
        this.accuracyAuthorization = other.accuracyAuthorization;
        this.isAirplaneMode = other.isAirplaneMode;
        this.timestamp = other.timestamp;
    }
    
    /**
     * Check if equals
     */
    public boolean equals(LocationProviderChangeEvent other) {
        if (other == null) return false;
        return other.isGPSEnabled() == this.gpsEnabled &&
               other.isNetworkEnabled() == this.networkEnabled &&
               other.isPermissionGranted() == isPermissionGranted() &&
               other.isEnabled() == isEnabled() &&
               other.getAccuracyAuthorization() == this.accuracyAuthorization &&
               other.isAirplaneMode() == this.isAirplaneMode &&
               other.getStatus() == this.status;
    }
    
    /**
     * Get elapsed time since creation
     */
    public long elapsed() {
        return System.currentTimeMillis() - this.timestamp;
    }
    
    public boolean isEnabled() {
        return gpsEnabled || networkEnabled;
    }
    
    public boolean isGPSEnabled() {
        return gpsEnabled;
    }
    
    public boolean isNetworkEnabled() {
        return networkEnabled;
    }
    
    public boolean isPermissionGranted() {
        return permission == 0;
    }
    
    public boolean isAirplaneMode() {
        return isAirplaneMode;
    }
    
    public int getPermission() {
        return permission;
    }
    
    public int getStatus() {
        return status;
    }
    
    public int getAccuracyAuthorization() {
        return accuracyAuthorization;
    }
    
    /**
     * Save to SharedPreferences
     */
    public void save(Context context) {
        SharedPreferences.Editor editor = context.getSharedPreferences(
            TSProviderManager.class.getSimpleName(), 
            Context.MODE_PRIVATE
        ).edit();
        editor.putBoolean("networkEnabled", networkEnabled);
        editor.putBoolean("gpsEnabled", gpsEnabled);
        editor.putInt("permission", permission);
        editor.putInt("accuracyAuthorization", accuracyAuthorization);
        editor.putBoolean("isAirplaneMode", isAirplaneMode);
        editor.putInt("status", status);
        editor.apply();
    }
    
    /**
     * Load from SharedPreferences
     */
    public void load(Context context) {
        init(context);
        SharedPreferences prefs = context.getSharedPreferences(
            TSProviderManager.class.getSimpleName(), 
            Context.MODE_PRIVATE
        );
        if (prefs.contains("networkEnabled")) {
            networkEnabled = prefs.getBoolean("networkEnabled", networkEnabled);
            gpsEnabled = prefs.getBoolean("gpsEnabled", gpsEnabled);
            permission = prefs.getInt("permission", permission);
            accuracyAuthorization = prefs.getInt("accuracyAuthorization", accuracyAuthorization);
            isAirplaneMode = prefs.getBoolean("isAirplaneMode", isAirplaneMode);
            status = prefs.getInt("status", status);
        }
    }
    
    /**
     * Convert to JSON
     */
    public JSONObject toJson() {
        JSONObject json = new JSONObject();
        try {
            json.put("network", networkEnabled);
            json.put("gps", gpsEnabled);
            json.put("enabled", isEnabled());
            json.put("status", status);
            json.put("accuracyAuthorization", accuracyAuthorization);
            json.put("airplane", isAirplaneMode);
        } catch (JSONException e) {
            LogHelper.e("LocationProviderChangeEvent", "Error creating JSON: " + e.getMessage(), e);
        }
        return json;
    }
    
    /**
     * Convert to Map
     */
    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("network", networkEnabled);
        map.put("gps", gpsEnabled);
        map.put("enabled", isEnabled());
        map.put("status", status);
        map.put("accuracyAuthorization", accuracyAuthorization);
        map.put("airplane", isAirplaneMode);
        return map;
    }
    
    public String getEventName() {
        return "locationproviderchange";
    }
}

