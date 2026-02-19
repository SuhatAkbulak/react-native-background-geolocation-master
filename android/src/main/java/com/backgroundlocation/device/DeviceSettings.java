package com.backgroundlocation.device;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.PowerManager;
import android.provider.Settings;
import com.backgroundlocation.event.PowerSaveModeChangeEvent;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.EventBus;

/**
 * DeviceSettings
 * DeviceSettings
 * Cihaz ayarları yönetimi - Battery optimization, Power save mode vb.
 */
public class DeviceSettings {
    
    public static final String IGNORE_BATTERY_OPTIMIZATION = "IGNORE_BATTERY_OPTIMIZATIONS";
    public static final String POWER_MANAGER = "POWER_MANAGER";
    private static final String TAG = "DeviceSettings";
    
    private static final String HUAWEI_POWER_MODE_CHANGED_ACTION = "huawei.intent.action.POWER_MODE_CHANGED_ACTION";
    private static final String HUAWEI_SMART_MODE_STATUS = "SmartModeStatus";
    private static final int HUAWEI_POWER_SAVE_MODE = 4;
    
    private static DeviceSettings instance = null;
    private BroadcastReceiver powerSaveReceiver;
    
    // Manufacturer-specific auto-start intents
    private static final Intent[] AUTO_START_INTENTS = {
        // Xiaomi
        new Intent().setComponent(new ComponentName("com.miui.securitycenter", 
            "com.miui.permcenter.autostart.AutoStartManagementActivity")),
        // LeTV
        new Intent().setComponent(new ComponentName("com.letv.android.letvsafe", 
            "com.letv.android.letvsafe.AutobootManageActivity")),
        // Huawei
        new Intent().setComponent(new ComponentName("com.huawei.systemmanager", 
            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
        // OPPO/ColorOS
        new Intent().setComponent(new ComponentName("com.coloros.safecenter", 
            "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
        // Vivo
        new Intent().setComponent(new ComponentName("com.vivo.permissionmanager", 
            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
        // Samsung
        new Intent().setComponent(new ComponentName("com.samsung.android.lool", 
            "com.samsung.android.sm.battery.ui.BatteryActivity")),
    };
    
    private DeviceSettings() {
    }
    
    private static synchronized DeviceSettings getInstanceInternal() {
        if (instance == null) {
            instance = new DeviceSettings();
        }
        return instance;
    }
    
    public static DeviceSettings getInstance() {
        if (instance == null) {
            instance = getInstanceInternal();
        }
        return instance;
    }
    
    /**
     * Get intent for device settings
     */
    public Intent getIntent(Context context, String action) {
        Intent intent = null;
        
        if (action.equalsIgnoreCase(IGNORE_BATTERY_OPTIMIZATION)) {
            intent = getBatteryOptimizationIntent(context);
        } else if (action.equalsIgnoreCase(POWER_MANAGER)) {
            intent = getPowerManagerIntent(context);
        }
        
        if (intent == null || context.getPackageManager().resolveActivity(intent, 
                PackageManager.MATCH_DEFAULT_ONLY) == null) {
            return null;
        }
        
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return intent;
    }
    
    /**
     * Get battery optimization intent
     */
    private Intent getBatteryOptimizationIntent(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Intent intent = new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS);
            return intent;
        }
        return null;
    }
    
    /**
     * Get power manager intent
     */
    private Intent getPowerManagerIntent(Context context) {
        Intent intent = new Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS);
        return intent;
    }
    
    /**
     * Check if battery optimization is ignored
     */
    public boolean isIgnoringBatteryOptimizations(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                return powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
            }
        }
        return false;
    }
    
    /**
     * Check if power save mode is enabled
     */
    public boolean isPowerSaveMode(Context context) {
        if (DeviceInfo.MANUFACTURER_HUAWEI.equalsIgnoreCase(Build.MANUFACTURER)) {
            return isHuaweiPowerSaveMode(context);
        }
        
        PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        if (powerManager != null) {
            return powerManager.isPowerSaveMode();
        }
        return false;
    }
    
    /**
     * Check Huawei power save mode
     */
    private boolean isHuaweiPowerSaveMode(Context context) {
        LogHelper.i(TAG, "[isPowerSaveMode] " + DeviceInfo.MANUFACTURER_HUAWEI + " detected");
        try {
            int smartModeStatus = Settings.System.getInt(context.getContentResolver(), HUAWEI_SMART_MODE_STATUS);
            return smartModeStatus == HUAWEI_POWER_SAVE_MODE;
        } catch (Settings.SettingNotFoundException e) {
            LogHelper.w(TAG, DeviceInfo.MANUFACTURER_HUAWEI + " System setting '" + HUAWEI_SMART_MODE_STATUS + "' not found");
            return isStandardPowerSaveMode(context);
        }
    }
    
    /**
     * Check standard power save mode
     */
    private boolean isStandardPowerSaveMode(Context context) {
        PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
        if (powerManager != null) {
            return powerManager.isPowerSaveMode();
        }
        return false;
    }
    
    /**
     * Start monitoring power save mode changes
     */
    public void startMonitoringPowerSaveMode(Context context) {
        if (powerSaveReceiver != null) {
            return; // Already monitoring
        }
        
        powerSaveReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                boolean isPowerSaveMode = false;
                
                if (intent.getAction() != null && 
                    intent.getAction().equals(HUAWEI_POWER_MODE_CHANGED_ACTION)) {
                    Bundle extras = intent.getExtras();
                    LogHelper.d(TAG, DeviceInfo.MANUFACTURER_HUAWEI + " detected: " + intent);
                    
                    if (extras != null && extras.containsKey("state")) {
                        for (String key : extras.keySet()) {
                            LogHelper.d(TAG, "[extras] " + key + ": " + extras.get(key));
                        }
                        if (extras.getInt("state") == 1) {
                            isPowerSaveMode = true;
                        }
                    }
                } else {
                    PowerManager powerManager = (PowerManager) context.getSystemService(Context.POWER_SERVICE);
                    if (powerManager != null) {
                        isPowerSaveMode = powerManager.isPowerSaveMode();
                    }
                }
                
                LogHelper.i(TAG, isPowerSaveMode ? "PowerSaveMode ON" : "PowerSaveMode OFF");
                EventBus.getDefault().post(new PowerSaveModeChangeEvent(isPowerSaveMode));
            }
        };
        
