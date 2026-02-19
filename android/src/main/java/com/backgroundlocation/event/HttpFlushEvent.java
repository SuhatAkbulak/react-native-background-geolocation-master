package com.backgroundlocation.event;

import android.content.Context;
import com.backgroundlocation.adapter.BackgroundLocationAdapter;
import com.backgroundlocation.config.Config;
import com.backgroundlocation.service.SyncService;

/**
 * HttpFlushEvent
 * HttpFlushEvent.java
 * HTTP flush event
 */
public class HttpFlushEvent {
    public static final String ACTION = "http_flush";
    
    public static void run(Context context) {
        Config config = Config.getInstance(context);
        if (config.enabled && config.autoSync && !config.url.isEmpty() && !config.isMoving) {
            BackgroundLocationAdapter.getThreadPool().execute(() -> {
                SyncService.sync(context);
            });
        }
    }
    
    public String getEventName() {
        return "httpflush";
    }
}

