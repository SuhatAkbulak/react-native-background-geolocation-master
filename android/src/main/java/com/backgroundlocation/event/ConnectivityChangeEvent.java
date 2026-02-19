package com.backgroundlocation.event;

import org.json.JSONObject;

/**
 * Connectivity Change Event
 * Type-safe event class
 */
public class ConnectivityChangeEvent {
    private final boolean connected;
    
    public ConnectivityChangeEvent(boolean connected) {
        this.connected = connected;
    }
    
    public boolean isConnected() {
        return connected;
    }
    
    public JSONObject toJson() {
        try {
            JSONObject json = new JSONObject();
            json.put("connected", connected);
            return json;
        } catch (Exception e) {
            return new JSONObject();
        }
    }
    
    public String getEventName() {
        return "connectivitychange";
    }
}



