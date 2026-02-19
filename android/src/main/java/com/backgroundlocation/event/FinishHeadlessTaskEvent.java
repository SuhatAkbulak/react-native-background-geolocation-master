package com.backgroundlocation.event;

import android.content.Context;

/**
 * FinishHeadlessTaskEvent
 * FinishHeadlessTaskEvent.java
 * Headless task bitirme event
 */
public class FinishHeadlessTaskEvent {
    private final Context context;
    private final int taskId;
    
    public FinishHeadlessTaskEvent(Context context, int taskId) {
        this.context = context;
        this.taskId = taskId;
    }
    
    public Context getContext() {
        return context;
    }
    
    public int getTaskId() {
        return taskId;
    }
    
    public String getEventName() {
        return "finishheadlesstask";
    }
}

