package com.backgroundlocation.provider;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.LocationProviderChangeEvent;
import com.backgroundlocation.lifecycle.LifecycleManager;
import com.backgroundlocation.location.LocationManager;
import com.backgroundlocation.logger.Log;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.EventBus;

/**
 * TSProviderManager
 * TSProviderManager
 * Location provider yönetimi - GPS, Network, Airplane Mode değişikliklerini izler
 */
public class TSProviderManager {
    
    public static final int ACCURACY_AUTHORIZATION_FULL = 0;
    public static final int ACCURACY_AUTHORIZATION_REDUCED = 1;
    public static final int PERMISSION_DENIED = 2;
    public static final int PERMISSION_ALWAYS = 3;
    public static final int PERMISSION_WHEN_IN_USE = 4;
    
    private static TSProviderManager instance;
    private BroadcastReceiver providerChangeReceiver;
    private final LocationProviderChangeEvent currentState;
    
    /**
     * Provider change receiver
     */
    private static class ProviderChangeReceiver extends BroadcastReceiver {
        private final TSProviderManager manager;
        
        ProviderChangeReceiver(TSProviderManager manager) {
            this.manager = manager;
        }
        
        @Override
        public void onReceive(Context context, Intent intent) {
            // Delay to avoid rapid-fire events
            BackgroundLocationAdapter.getUiHandler().postDelayed(() -> {
                manager.onProviderChange(context, intent);
            }, 1000);
        }
    }
    
    private TSProviderManager(Context context) {
        this.currentState = new LocationProviderChangeEvent(context);
    }
    
    /**
     * Get instance
     */
    public static TSProviderManager getInstance(Context context) {
        if (instance == null) {
            synchronized (TSProviderManager.class) {
                if (instance == null) {
                    instance = new TSProviderManager(context.getApplicationContext());
                }
            }
        }
        return instance;
    }
    
    /**
     * Start monitoring provider changes
     */
    public void startMonitoring(Context context) {
        synchronized (currentState) {
            currentState.init(context);
        }
        
        if (providerChangeReceiver == null) {
            Log.logger.info(Log.on("Start monitoring location-provider changes"));
            
            IntentFilter filter = new IntentFilter();
            filter.addAction(android.location.LocationManager.PROVIDERS_CHANGED_ACTION);
            filter.addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED);
            
            providerChangeReceiver = new ProviderChangeReceiver(this);
            context.getApplicationContext().registerReceiver(providerChangeReceiver, filter);
            
            // Post initial event if headless and enabled
            if (LifecycleManager.getInstance().isHeadless() && 
                Config.isLoaded() && 
                Config.getInstance(context).enabled) {
                EventBus.getDefault().post(new LocationProviderChangeEvent(context));
            }
        }
    }
    
    /**
     * Stop monitoring provider changes
     */
    public void stopMonitoring(Context context) {
        if (providerChangeReceiver != null) {
            try {
                context.getApplicationContext().unregisterReceiver(providerChangeReceiver);
                providerChangeReceiver = null;
                Log.logger.info(Log.off("Stop monitoring location-provider changes"));
            } catch (IllegalArgumentException e) {
                Log.logger.error(Log.error("Failed to unregister receiver: " + e.getMessage()));
            }
        }
    }
    
    /**
     * Handle provider change
     */
    private void onProviderChange(Context context, Intent intent) {
        // Throttle: ignore events within 250ms
        synchronized (currentState) {
            if (currentState.elapsed() < 250) {
                return;
            }
        }
        
        Config config = Config.getInstance(context);
        LifecycleManager lifecycleManager = LifecycleManager.getInstance();
        
        // Stop monitoring if disabled in headless mode
        if (lifecycleManager.isHeadless() && !config.enabled) {
            Log.logger.info(Log.off("Stop monitoring location-provider changes"));
            stopMonitoring(context);
            return;
        }
        
        // Create new event
        LocationProviderChangeEvent newEvent = new LocationProviderChangeEvent(context);
        
        // Check if state changed
        synchronized (currentState) {
            if (newEvent.equals(currentState)) {
                return; // No change
            }
            currentState.update(newEvent);
        }
        
        // Notify LocationManager
        LocationManager locationManager = LocationManager.getInstance(context);
        if (locationManager != null) {
            // TODO: Implement onProviderChange in LocationManager if needed
            // locationManager.onProviderChange(newEvent);
        }
        
        // Log change
        StringBuilder logMessage = new StringBuilder();
        logMessage.append(Log.header("Location-provider change: " + newEvent.isEnabled()));
        logMessage.append(Log.boxRow("GPS: " + newEvent.isGPSEnabled()));
        logMessage.append(Log.boxRow("Network: " + newEvent.isNetworkEnabled()));
        logMessage.append(Log.boxRow("AP Mode: " + newEvent.isAirplaneMode()));
        Log.logger.info(logMessage.toString());
        
        // Post event to EventBus
        EventBus.getDefault().post(newEvent);
    }
    
    /**
     * Handle connectivity change
     */
    public void onConnectivityChange(Context context, boolean isConnected) {
        LocationProviderChangeEvent newEvent = new LocationProviderChangeEvent(context);
        synchronized (currentState) {
            if (!newEvent.equals(currentState)) {
                onProviderChange(context, null);
            }
        }
    }
    
    /**
     * Get current state
     */
    public LocationProviderChangeEvent getCurrentState() {
        synchronized (currentState) {
            return currentState;
        }
    }
}

