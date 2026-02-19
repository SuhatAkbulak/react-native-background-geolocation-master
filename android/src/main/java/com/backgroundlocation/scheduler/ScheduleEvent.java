package com.backgroundlocation.scheduler;

import android.content.Context;
import android.content.Intent;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.event.HttpFlushEvent;
import com.backgroundlocation.event.LaunchForegroundServiceEvent;
import com.backgroundlocation.event.MotionActivityCheckEvent;
import com.backgroundlocation.event.MotionTriggerDelayEvent;
import com.backgroundlocation.event.StartGeofencesEvent;
import com.backgroundlocation.event.StopAfterElapsedMinutesEvent;
import com.backgroundlocation.event.StopTimeoutEvent;
import com.backgroundlocation.event.TerminateEvent;
import com.backgroundlocation.logger.Log;
import com.backgroundlocation.service.HeartbeatService;
import com.backgroundlocation.util.LogHelper;
import org.greenrobot.eventbus.EventBus;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.Locale;

/**
 * ScheduleEvent
 * ScheduleEvent.java
 * Schedule event - zamanlanmış event'leri yönetir
 */
public class ScheduleEvent {
    
    private final Boolean enabled;
    private final JSONObject state;
    
    /**
     * Callback interface
     */
    public interface Callback {
        void onFinish();
    }
    
    public ScheduleEvent(Boolean enabled, JSONObject state) {
        this.enabled = enabled;
        this.state = state;
    }
    
    /**
     * Handle schedule alarm event
     */
    static void onScheduleAlarm(Context context, boolean enabled, int trackingMode) {
        Log.logger.debug("");
        Config config = Config.getInstance(context);
        
        if (!config.schedulerEnabled) {
            TSScheduleManager.getInstance(context).cancel();
            Log.logger.warn(Log.warn("Ignored schedule alarm event (scheduler is disabled)"));
            return;
        }
        
        BackgroundLocationAdapter adapter = BackgroundLocationAdapter.getInstance(context);
        Log.logger.info(Log.header("📅  Schedule alarm fired!  enabled: " + enabled + ", trackingMode: " + trackingMode));
        
        // TODO: Add trackingMode to Config if needed
        // config.trackingMode = trackingMode;
        
        if (enabled) {
            adapter.start(new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    Log.logger.debug("Schedule start success");
                }
                
                @Override
                public void onFailure(String error) {
                    Log.logger.error(Log.error("Schedule start failed: " + error));
                }
            });
        } else {
            adapter.stop(new com.backgroundlocation.adapter.callback.Callback() {
                @Override
                public void onSuccess() {
                    Log.logger.debug("Schedule stop success");
                }
                
                @Override
                public void onFailure(String error) {
                    Log.logger.error(Log.error("Schedule stop failed: " + error));
                }
            });
        }
        
        EventBus.getDefault().post(new ScheduleEvent(Boolean.valueOf(enabled), config.toJSON()));
        TSScheduleManager.getInstance(context).scheduleNext(Calendar.getInstance(Locale.US), config.enabled);
    }
    
    /**
     * Handle one-shot event
     */
    static void onOneShot(Context context, String action, Callback callback) {
        Log.logger.info(Log.header("⏰ OneShot event fired: " + action));
        Context appContext = context.getApplicationContext();
        BackgroundLocationAdapter adapter = BackgroundLocationAdapter.getInstance(appContext);
        
        if (action.equalsIgnoreCase(TerminateEvent.ACTION)) {
            new TerminateEvent("Schedule terminated");
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(MotionActivityCheckEvent.ACTION)) {
            new MotionActivityCheckEvent(appContext);
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(StopAfterElapsedMinutesEvent.ACTION)) {
            new StopAfterElapsedMinutesEvent(appContext);
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(StopTimeoutEvent.ACTION)) {
            new StopTimeoutEvent(appContext);
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(MotionTriggerDelayEvent.ACTION)) {
            new MotionTriggerDelayEvent(0, "Schedule triggered");
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(StartGeofencesEvent.ACTION)) {
            new StartGeofencesEvent(true, "Schedule triggered");
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(LaunchForegroundServiceEvent.ACTION)) {
            new LaunchForegroundServiceEvent(appContext);
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(HttpFlushEvent.ACTION)) {
            HttpFlushEvent.run(appContext);
            if (callback != null) callback.onFinish();
        } else if (action.equalsIgnoreCase(HeartbeatService.ACTION)) {
            HeartbeatService.onHeartbeat(appContext);
            if (callback != null) callback.onFinish();
        } else {
            Log.logger.warn(Log.warn("Unknown OneShot event: " + action + " <IGNORED>"));
            if (callback != null) callback.onFinish();
        }
    }
    
    public Boolean getEnabled() {
        return enabled;
    }
    
    public JSONObject getState() {
        return state;
    }
}

