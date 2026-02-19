package com.backgroundlocation.scheduler;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.util.LogHelper;

/**
 * ScheduleAlarmReceiver
 * ScheduleAlarmReceiver
 * Schedule alarm receiver - AlarmManager ile zamanlanmış alarm'ları alır
 */
public class ScheduleAlarmReceiver extends BroadcastReceiver {
    
    public static String TAG = "TSLocationManager";
    
    /**
     * Regular schedule runner
     */
    private class ScheduleRunner implements Runnable {
        private final Intent intent;
        private final Context context;
        
        ScheduleRunner(Intent intent, Context context) {
            this.intent = intent;
            this.context = context;
        }
        
        @Override
        public void run() {
            boolean enabled = this.intent.getBooleanExtra("schedule_enabled", false);
            int trackingMode = this.intent.getIntExtra("trackingMode", 1);
            ScheduleEvent.onScheduleAlarm(
                this.context.getApplicationContext(), 
                enabled, 
                trackingMode
            );
        }
    }
    
    /**
     * One-shot runner
     */
    private class OneShotRunner implements Runnable {
        private final Context context;
        private final String action;
        
        OneShotRunner(Context context, String action) {
            this.context = context;
            this.action = action;
        }
        
        @Override
        public void run() {
            ScheduleEvent.onOneShot(this.context.getApplicationContext(), this.action, null);
        }
    }
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent.hasExtra(TSScheduleManager.ACTION_ONESHOT)) {
            // One-shot event
            String action = intent.getStringExtra(TSScheduleManager.ACTION_NAME);
            
            // Cancel pending intent
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                flags |= PendingIntent.FLAG_IMMUTABLE;
            }
            PendingIntent broadcast = PendingIntent.getBroadcast(
                context, 
                action.hashCode(), 
                intent, 
                flags
            );
            
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager != null && broadcast != null) {
                alarmManager.cancel(broadcast);
                broadcast.cancel();
            }
            
            BackgroundLocationAdapter.getThreadPool().execute(
                new OneShotRunner(context, action)
            );
            return;
        }
        
        // Regular schedule event
        BackgroundLocationAdapter.getThreadPool().execute(
            new ScheduleRunner(intent, context)
        );
    }
}

