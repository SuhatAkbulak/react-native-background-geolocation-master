package com.backgroundlocation.util;

import android.util.Log;

import com.backgroundlocation.config.Config;

/**
 * Log Helper Utility
 * Config.debug kontrolü ile log yönetimi
 * TSLog benzeri
 */
public class LogHelper {
    
    private static final String DEFAULT_TAG = "BackgroundLocation";
    
    /**
     * Debug log - sadece debug modda gözükür
     */
    public static void d(String tag, String message) {
        if (isDebugEnabled()) {
            Log.d(tag, message);
        }
    }
    
    /**
     * Info log - her zaman gözükür
     */
    public static void i(String tag, String message) {
        Log.i(tag, message);
    }
    
    /**
     * Warning log - her zaman gözükür
     */
    public static void w(String tag, String message) {
        Log.w(tag, message);
    }
    
    /**
     * Error log - her zaman gözükür
     */
    public static void e(String tag, String message) {
        Log.e(tag, message);
    }
    
    /**
     * Error log with exception - her zaman gözükür
     */
    public static void e(String tag, String message, Throwable throwable) {
        Log.e(tag, message, throwable);
    }
    
    /**
     * Debug log with default tag
     */
    public static void d(String message) {
        d(DEFAULT_TAG, message);
    }
    
    /**
     * Info log with default tag
     */
    public static void i(String message) {
        i(DEFAULT_TAG, message);
    }
    
    /**
     * Warning log with default tag
     */
    public static void w(String message) {
        w(DEFAULT_TAG, message);
    }
    
    /**
     * Error log with default tag
     */
    public static void e(String message) {
        e(DEFAULT_TAG, message);
    }
    
    /**
     * Check if debug mode is enabled
     * Default: true (her zaman göster)
     */
    private static boolean isDebugEnabled() {
        // Static method olduğu için Config instance'ına erişemiyoruz
        // Context ile kontrol edilmesi gereken yerlerde isDebugEnabled(context) kullanılmalı
        return true; // Default: debug enabled (her zaman göster)
    }
    
    /**
     * Check if debug mode is enabled with context
     */
    public static boolean isDebugEnabled(android.content.Context context) {
        if (context == null) {
            return false;
        }
        try {
            Config config = Config.getInstance(context);
            return config.debug;
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Debug log with context check
     */
    public static void d(android.content.Context context, String tag, String message) {
        if (isDebugEnabled(context)) {
            Log.d(tag, message);
        }
    }
    
    /**
     * Debug log with context check and default tag
     */
    public static void d(android.content.Context context, String message) {
        d(context, DEFAULT_TAG, message);
    }
}

