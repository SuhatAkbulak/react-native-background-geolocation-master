package com.backgroundlocation.event;

import android.content.Context;
import com.backgroundlocation.config.Config;
import org.greenrobot.eventbus.EventBus;

/**
 * MotionActivityCheckEvent
 * MotionActivityCheckEvent.java
 * Motion activity kontrol event
 */
public class MotionActivityCheckEvent {
    public static final String ACTION = "MOTION_ACTIVITY_CHECK";
    
    public MotionActivityCheckEvent(Context context) {
        Config config = Config.getInstance(context);
        if (config.enabled && config.isMoving) {
            EventBus.getDefault().post(this);
        }
    }
    
    public String getEventName() {
        return "motionactivitycheck";
    }
}

