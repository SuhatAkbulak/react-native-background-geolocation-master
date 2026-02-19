package com.backgroundlocation.util;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.core.content.ContextCompat;

/**
 * LocationAuthorization
 * LocationAuthorization.java
 * Location permission yönetimi
 */
public class LocationAuthorization {
    
    /**
     * Check if app has location permission (fine or coarse)
     */
    public static boolean hasPermission(Context context) {
        return ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
               ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
    }
    
    /**
     * Check if app has background location permission (Android 10+)
     */
    public static boolean hasBackgroundPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED;
        }
        // Android 9 and below: background permission is granted if location permission is granted
        return hasPermission(context);
    }
    
    /**
     * Check if app has activity recognition permission
     */
    public static boolean hasActivityPermission(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(context, android.Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED;
        }
        // Android 9 and below: activity recognition permission is not required
        return true;
    }
}

