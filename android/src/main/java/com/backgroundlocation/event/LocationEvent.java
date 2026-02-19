package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * Location Event
 * Type-safe event class
 */
public class LocationEvent {
    private final JSONObject locationJson;
    
    public LocationEvent(JSONObject locationJson) {
        this.locationJson = locationJson;
    }
    
    public JSONObject toJson() {
        return locationJson;
    }
    
    public String getEventName() {
        return "location";
    }
}



