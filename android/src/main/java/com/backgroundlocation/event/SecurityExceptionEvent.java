package com.backgroundlocation.event;

/**
 * SecurityExceptionEvent
 * SecurityExceptionEvent.java
 * Security exception event
 */
public class SecurityExceptionEvent {
    private final String message;
    private final String permission;
    
    public SecurityExceptionEvent(String message, String permission) {
        this.message = message;
        this.permission = permission;
    }
    
    public String getMessage() {
        return message;
    }
    
    public String getPermission() {
        return permission;
    }
    
    public String getEventName() {
        return "securityexception";
    }
}

