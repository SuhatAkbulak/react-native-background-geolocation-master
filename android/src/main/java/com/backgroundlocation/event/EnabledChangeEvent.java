package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * Enabled Change Event
 * stopAfterElapsedMinutes süresi dolduğunda tetiklenir
 * Type-safe event class
 */
public class EnabledChangeEvent {
    private final boolean enabled;
    
    public EnabledChangeEvent(boolean enabled) {
        this.enabled = enabled;
    }
    
    public boolean isEnabled() {
        return enabled;
    }
    
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("enabled", enabled);
            return json;
        } catch (Exception e) {
            return new JSONObject();
        }
    }
    
    public String getEventName() {
        return "enabledchange";
    }
}



