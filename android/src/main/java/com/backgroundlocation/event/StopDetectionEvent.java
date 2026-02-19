package com.backgroundlocation.event;

/**
 * StopDetectionEvent
 * StopDetectionEvent.java
 * Stop detection event
 */
public class StopDetectionEvent {
    private final String reason;
    
    public StopDetectionEvent(String reason) {
        this.reason = reason;
    }
    
    public String getReason() {
        return reason;
    }
    
    public String getEventName() {
        return "stopdetection";
    }
}

