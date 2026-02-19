package com.backgroundlocation.event;

import android.content.Context;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;

/**
 * StopTimeoutEvent
 * StopTimeoutEvent.java
 * Stop timeout event
 */
public class StopTimeoutEvent {
    public static final String ACTION = "STOP_TIMEOUT";
    
    public StopTimeoutEvent(Context context) {
        Config config = Config.getInstance(context);
        if (config.enabled && config.isMoving) {
            BackgroundLocationAdapter.getInstance(context).changePace(false, null);
        }
    }
    
    public String getEventName() {
        return "stoptimeout";
    }
}

