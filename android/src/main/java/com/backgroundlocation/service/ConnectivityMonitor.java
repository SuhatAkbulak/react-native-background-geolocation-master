package com.backgroundlocation.service;

import android.content.Context;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.util.Log;

import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.ConnectivityChangeEvent;

import org.greenrobot.eventbus.EventBus;

/**
 * Connectivity Monitor
 * Network monitoring
 * Online olunca otomatik sync başlatır
 */
public class ConnectivityMonitor {
    
    private static final String TAG = "ConnectivityMonitor";
    private static ConnectivityMonitor instance;
    
    private Context context;
    private ConnectivityManager connectivityManager;
    private ConnectivityManager.NetworkCallback networkCallback;
    private boolean isMonitoring = false;
    
    private ConnectivityMonitor(Context context) {
        this.context = context.getApplicationContext();
        this.connectivityManager = (ConnectivityManager) 
            context.getSystemService(Context.CONNECTIVITY_SERVICE);
    }
    
    public static synchronized ConnectivityMonitor getInstance(Context context) {
        if (instance == null) {
            instance = new ConnectivityMonitor(context);
        }
        return instance;
    }
    
    /**
     * Start monitoring connectivity changes
     * 
     */
    public void startMonitoring() {
        if (isMonitoring) {
            Log.d(TAG, "Already monitoring connectivity");
            return;
        }
        
        if (!isNetworkAvailable()) {
            // Emit offline event
            emitConnectivityEvent(false);
        }
        
        Log.d(TAG, "📶 Start monitoring connectivity changes");
        
        if (networkCallback == null && connectivityManager != null) {
            NetworkRequest request = new NetworkRequest.Builder().build();
            
            networkCallback = new ConnectivityManager.NetworkCallback() {
                @Override
                public void onAvailable(Network network) {
                    super.onAvailable(network);
                    handleConnectivityChange(true);
                }
                
                @Override
                public void onLost(Network network) {
                    super.onLost(network);
                    handleConnectivityChange(false);
                }
            };
            
            try {
                connectivityManager.registerNetworkCallback(request, networkCallback);
                isMonitoring = true;
                Log.d(TAG, "✅ Connectivity monitor started");
            } catch (Exception e) {
                Log.e(TAG, "Failed to register network callback: " + e.getMessage());
            }
        }
    }
    
    /**
     * Stop monitoring
     */
    public void stopMonitoring() {
        Log.d(TAG, "📵 Stop monitoring connectivity changes");
        
        if (networkCallback != null && connectivityManager != null) {
            try {
                connectivityManager.unregisterNetworkCallback(networkCallback);
                Log.d(TAG, "✅ Connectivity monitor stopped");
            } catch (IllegalArgumentException e) {
                Log.w(TAG, "Network callback already unregistered: " + e.getMessage());
            }
            networkCallback = null;
        }
        
        isMonitoring = false;
    }
    
    /**
     * Handle connectivity change ()
     */
    private void handleConnectivityChange(boolean connected) {
        boolean actuallyConnected = isNetworkAvailable();
        
        if (connected == actuallyConnected) {
            Log.d(TAG, "📶 Connectivity change: " + (actuallyConnected ? "ONLINE" : "OFFLINE"));
            
            Config config = Config.getInstance(context);
            
            // Emit event
            emitConnectivityEvent(actuallyConnected);
            
            // Trigger auto sync if online ()
            // CRITICAL: Only sync if tracking is enabled
            if (actuallyConnected && config.enabled && config.autoSync && !config.url.isEmpty()) {
                // Delay 1 second before syncing
                new android.os.Handler(android.os.Looper.getMainLooper())
                    .postDelayed(() -> {
                        Log.d(TAG, "🔄 Network available, triggering auto sync...");
                        SyncService.sync(context);
                    }, 1000);
            } else if (actuallyConnected && !config.enabled) {
                Log.d(TAG, "⏸️ Tracking not enabled, skipping sync");
            }
        }
    }
    
    /**
     * Emit connectivity event to React Native
     * direct EventBus
     */
    private void emitConnectivityEvent(boolean connected) {
        EventBus.getDefault().post(new ConnectivityChangeEvent(connected));
    }
    
    /**
     * Check if network is available
     */
    public boolean isNetworkAvailable() {
        if (connectivityManager == null) return false;
        
        try {
            android.net.NetworkInfo activeNetwork = connectivityManager.getActiveNetworkInfo();
            return activeNetwork != null && activeNetwork.isConnected();
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Check if connected via WiFi
     */
    public boolean isConnectedWifi() {
        if (connectivityManager == null) return false;
        
        try {
            NetworkCapabilities capabilities = connectivityManager
                .getNetworkCapabilities(connectivityManager.getActiveNetwork());
            
            return capabilities != null && 
                   capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI);
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Check if connected via mobile
     */
    public boolean isConnectedMobile() {
        if (connectivityManager == null) return false;
        
        try {
            NetworkCapabilities capabilities = connectivityManager
                .getNetworkCapabilities(connectivityManager.getActiveNetwork());
            
            return capabilities != null && 
                   capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR);
        } catch (Exception e) {
            return false;
        }
    }
}

