package com.backgroundlocation.event;

/**
 * StartGeofencesEvent
 * StartGeofencesEvent
 * Geofences başlatma event
 */
public class StartGeofencesEvent {
    public static final String ACTION = "START_GEOFENCES";
    
    private final boolean success;
    private final String message;
    
    public StartGeofencesEvent(boolean success, String message) {
        this.success = success;
        this.message = message;
    }
    
    public boolean isSuccess() {
        return success;
    }
    
    public String getMessage() {
        return message;
    }
    
    public String getEventName() {
        return "startgeofences";
    }
}

