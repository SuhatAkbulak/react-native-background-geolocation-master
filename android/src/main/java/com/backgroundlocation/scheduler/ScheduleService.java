package com.backgroundlocation.scheduler;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import com.backgroundlocation.service.AbstractService;
import com.backgroundlocation.util.LogHelper;

/**
 * ScheduleService
 * ScheduleService
 * Schedule service - zamanlanmış servis
 */
public class ScheduleService extends AbstractService {
    
    /**
     * Create pending intent for schedule service
     */
    static PendingIntent createPendingIntent(Context context, Intent intent) {
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        return PendingIntent.getForegroundService(context, 0, intent, flags);
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent.hasExtra("schedule_enabled")) {
            boolean enabled = intent.getBooleanExtra("schedule_enabled", false);
            int trackingMode = intent.getIntExtra("trackingMode", 1);
            ScheduleEvent.onScheduleAlarm(getApplicationContext(), enabled, trackingMode);
        }
        
        AbstractService.stop(getApplicationContext(), ScheduleService.class);
        return START_NOT_STICKY;
    }
}

