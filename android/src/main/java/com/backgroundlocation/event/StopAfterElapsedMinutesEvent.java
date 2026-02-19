package com.backgroundlocation.event;

import android.content.Context;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.service.LocationService;
import org.greenrobot.eventbus.EventBus;

/**
 * Stop After Elapsed Minutes Event
 * stopAfterElapsedMinutes süresi dolduğunda tetiklenir
 * AlarmManager → Event → Service stop
 */
public class StopAfterElapsedMinutesEvent {
    public static final String ACTION = "STOP_AFTER_ELAPSED_MINUTES";
    
    public StopAfterElapsedMinutesEvent(Context context) {
        Config config = Config.getInstance(context);
        
        if (config.enabled) {
            // Post self to EventBus
            EventBus.getDefault().post(this);
            
            // Stop tracking service
            LocationService.stop(context);
        }
    }
}



