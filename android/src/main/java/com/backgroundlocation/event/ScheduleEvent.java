package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * ScheduleEvent
 * ScheduleEvent.java
 * Schedule event
 */
public class ScheduleEvent {
    private final String action;
    private final JSONObject data;
    
    public ScheduleEvent(String action, JSONObject data) {
        this.action = action;
        this.data = data;
    }
    
    public String getAction() {
        return action;
    }
    
    public JSONObject getData() {
        return data;
    }
    
    public String getEventName() {
        return "schedule";
    }
}

