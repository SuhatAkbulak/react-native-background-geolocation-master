package com.backgroundlocation.event;

import android.content.Context;
import android.os.Build;
import com.backgroundlocation.service.AbstractService;

/**
 * LaunchForegroundServiceEvent
 * LaunchForegroundServiceEvent.java
 * Foreground service başlatma event
 */
public class LaunchForegroundServiceEvent {
    public static final String ACTION = "LAUNCH_FOREGROUND_SERVICE";
    
    public LaunchForegroundServiceEvent(Context context) {
        if (Build.VERSION.SDK_INT >= 31) {
            AbstractService.launchQueuedServices(context);
        }
    }
    
    public String getEventName() {
        return "launchforegroundservice";
    }
}

