package com.backgroundlocation.event;

import org.json.JSONException;
import org.json.JSONObject;

/**
 * Activity Change Event
 * Aktivite değişikliği olaylarını temsil eder
 * Event sınıfı
 */
public class ActivityChangeEvent {
    private static final String EVENT_NAME = "activitychange";
    
    private String activity; // "still", "walking", "running", "on_foot", "in_vehicle", "on_bicycle", "unknown"
    private int confidence; // 0-100
    private long timestamp;
    
    public ActivityChangeEvent(String activity, int confidence) {
        this.activity = activity;
        this.confidence = confidence;
        this.timestamp = System.currentTimeMillis();
    }
    
    public String getEventName() {
        return EVENT_NAME;
    }
    
    public String getActivity() {
        return activity;
    }
    
    public int getConfidence() {
        return confidence;
    }
    
    public long getTimestamp() {
        return timestamp;
    }
    
    /**
     * Convert to JSON for React Native
     */
    public JSONObject toJson() throws JSONException {
        JSONObject json = new JSONObject();
        json.put("activity", activity);
        json.put("confidence", confidence);
        json.put("timestamp", timestamp);
        return json;
    }
}

