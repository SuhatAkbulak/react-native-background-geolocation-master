package com.backgroundlocation.event;

/**
 * TerminateEvent
 * TerminateEvent
 * Terminate event
 */
public class TerminateEvent {
    public static final String ACTION = "TERMINATE";
    
    private final String reason;
    
    public TerminateEvent(String reason) {
        this.reason = reason;
    }
    
    public String getReason() {
        return reason;
    }
    
    public String getEventName() {
        return "terminate";
    }
}