        IntentFilter filter = new IntentFilter();
        filter.addAction("android.os.action.POWER_SAVE_MODE_CHANGED");
        if (DeviceInfo.MANUFACTURER_HUAWEI.equalsIgnoreCase(Build.MANUFACTURER)) {
            filter.addAction(HUAWEI_POWER_MODE_CHANGED_ACTION);
        }
        
        context.registerReceiver(powerSaveReceiver, filter);
        LogHelper.d(TAG, "Started monitoring power save mode changes");
    }
    
    /**
     * Stop monitoring power save mode changes
     */
    public void stopMonitoringPowerSaveMode(Context context) {
        if (powerSaveReceiver != null) {
            try {
                context.unregisterReceiver(powerSaveReceiver);
                powerSaveReceiver = null;
                LogHelper.d(TAG, "Stopped monitoring power save mode changes");
            } catch (Exception e) {
                LogHelper.e(TAG, "Error unregistering power save receiver: " + e.getMessage(), e);
            }
        }
    }
    
    /**
     * Get auto-start intent for manufacturer
     */
    public Intent getAutoStartIntent(Context context) {
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        
        for (Intent intent : AUTO_START_INTENTS) {
            ComponentName component = intent.getComponent();
            if (component != null) {
                try {
                    context.getPackageManager().getPackageInfo(component.getPackageName(), 0);
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    return intent;
                } catch (PackageManager.NameNotFoundException e) {
                    // Package not found, try next
                }
            }
        }
        
        return null;
    }
}

