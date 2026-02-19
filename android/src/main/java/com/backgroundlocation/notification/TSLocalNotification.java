package com.backgroundlocation.notification;

import android.app.Notification;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.logger.Log;
import com.backgroundlocation.service.ForegroundNotification;
import com.backgroundlocation.util.LogHelper;

/**
 * TSLocalNotification
 * TSLocalNotification
 * Local notification yönetimi
 */
public class TSLocalNotification {
    
    /**
     * Build notification builder
     */
    public static NotificationCompat.Builder build(Context context) {
        NotificationCompat.Builder builder;
        ForegroundNotification.createNotificationChannel(context, false);
        
        try {
            String channelId = getChannelId(context);
            if (channelId.isEmpty()) {
                channelId = context.getPackageName() + "TSLocationManager";
            }
            builder = new NotificationCompat.Builder(context, channelId);
        } catch (NoSuchMethodError e) {
            // Fallback for older Android versions
            builder = new NotificationCompat.Builder(context);
        }
        
        // Set launch intent
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent != null) {
            launchIntent.setAction(Intent.ACTION_MAIN);
            launchIntent.putExtra("TSLocationManager", true);
            launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            launchIntent.setPackage(null);
            launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | 
                                 Intent.FLAG_ACTIVITY_CLEAR_TOP | 
                                 Intent.FLAG_ACTIVITY_SINGLE_TOP);
            
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                flags |= PendingIntent.FLAG_IMMUTABLE;
            }
            
            builder.setContentIntent(PendingIntent.getActivity(context, 0, launchIntent, flags));
        } else {
            Log.logger.warn(Log.warn("Failed to find launchIntent for package: " + context.getPackageName()));
        }
        
        // Set small icon
        int smallIcon = getSmallIcon(context);
        if (smallIcon > 0) {
            builder.setSmallIcon(smallIcon);
        }
        
        builder.setOnlyAlertOnce(true);
        return builder;
    }
    
    /**
     * Get small icon
     */
    public static int getSmallIcon(Context context) {
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            
            // Check notificationIcon field
            if (config.notificationIcon != null && !config.notificationIcon.isEmpty()) {
                int iconId = context.getResources().getIdentifier(
                    config.notificationIcon, 
                    "drawable", 
                    context.getPackageName()
                );
                if (iconId > 0) {
                    return iconId;
                }
            }
        }
        
        // Fallback to application icon
        ApplicationInfo appInfo = context.getApplicationInfo();
        return appInfo.icon;
    }
    
    /**
     * Notify
     */
    public static void notify(Context context, Notification notification, int notificationId) {
        NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
        
        // Check permission for Android 13+
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (ActivityCompat.checkSelfPermission(context, 
                    android.Manifest.permission.POST_NOTIFICATIONS) == 
                    android.content.pm.PackageManager.PERMISSION_GRANTED) {
                notificationManager.notify(notificationId, notification);
            } else {
                LogHelper.w("TSLocalNotification", "POST_NOTIFICATIONS permission not granted");
            }
        } else {
            notificationManager.notify(notificationId, notification);
        }
    }
    
    /**
     * Get channel ID
     */
    private static String getChannelId(Context context) {
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            
            if (config.notificationChannelId != null && !config.notificationChannelId.isEmpty()) {
                return config.notificationChannelId;
            }
        }
        return "";
    }
}

