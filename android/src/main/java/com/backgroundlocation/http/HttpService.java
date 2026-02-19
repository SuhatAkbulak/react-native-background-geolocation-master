package com.backgroundlocation.http;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.net.NetworkRequest;
import android.os.Build;
import android.os.Bundle;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.adapter.callback.AuthorizationCallback;
import com.backgroundlocation.adapter.callback.SyncCallback;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.AuthorizationEvent;
import com.backgroundlocation.event.ConfigChangeEvent;
import com.backgroundlocation.event.ConnectivityChangeEvent;
import com.backgroundlocation.lifecycle.LifecycleManager;
import com.backgroundlocation.util.LogHelper;
import okhttp3.OkHttpClient;
import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * HttpService
 * HttpService
 * HTTP service yönetimi - OkHttpClient, connectivity monitoring, authorization
 */
public class HttpService {
    
    private static final String TAG = "HttpService";
    private static HttpService instance = null;
    
    private final Context context;
    private final OkHttpClient client;
    private final List<AuthorizationCallback> authorizationCallbacks = new ArrayList<>();
    private final AtomicBoolean isBusy = new AtomicBoolean(false);
    
    private BroadcastReceiver connectivityReceiver;
    private ConnectivityManager.NetworkCallback networkCallback;
    
    private HttpService(Context context) {
        this.context = context.getApplicationContext();
        Config config = Config.getInstance(this.context);
        
        // Create OkHttpClient with timeout
        int timeout = 60000; // Default 60 seconds
        this.client = new OkHttpClient.Builder()
            .followRedirects(false) // Don't follow redirects
            .callTimeout(timeout, TimeUnit.MILLISECONDS)
            .connectTimeout(timeout, TimeUnit.MILLISECONDS)
            .readTimeout(timeout, TimeUnit.MILLISECONDS)
            .writeTimeout(timeout, TimeUnit.MILLISECONDS)
            .build();
        
        // Register EventBus
        if (!EventBus.getDefault().isRegistered(this)) {
            EventBus.getDefault().register(this);
        }
        
        // Start monitoring if enabled
        if (config.enabled) {
            startMonitoringConnectivityChanges(this.context);
        }
        
        LogHelper.d(TAG, "HttpService initialized");
    }
    
    private static synchronized HttpService getInstanceInternal(Context context) {
        if (instance == null) {
            instance = new HttpService(context.getApplicationContext());
        }
        return instance;
    }
    
    public static HttpService getInstance(Context context) {
        if (instance == null) {
            instance = getInstanceInternal(context.getApplicationContext());
        }
        return instance;
    }
    
    /**
     * Get OkHttpClient instance
     */
    public OkHttpClient getClient() {
        return client;
    }
    
    /**
     * Check if service is busy
     */
    public boolean isBusy() {
        return isBusy.get();
    }
    
    /**
     * Set busy state
     */
    public void setBusy(boolean busy) {
        isBusy.set(busy);
    }
    
