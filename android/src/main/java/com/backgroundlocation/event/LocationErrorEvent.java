package com.backgroundlocation.event;

/**
 * LocationErrorEvent
 * LocationErrorEvent.java
 * Location hata event
 */
public class LocationErrorEvent {
    public final int errorCode;
    public final String message;
    
    public LocationErrorEvent(int errorCode, String message) {
        this.errorCode = errorCode;
        this.message = message;
    }
    
    public LocationErrorEvent(int errorCode) {
        this.errorCode = errorCode;
        this.message = "";
    }
    
    public String getEventName() {
        return "locationerror";
    }
}

