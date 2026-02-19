package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * Geofence Event
 * Geofence ENTER/EXIT/DWELL olayı
 */
public class GeofenceEvent {
    private final String identifier;
    private final String action; // ENTER, EXIT, DWELL
    private final JSONObject location;
    
    public GeofenceEvent(String identifier, String action, JSONObject location) {
        this.identifier = identifier;
        this.action = action;
        this.location = location;
    }
    
    public String getIdentifier() {
        return identifier;
    }
    
    public String getAction() {
        return action;
    }
    
    public JSONObject getLocation() {
        return location;
    }
    
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("identifier", identifier);
            json.put("action", action);
            json.put("location", location);
            return json;
        } catch (Exception e) {
            return new JSONObject();
        }
    }
    
    public String getEventName() {
        return "geofence";
    }
}



