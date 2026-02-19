package com.backgroundlocation.event;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Heartbeat Event
 * Periyodik heartbeat location olaylarını temsil eder
 * HeartbeatEvent
 */
public class HeartbeatEvent {
    private static final String EVENT_NAME = "heartbeat";
    
    private JSONObject location;
    
    public HeartbeatEvent() {
        this.location = new JSONObject();
    }
    
    public HeartbeatEvent(JSONObject location) {
        this.location = location;
    }
    
    public String getEventName() {
        return EVENT_NAME;
    }
    
    public JSONObject getLocation() {
        return location;
    }
    
    public void setLocation(JSONObject location) {
        this.location = location;
    }
    
    /**
     * Convert to JSON for React Native
     */
    public JSONObject toJson() throws JSONException {
        JSONObject json = new JSONObject();
        json.put("location", location);
        return json;
    }
}

