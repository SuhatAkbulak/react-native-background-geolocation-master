package com.backgroundlocation.scheduler;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.PersistableBundle;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.ConfigChangeEvent;
import com.backgroundlocation.logger.Log;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * TSScheduleManager
 * TSScheduleManager
 * Schedule yönetimi - zamanlanmış işleri yönetir
 */
public class TSScheduleManager {
    
    public static final String ACTION_NAME = "action";
    public static final String ACTION_ONESHOT = "ONESHOT";
    private static final int JOB_ID = 666;
    
    private static TSScheduleManager instance = null;
    private final Context context;
    private final SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm", Locale.US);
    private final List<Schedule> schedules = new ArrayList<>();
    private final AtomicBoolean isStarted = new AtomicBoolean(false);
    
    public TSScheduleManager(Context context) {
        this.context = context.getApplicationContext();
        EventBus eventBus = EventBus.getDefault();
        if (!eventBus.isRegistered(this)) {
            eventBus.register(this);
        }
    }
    
    private static synchronized TSScheduleManager getInstanceInternal(Context context) {
        if (instance == null) {
            instance = new TSScheduleManager(context);
        }
        return instance;
    }
    
    public static TSScheduleManager getInstance(Context context) {
        if (instance == null) {
            Config.getInstance(context.getApplicationContext());
            instance = getInstanceInternal(context);
        }
        return instance;
    }
    
