package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * Motion Change Event
 * Hareket durumu değiştiğinde tetiklenir
 */
public class MotionChangeEvent {
    private final boolean isMoving;
    private final JSONObject location;
    
    public MotionChangeEvent(boolean isMoving, JSONObject location) {
        this.isMoving = isMoving;
        this.location = location;
    }
    
    public boolean isMoving() {
        return isMoving;
    }
    
    public JSONObject getLocation() {
        return location;
    }
    
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("isMoving", isMoving);
            json.put("location", location);
            return json;
        } catch (Exception e) {
            return new JSONObject();
        }
    }
    
    public String getEventName() {
        return "motionchange";
    }
}