    /**
     * Check if network is available
     */
    public boolean isNetworkAvailable() {
        ConnectivityManager connectivityManager = (ConnectivityManager) 
            context.getSystemService(Context.CONNECTIVITY_SERVICE);
        if (connectivityManager == null) {
            return false;
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Network network = connectivityManager.getActiveNetwork();
            if (network == null) {
                return false;
            }
            NetworkCapabilities capabilities = connectivityManager.getNetworkCapabilities(network);
            return capabilities != null && 
                   (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET));
        } else {
            NetworkInfo activeNetworkInfo = connectivityManager.getActiveNetworkInfo();
            return activeNetworkInfo != null && activeNetworkInfo.isConnected();
        }
    }
    
    /**
     * Check if connected via mobile
     */
    public boolean isConnectedMobile() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ConnectivityManager connectivityManager = (ConnectivityManager) 
                context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                return false;
            }
            Network network = connectivityManager.getActiveNetwork();
            if (network == null) {
                return false;
            }
            NetworkCapabilities capabilities = connectivityManager.getNetworkCapabilities(network);
            return capabilities != null && 
                   capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR);
        }
        return false;
    }
    
    /**
     * Check if connected via WiFi
     */
    public boolean isConnectedWifi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ConnectivityManager connectivityManager = (ConnectivityManager) 
                context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                return false;
            }
            Network network = connectivityManager.getActiveNetwork();
            if (network == null) {
                return false;
            }
            NetworkCapabilities capabilities = connectivityManager.getNetworkCapabilities(network);
            return capabilities != null && 
                   capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI);
        }
        return false;
    }
    
    /**
     * Start monitoring connectivity changes
     */
    public void startMonitoringConnectivityChanges(Context context) {
        if (!isNetworkAvailable()) {
            EventBus.getDefault().post(new ConnectivityChangeEvent(false));
        }
        
        LogHelper.d(TAG, "Start monitoring connectivity changes");
        
        if (networkCallback == null && connectivityReceiver == null) {
            ConnectivityManager connectivityManager = (ConnectivityManager) 
                context.getSystemService(Context.CONNECTIVITY_SERVICE);
            
            if (connectivityManager != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Use NetworkCallback for Android 7.0+
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
                    connectivityManager.registerNetworkCallback(request, networkCallback);
                } else {
                    // Use BroadcastReceiver for older Android versions
                    connectivityReceiver = new BroadcastReceiver() {
                        @Override
                        public void onReceive(Context context, Intent intent) {
                            Bundle extras = intent.getExtras();
                            boolean isConnected = extras != null && 
                                !extras.containsKey("noConnectivity");
                            handleConnectivityChange(isConnected);
                        }
                    };
                    IntentFilter filter = new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION);
                    context.registerReceiver(connectivityReceiver, filter);
                }
            }
        }
    }
    
    /**
     * Stop monitoring connectivity changes
     */
    public void stopMonitoringConnectivityChanges(Context context) {
        LogHelper.d(TAG, "Stop monitoring connectivity changes");
        
        ConnectivityManager connectivityManager = (ConnectivityManager) 
            context.getSystemService(Context.CONNECTIVITY_SERVICE);
        
        if (networkCallback != null && connectivityManager != null) {
            try {
                connectivityManager.unregisterNetworkCallback(networkCallback);
            } catch (IllegalArgumentException e) {
                LogHelper.w(TAG, "Error unregistering network callback: " + e.getMessage());
            }
            networkCallback = null;
        }
        
        if (connectivityReceiver != null) {
            try {
                context.unregisterReceiver(connectivityReceiver);
            } catch (IllegalArgumentException e) {
                LogHelper.w(TAG, "Error unregistering connectivity receiver: " + e.getMessage());
            }
            connectivityReceiver = null;
        }
    }
    
    /**
     * Handle connectivity change
     */
    private void handleConnectivityChange(boolean isConnected) {
        EventBus.getDefault().post(new ConnectivityChangeEvent(isConnected));
        LogHelper.d(TAG, "Connectivity changed: " + (isConnected ? "CONNECTED" : "DISCONNECTED"));
    }
    
    /**
     * Add authorization callback
     */
    public void onAuthorization(AuthorizationCallback callback) {
        synchronized (authorizationCallbacks) {
            authorizationCallbacks.add(callback);
        }
    }
    
    /**
     * Remove authorization callback
     */
    public void removeAuthorizationCallback(AuthorizationCallback callback) {
        synchronized (authorizationCallbacks) {
            authorizationCallbacks.remove(callback);
        }
    }
    
    /**
     * Remove all authorization callbacks
     */
    public void removeAllAuthorizationCallbacks() {
        synchronized (authorizationCallbacks) {
            authorizationCallbacks.clear();
        }
    }
    
    /**
     * Fire authorization event
     */
    public void fireAuthorizationEvent(AuthorizationEvent event) {
        if (LifecycleManager.getInstance().isHeadless()) {
            // Headless mode - post to EventBus
            EventBus.getDefault().post(event);
            return;
        }
        
        synchronized (authorizationCallbacks) {
            for (AuthorizationCallback callback : authorizationCallbacks) {
                try {
                    callback.onResponse(event);
                } catch (Exception e) {
                    LogHelper.e(TAG, "Error in authorization callback: " + e.getMessage(), e);
                }
            }
        }
    }
    
    /**
     * Flush locations (sync)
     */
    public void flush(SyncCallback callback) {
        if (!isNetworkAvailable()) {
            if (callback != null) {
                BackgroundLocationAdapter.getUiHandler().post(() -> 
                    callback.onFailure("HTTP_SERVICE_NO_CONNECTION"));
            }
            return;
        }
        
        if (isBusy.get()) {
            LogHelper.i(TAG, "HttpService is busy");
            if (callback != null) {
                BackgroundLocationAdapter.getUiHandler().post(() -> 
                    callback.onFailure("HTTP_SERVICE_BUSY"));
            }
            return;
        }
        
        // Use SyncService to sync
        com.backgroundlocation.service.SyncService.sync(context);
        
        // TODO: Implement callback support in SyncService
        if (callback != null) {
            LogHelper.w(TAG, "SyncCallback not fully implemented in SyncService yet");
        }
    }
    
    /**
     * Handle config change event
     */
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onConfigChange(ConfigChangeEvent event) {
        Config config = Config.getInstance(context);
        
        if ((event.isDirty("autoSync") || event.isDirty("url") || 
             event.isDirty("params") || event.isDirty("extras") || 
             event.isDirty("headers")) && 
            !config.url.isEmpty() && config.autoSync && isNetworkAvailable()) {
            // Trigger sync if config changed
            BackgroundLocationAdapter.getThreadPool().execute(() -> {
                flush(null);
            });
        }
    }
    
    /**
     * Destroy service
     */
    public void destroy() {
        EventBus eventBus = EventBus.getDefault();
        if (eventBus.isRegistered(this)) {
            eventBus.unregister(this);
        }
        
        stopMonitoringConnectivityChanges(context);
        removeAllAuthorizationCallbacks();
        
        LogHelper.d(TAG, "HttpService destroyed");
    }
}