    /**
     * Cancel all schedules
     */
    public void cancel() {
        Config config = Config.getInstance(context);
        if (!config.scheduleUseAlarmManager) {
            JobScheduler jobScheduler = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
            if (jobScheduler != null) {
                jobScheduler.cancel(JOB_ID);
            }
            return;
        }
        
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null) {
            Intent intent = new Intent(context, ScheduleService.class);
            PendingIntent pendingIntent = ScheduleService.createPendingIntent(context, intent);
            alarmManager.cancel(pendingIntent);
        }
    }
    
    /**
     * Check if can schedule exact alarms
     */
    public boolean canScheduleExactAlarms() {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return alarmManager.canScheduleExactAlarms();
        }
        return true;
    }
    
    /**
     * Cancel one-shot
     */
    public void cancelOneShot(String action) {
        if (action == null || action.isEmpty()) {
            return;
        }
        
        Log.logger.info(Log.info("Cancel OneShot: " + action));
        
        // Cancel JobScheduler
        JobScheduler jobScheduler = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
        if (jobScheduler != null) {
            jobScheduler.cancel(action.hashCode());
        }
        
        // Cancel AlarmManager
        Intent intent = new Intent(context, ScheduleAlarmReceiver.class);
        intent.setAction(action);
        intent.putExtra(ACTION_ONESHOT, true);
        intent.putExtra(ACTION_NAME, action);
        
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= PendingIntent.FLAG_IMMUTABLE;
        }
        
        PendingIntent broadcast = PendingIntent.getBroadcast(context, action.hashCode(), intent, flags);
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager != null && broadcast != null) {
            alarmManager.cancel(broadcast);
            broadcast.cancel();
        }
    }
    
    /**
     * Destroy
     */
    public void destroy() {
        Config config = Config.getInstance(context);
        if (config.stopOnTerminate) {
            stop();
        }
        EventBus eventBus = EventBus.getDefault();
        if (eventBus.isRegistered(this)) {
            eventBus.unregister(this);
        }
    }
    
    /**
     * Handle config change
     */
    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onConfigChange(ConfigChangeEvent event) {
        Config config = Config.getInstance(context);
        if (event.isDirty("schedule")) {
            restart(event.getContext());
        }
    }
    
    /**
     * One-shot schedule
     */
    public void oneShot(String action, long delayMillis) {
        oneShot(action, delayMillis, false, false);
    }
    
    /**
     * One-shot schedule with options
     */
    public void oneShot(String action, long delayMillis, boolean useAlarmManager, boolean exact) {
        // TODO: Implement one-shot scheduling
        LogHelper.d("TSScheduleManager", "One-shot: " + action + " delay: " + delayMillis);
    }
    
    /**
     * Restart scheduler
     */
    public void restart(Context context) {
        Config config = Config.getInstance(this.context);
        synchronized (schedules) {
            schedules.clear();
        }
        
        if (config.schedulerEnabled) {
            Log.logger.debug(Log.info("Schedule changed: restarting..."));
            cancel();
            config.schedulerEnabled = false;
            start();
        }
    }
    
    /**
     * Start scheduler
     */
    public void start() {
        if (isStarted.get()) {
            return;
        }
        
        Config config = Config.getInstance(context);
        synchronized (schedules) {
            if (schedules.isEmpty()) {
                if (!loadSchedules()) {
                    stop();
                    return;
                }
            }
            
            if (config.schedulerEnabled) {
                Log.logger.warn("Scheduler already started. IGNORED");
                return;
            }
        }
        
        config.schedulerEnabled = true;
        
        StringBuilder logMessage = new StringBuilder();
        logMessage.append(Log.header("🎾  Scheduler ON"));
        
        synchronized (schedules) {
            for (Schedule schedule : schedules) {
                logMessage.append(Log.boxRow(schedule.toString()));
            }
        }
        
        logMessage.append(Log.BOX_BOTTOM);
        Log.logger.info(logMessage.toString());
        
        scheduleNext(Calendar.getInstance(Locale.US), config.enabled);
    }
    
    /**
     * Stop scheduler
     */
    public void stop() {
        Config config = Config.getInstance(context);
        Log.logger.info(Log.off("Scheduler OFF"));
        config.schedulerEnabled = false;
        cancel();
        isStarted.set(false);
    }
    
    /**
     * Load schedules from config
     */
    private boolean loadSchedules() {
        Config config = Config.getInstance(context);
        if (config.schedule == null || config.schedule.isEmpty()) {
            return false;
        }
        
        String[] scheduleStrings = config.schedule.split(",");
        for (String scheduleStr : scheduleStrings) {
            try {
                schedules.add(new Schedule(scheduleStr.trim()));
            } catch (Exception e) {
                LogHelper.e("TSScheduleManager", "Failed to parse schedule: " + scheduleStr, e);
            }
        }
        
        return !schedules.isEmpty();
    }
    
    /**
     * Schedule next alarm
     */
    public void scheduleNext(Calendar calendar, Boolean enabled) {
        synchronized (schedules) {
            if (schedules.isEmpty()) {
                if (!loadSchedules()) {
                    stop();
                    return;
                }
            }
        }
        
        // Check if more than 7 days in future
        long daysDiff = TimeUnit.MILLISECONDS.toDays(
            calendar.getTimeInMillis() - Calendar.getInstance().getTimeInMillis()
        );
        if (daysDiff >= 7) {
            Log.logger.warn(Log.warn("Failed to find a schedule. Giving up."));
            return;
        }
        
        int dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK);
        Log.logger.debug(Log.info("Day #" + dayOfWeek + ": Searching schedule for alarms..."));
        
        Schedule nextSchedule = null;
        synchronized (schedules) {
            for (Schedule schedule : schedules) {
                if (schedule.isNext(calendar)) {
                    nextSchedule = schedule;
                    break;
                }
            }
        }
        
        if (nextSchedule != null) {
            if (calendar.after(nextSchedule.onTime) && calendar.before(nextSchedule.offTime)) {
                // Currently in schedule window
                if (!enabled) {
                    Log.logger.debug(Log.info("Scheduler says we should be ENABLED but we are NOT"));
                    scheduleAlarm(Boolean.TRUE, calendar, nextSchedule.trackingMode);
                } else {
                    scheduleAlarm(Boolean.FALSE, nextSchedule.offTime, nextSchedule.trackingMode);
                }
            } else if (calendar.before(nextSchedule.onTime)) {
                // Before schedule window
                if (enabled) {
                    Log.logger.debug(Log.info("Scheduler says we should be DISABLED but we are NOT"));
                    scheduleAlarm(Boolean.FALSE, calendar, nextSchedule.trackingMode);
                } else {
                    scheduleAlarm(Boolean.TRUE, nextSchedule.onTime, nextSchedule.trackingMode);
                }
            } else if (calendar.after(nextSchedule.offTime)) {
                // After schedule window - check tomorrow
                Log.logger.debug(Log.info("Scheduler failed to find any alarms today. Checking tomorrow..."));
                calendar.add(Calendar.DAY_OF_YEAR, 1);
                calendar.set(Calendar.HOUR_OF_DAY, 0);
                calendar.set(Calendar.MINUTE, 0);
                scheduleNext(calendar, enabled);
            }
        } else {
            // No schedule found for today
            if (enabled) {
                Log.logger.debug(Log.info("Scheduler says we should be DISABLED but we are NOT"));
                scheduleAlarm(Boolean.FALSE, calendar, 1);
            } else {
                Log.logger.debug(Log.info("Day #" + dayOfWeek + ": Failed to find alarms on this day. Trying tomorrow..."));
                calendar.add(Calendar.DAY_OF_YEAR, 1);
                calendar.set(Calendar.HOUR_OF_DAY, 0);
                calendar.set(Calendar.MINUTE, 0);
                scheduleNext(calendar, enabled);
            }
        }
    }
    
    /**
     * Schedule alarm
     */
    private void scheduleAlarm(Boolean enabled, Calendar time, int trackingMode) {
        Config config = Config.getInstance(context);
        long triggerAtMillis = time.getTimeInMillis();
        
        if (config.scheduleUseAlarmManager) {
            // Use AlarmManager
            AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (alarmManager == null) return;
            
            Intent intent = new Intent(context, ScheduleService.class);
            intent.putExtra("schedule_enabled", enabled);
            intent.putExtra("trackingMode", trackingMode);
            
            PendingIntent pendingIntent = ScheduleService.createPendingIntent(context, intent);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent);
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent);
                }
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent);
            }
        } else {
            // Use JobScheduler
            JobScheduler jobScheduler = (JobScheduler) context.getSystemService(Context.JOB_SCHEDULER_SERVICE);
            if (jobScheduler == null) return;
            
            PersistableBundle extras = new PersistableBundle();
            extras.putBoolean("enabled", enabled);
            extras.putInt("trackingMode", trackingMode);
            
            JobInfo jobInfo = new JobInfo.Builder(JOB_ID, new ComponentName(context, ScheduleJobService.class))
                .setMinimumLatency(Math.max(0, triggerAtMillis - System.currentTimeMillis()))
                .setExtras(extras)
                .setPersisted(true)
                .build();
            
            jobScheduler.schedule(jobInfo);
        }
    }
}

