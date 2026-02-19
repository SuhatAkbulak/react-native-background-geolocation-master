package com.backgroundlocation;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.BootEvent;
import com.backgroundlocation.lifecycle.LifecycleManager;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.EventBus;

/**
 * BootReceiver
 * BootReceiver.java
 * Uygulama başlangıcında otomatik başlatma için
 */
public class BootReceiver extends BroadcastReceiver {
    
    private static final String TAG = "BootReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        // Run in background thread ()
        BackgroundLocationAdapter.getThreadPool().execute(() -> {
            handleBoot(context, intent);
        });
    }
    
    private void handleBoot(Context context, Intent intent) {
        Config config = Config.getInstance(context.getApplicationContext());
        BackgroundLocationAdapter adapter = BackgroundLocationAdapter.getInstance(context);
        String action = intent.getAction();
        
        LogHelper.i(TAG, "BootReceiver: " + context.getPackageName() + " - Action: " + action);
        
        if (action == null) {
            LogHelper.w(TAG, "BootReceiver executed with no Intent action!");
            return;
        }
        
        // Post BootEvent ()
        EventBus.getDefault().post(new BootEvent(context, intent));
        
        // Handle different boot actions
        if (action.equalsIgnoreCase(Constants.ACTION_BOOT_COMPLETED) || 
            action.equalsIgnoreCase(Constants.ACTION_LOCKED_BOOT_COMPLETED)) {
            config.didDeviceReboot = true;
            config.save();
            startServicesIfNeeded(context, config, adapter);
        } else if (action.equalsIgnoreCase(Constants.ACTION_MY_PACKAGE_REPLACED)) {
            startServicesIfNeeded(context, config, adapter);
        }
    }
    
    private void startServicesIfNeeded(Context context, Config config, BackgroundLocationAdapter adapter) {
        // Check if headless mode
        if (LifecycleManager.getInstance().isHeadless()) {
            // If stopOnTerminate is true, disable tracking
            if (config.enabled && (config.stopOnTerminate || !config.startOnBoot)) {
                config.enabled = false;
                config.save();
            }
            
            // Check stopOnTerminate
            if (config.stopOnTerminate) {
                LogHelper.w(TAG, "Plugin is configured to stopOnTerminate: true. Refusing to start BackgroundLocation on boot");
                return;
            }
            
            // Start if startOnBoot is enabled
            if (config.startOnBoot) {
                // Start scheduler if enabled
                // TODO: Implement scheduler system
                // if (config.schedulerEnabled) {
                //     adapter.startSchedule();
                // }
                
                // Start tracking if enabled
                if (config.enabled) {
                    adapter.startOnBoot();
                }
            }
        }
    }
}

