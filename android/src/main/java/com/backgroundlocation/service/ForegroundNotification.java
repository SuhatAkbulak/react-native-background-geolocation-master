package com.backgroundlocation.service;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.media.AudioAttributes;
import android.net.Uri;
import android.os.Build;
import androidx.core.app.NotificationCompat;
import com.backgroundlocation.Constants;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.service.AbstractService;
import com.backgroundlocation.util.LogHelper;

import java.util.Map;
import java.util.concurrent.atomic.AtomicLong;

/**
 * ForegroundNotification
 * Foreground service notification yönetimi
 */
public class ForegroundNotification {
    
    public static final String NOTIFICATION_ACTION = Constants.ACTION_NOTIFICATION_ACTION;
    public static final int NOTIFICATION_ID = 9942585;
    private static final String DEFAULT_LAYOUT = "default";
    private static final String NOTIFICATION_BUTTON_PAUSE = "notificationButtonPause";
    private static final AtomicLong notificationTime = new AtomicLong(0);
    
    /**
     * Set notification time
     */
    static void setNotificationTime(long time) {
        notificationTime.set(time);
    }
    
    /**
     * Build notification
     */
    public static Notification build(Context context) {
        NotificationCompat.Builder builder = buildBaseNotification(context);
        builder.setOnlyAlertOnce(true);
        builder.setSound((Uri) null);
        
        if (notificationTime.get() > 0) {
            builder.setWhen(notificationTime.get());
        }
        
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            builder.setPriority(getPriorityFromConfig(config.priority));
            applyNotificationConfig(context, builder, config);
        } else {
            applyDefaultNotification(context, builder);
        }
        
        Notification notification = builder.build();
        notification.flags |= Notification.FLAG_ONGOING_EVENT | Notification.FLAG_NO_CLEAR;
        return notification;
    }
    
    /**
     * Build base notification
     */
    private static NotificationCompat.Builder buildBaseNotification(Context context) {
        String channelId = getChannelId(context);
        createNotificationChannel(context, false);
        return new NotificationCompat.Builder(context, channelId);
    }
    
    /**
     * Apply notification config
     */
    private static void applyNotificationConfig(Context context, NotificationCompat.Builder builder, Config config) {
        ApplicationInfo appInfo = context.getApplicationInfo();
        
        // Orijinal Transistorsoft field isimleri (title, text, color, smallIcon, largeIcon, priority)
        String title = config.title;
        if (title == null || title.isEmpty()) {
            int labelRes = appInfo.labelRes;
            title = labelRes == 0 ? appInfo.nonLocalizedLabel.toString() : context.getString(labelRes);
        }
        
        builder.setContentTitle(title);
        builder.setContentText(config.text);
        builder.setStyle(new NotificationCompat.BigTextStyle().bigText(config.text));
        builder.setSmallIcon(android.R.drawable.ic_menu_mylocation);
        
        // Set color
        if (config.color != null && !config.color.isEmpty()) {
            try {
                builder.setColor(Color.parseColor(config.color));
            } catch (Exception e) {
                LogHelper.w("ForegroundNotification", "Invalid color: " + config.color);
            }
        }
        
        // Set large icon if available
        // TODO: Implement large icon support
    }
    
    /**
     * Apply default notification
     */
    private static void applyDefaultNotification(Context context, NotificationCompat.Builder builder) {
        ApplicationInfo appInfo = context.getApplicationInfo();
        int labelRes = appInfo.labelRes;
        String title = labelRes == 0 ? appInfo.nonLocalizedLabel.toString() : context.getString(labelRes);
        builder.setContentTitle(title);
        builder.setSmallIcon(android.R.drawable.ic_menu_mylocation);
    }
    
    /**
     * Create notification channel
     */
    public static void createNotificationChannel(Context context, boolean force) {
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (notificationManager == null) {
            return;
        }
        
        String channelId = getChannelId(context);
        String channelName = getChannelName(context);
        
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            // Orijinal Transistorsoft field isimleri (channelName, channelId)
            if (config.channelName != null && !config.channelName.isEmpty()) {
                channelName = config.channelName;
            }
            if (config.channelId != null && !config.channelId.isEmpty()) {
                channelId = config.channelId;
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = notificationManager.getNotificationChannel(channelId);
            if (channel == null || force) {
                // IMPORTANCE_DEFAULT (1) kullan - bu notification'ın görünür olmasını sağlar
                channel = new NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_DEFAULT);
                channel.setShowBadge(false);
                channel.enableLights(false);
                channel.setSound((Uri) null, (AudioAttributes) null);
                channel.enableVibration(false);
                // VISIBILITY_SECRET (-1) - lockscreen'de gizli
                // Ama notification görünür olacak çünkü IMPORTANCE_DEFAULT
                channel.setLockscreenVisibility(Notification.VISIBILITY_SECRET);
                notificationManager.createNotificationChannel(channel);
            }
        }
    }
    
    /**
     * Get channel ID
     */
    private static String getChannelId(Context context) {
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            // Orijinal Transistorsoft field isimleri (channelId)
            if (config.channelId != null && !config.channelId.isEmpty()) {
                return config.channelId;
            }
        }
        return context.getPackageName() + "TSLocationManager";
    }
    
    /**
     * Get channel name
     */
    private static String getChannelName(Context context) {
        if (Config.isLoaded()) {
            Config config = Config.getInstance(context);
            // Orijinal Transistorsoft field isimleri (channelName)
            if (config.channelName != null && !config.channelName.isEmpty()) {
                return config.channelName;
            }
        }
        
        ApplicationInfo appInfo = context.getApplicationInfo();
        if (appInfo.labelRes != 0) {
            return context.getString(appInfo.labelRes);
        }
        return "TSLocationManager";
    }
    
    /**
     * Get priority from config
     */
    private static int getPriorityFromConfig(int priority) {
        switch (priority) {
            case -2: return NotificationCompat.PRIORITY_MIN;
            case -1: return NotificationCompat.PRIORITY_LOW;
            case 0: return NotificationCompat.PRIORITY_DEFAULT;
            case 1: return NotificationCompat.PRIORITY_HIGH;
            case 2: return NotificationCompat.PRIORITY_MAX;
            default: return NotificationCompat.PRIORITY_DEFAULT;
        }
    }
    
    /**
     * Update channel ID
     */
    public static void onUpdateChannelId(Context context) {
        NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        createNotificationChannel(context, false);
        
        if (AbstractService.isAnyServiceActive()) {
            notificationManager.notify(NOTIFICATION_ID, build(context));
        }
    }
    
    /**
     * Update channel name
     */
    public static void onUpdateChannelName(Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager notificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            Config config = Config.getInstance(context);
            // Orijinal Transistorsoft field isimleri (channelId, channelName)
            String channelId = config.channelId != null && !config.channelId.isEmpty() 
                ? config.channelId 
                : getChannelId(context);
            
            NotificationChannel channel = notificationManager.getNotificationChannel(channelId);
            if (channel != null) {
                String channelName = config.channelName != null && !config.channelName.isEmpty()
                    ? config.channelName
                    : getChannelName(context);
                channel.setName(channelName);
            }
        }
    }
}

